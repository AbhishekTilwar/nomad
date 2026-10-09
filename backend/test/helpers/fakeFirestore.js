// In-memory Firestore fake used by the backend tests.
//
// What it models faithfully enough to be meaningful:
//  - optimistic-concurrency transactions: every tx.get records the doc version; commit fails and the
//    callback is re-run if any read doc changed (same observable behaviour as Firestore's retry on
//    contention). tx.get yields to the event loop so concurrent transactions genuinely interleave.
//  - reads-before-writes rule inside transactions.
//  - where (==, !=, <, <=, >, >=, in, array-contains), orderBy (+implicit __name__), limit,
//    startAfter(snapshot), collection groups, count(), batch, FieldValue-like sentinels, dotted update paths.
// What it does NOT model: index requirements, security rules, multi-region timing, the real
// server's pessimistic locking (it uses optimistic retry with a generous attempt budget).
import { Timestamp } from 'firebase-admin/firestore';

const isPlain = (v) => v && typeof v === 'object' && !Array.isArray(v) && !(v instanceof Timestamp) && !v.__fv;
const clone = (v) => {
  if (v instanceof Timestamp) return v;
  if (Array.isArray(v)) return v.map(clone);
  if (isPlain(v)) return Object.fromEntries(Object.entries(v).filter(([, x]) => x !== undefined).map(([k, x]) => [k, clone(x)]));
  return v;
};
const tick = () => new Promise((r) => setImmediate(r));
const keyOf = (v) => (v instanceof Timestamp ? v.toMillis() : v);
const cmp = (a, b) => {
  a = keyOf(a); b = keyOf(b);
  if (a === b) return 0;
  return a < b ? -1 : 1;
};
const getPath = (obj, path) => path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), obj);

export class FakeFirestore {
  constructor({ now = () => Date.now(), maxAttempts = 200 } = {}) {
    this.now = now;
    this.maxAttempts = maxAttempts;
    this.docs = new Map(); // path -> { data, version }
    this.versions = new Map(); // path -> number (survives deletes)
    this.stats = { txAttempts: 0, txConflicts: 0 };
    this.fv = {
      serverTimestamp: () => ({ __fv: 'ts' }),
      delete: () => ({ __fv: 'delete' }),
    };
  }

  collection(path) { return new CollectionRef(this, path); }
  doc(path) { return new DocRef(this, path); }
  collectionGroup(id) { return new Query(this, { group: id }); }
  batch() { return new Batch(this); }
  version(path) { return this.versions.get(path) ?? 0; }

  // ---- raw ops (synchronous, atomic)
  _resolve(value) {
    if (value && value.__fv === 'ts') return Timestamp.fromMillis(this.now());
    if (Array.isArray(value)) return value.map((x) => this._resolve(x));
    if (isPlain(value)) {
      const out = {};
      for (const [k, v] of Object.entries(value)) {
        if (v === undefined) continue;
        if (v && v.__fv === 'delete') continue;
        out[k] = this._resolve(v);
      }
      return out;
    }
    return value;
  }
  _bump(path) { this.versions.set(path, this.version(path) + 1); }
  _set(path, data, merge) {
    const existing = this.docs.get(path)?.data;
    let next;
    if (merge && existing) next = deepMerge(existing, data, this);
    else next = this._resolve(data);
    this.docs.set(path, { data: clone(next) });
    this._bump(path);
  }
  _update(path, upd) {
    const cur = this.docs.get(path);
    if (!cur) { const e = new Error(`NOT_FOUND: no document to update: ${path}`); e.code = 5; throw e; }
    const data = clone(cur.data);
    for (const [k, v] of Object.entries(upd)) {
      const parts = k.split('.');
      let o = data;
      for (const p of parts.slice(0, -1)) { if (!isPlain(o[p])) o[p] = {}; o = o[p]; }
      const last = parts[parts.length - 1];
      if (v && v.__fv === 'delete') delete o[last];
      else if (v !== undefined) o[last] = this._resolve(v);
    }
    this.docs.set(path, { data });
    this._bump(path);
  }
  _delete(path) { if (this.docs.delete(path)) this._bump(path); else this._bump(path); }

  async runTransaction(fn) {
    for (let attempt = 1; attempt <= this.maxAttempts; attempt++) {
      this.stats.txAttempts++;
      const tx = new Transaction(this);
      const result = await fn(tx);
      // commit: validate reads
      let ok = true;
      for (const [p, v] of tx.reads) if (this.version(p) !== v) { ok = false; break; }
      if (ok) {
        for (const w of tx.writes) {
          if (w.op === 'set') this._set(w.path, w.data, w.merge);
          if (w.op === 'update') this._update(w.path, w.data);
          if (w.op === 'delete') this._delete(w.path);
        }
        return result;
      }
      this.stats.txConflicts++;
      await tick();
    }
    const e = new Error('ABORTED: too much contention'); e.code = 10; throw e;
  }
}

function deepMerge(existing, patch, db) {
  const out = clone(existing);
  for (const [k, v] of Object.entries(patch)) {
    if (v === undefined) continue;
    if (v && v.__fv === 'delete') delete out[k];
    else if (isPlain(v) && isPlain(out[k])) out[k] = deepMerge(out[k], v, db);
    else out[k] = db._resolve(v);
  }
  return out;
}

class Snapshot {
  constructor(ref, data) { this.ref = ref; this.id = ref.id; this._d = data; this.exists = data !== undefined; }
  data() { return this._d === undefined ? undefined : clone(this._d); }
  get(field) { return getPath(this._d, field); }
}

export class DocRef {
  constructor(db, path) {
    this.firestore = db; this.path = path;
    this.id = path.split('/').pop();
  }
  get parent() { const segs = this.path.split('/'); return new CollectionRef(this.firestore, segs.slice(0, -1).join('/')); }
  collection(sub) { return new CollectionRef(this.firestore, `${this.path}/${sub}`); }
  async get() { await tick(); return this._snap(); }
  _snap() { const d = this.firestore.docs.get(this.path); return new Snapshot(this, d?.data); }
  async set(data, opts = {}) { this.firestore._set(this.path, data, opts.merge); }
  async update(data) { this.firestore._update(this.path, data); }
  async delete() { this.firestore._delete(this.path); }
}

export class Query {
  constructor(db, spec) {
    this.firestore = db;
    this.spec = { filters: [], orders: [], limit: null, after: null, ...spec };
  }
  _with(patch) { return new Query(this.firestore, { ...this.spec, ...patch }); }
  where(field, op, value) { return this._with({ filters: [...this.spec.filters, { field, op, value }] }); }
  orderBy(field, dir = 'asc') { return this._with({ orders: [...this.spec.orders, { field, dir }] }); }
  limit(n) { return this._with({ limit: n }); }
  startAfter(snap) { return this._with({ after: snap }); }

  _matchPath(path) {
    const segs = path.split('/');
    const colPath = segs.slice(0, -1).join('/');
    if (this.spec.group) return segs[segs.length - 2] === this.spec.group;
    return colPath === this.spec.collection;
  }
  _run() {
    const { filters, orders } = this.spec;
    let rows = [];
    for (const [path, { data }] of this.firestore.docs) {
      if (!this._matchPath(path)) continue;
      let ok = true;
      for (const f of filters) {
        const v = getPath(data, f.field);
        if (v === undefined) { ok = false; break; }
        const c = () => cmp(v, f.value);
        ok = {
          '==': () => c() === 0,
          '!=': () => c() !== 0,
          '<': () => c() < 0,
          '<=': () => c() <= 0,
          '>': () => c() > 0,
          '>=': () => c() >= 0,
          in: () => f.value.some((x) => cmp(v, x) === 0),
          'array-contains': () => Array.isArray(v) && v.some((x) => cmp(x, f.value) === 0),
        }[f.op]();
        if (!ok) break;
      }
      if (ok && orders.every((o) => getPath(data, o.field) !== undefined)) rows.push({ path, data });
    }
    const lastDir = orders.length ? orders[orders.length - 1].dir : 'asc';
    const compare = (a, b) => {
      for (const o of orders) {
        const c = cmp(getPath(a.data, o.field), getPath(b.data, o.field));
        if (c) return o.dir === 'desc' ? -c : c;
      }
      const c = cmp(a.path, b.path);
      return lastDir === 'desc' ? -c : c;
    };
    rows.sort(compare);
    if (this.spec.after) {
      const a = { path: this.spec.after.ref.path, data: this.spec.after._d };
      rows = rows.filter((r) => compare(r, a) > 0);
    }
    if (this.spec.limit != null) rows = rows.slice(0, this.spec.limit);
    return rows;
  }
  async get() {
    await tick();
    return this._snapshot();
  }
  _snapshot() {
    const docs = this._run().map((r) => new Snapshot(new DocRef(this.firestore, r.path), r.data));
    return { docs, size: docs.length, empty: docs.length === 0 };
  }
  count() {
    return { get: async () => { await tick(); return { data: () => ({ count: this._run().length }) }; } };
  }
}

export class CollectionRef extends Query {
  constructor(db, path) { super(db, { collection: path }); this.path = path; this.id = path.split('/').pop(); }
  get parent() {
    const segs = this.path.split('/');
    return segs.length > 1 ? new DocRef(this.firestore, segs.slice(0, -1).join('/')) : null;
  }
  doc(id) { return new DocRef(this.firestore, `${this.path}/${id ?? randomId()}`); }
  async add(data) { const ref = this.doc(); await ref.set(data); return ref; }
}

let counter = 0;
const randomId = () => `auto${(++counter).toString(36)}${Math.random().toString(36).slice(2, 12)}`;

class Transaction {
  constructor(db) { this.db = db; this.reads = new Map(); this.writes = []; }
  async get(refOrQuery) {
    if (this.writes.length) throw new Error('Firestore transactions require all reads to be executed before all writes.');
    // Snapshot first, THEN model network latency, so other transactions can commit in between.
    let result;
    if (refOrQuery instanceof DocRef) {
      this.reads.set(refOrQuery.path, this.db.version(refOrQuery.path));
      result = refOrQuery._snap();
    } else {
      result = refOrQuery._snapshot();
      result.docs.forEach((d) => this.reads.set(d.ref.path, this.db.version(d.ref.path)));
    }
    await new Promise((r) => setTimeout(r, 2));
    return result;
  }
  set(ref, data, opts = {}) { this.writes.push({ op: 'set', path: ref.path, data, merge: opts.merge }); return this; }
  update(ref, data) { this.writes.push({ op: 'update', path: ref.path, data }); return this; }
  delete(ref) { this.writes.push({ op: 'delete', path: ref.path }); return this; }
}

class Batch {
  constructor(db) { this.db = db; this.ops = []; }
  set(ref, data, opts = {}) { this.ops.push(() => this.db._set(ref.path, data, opts.merge)); return this; }
  update(ref, data) { this.ops.push(() => this.db._update(ref.path, data)); return this; }
  delete(ref) { this.ops.push(() => this.db._delete(ref.path)); return this; }
  async commit() { this.ops.forEach((o) => o()); this.ops = []; }
}
