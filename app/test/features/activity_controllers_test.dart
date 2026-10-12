import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:nomad_mingle/core/services/location_service.dart';
import 'package:nomad_mingle/core/utils/app_exception.dart';
import 'package:nomad_mingle/features/activities/data/activity_repository.dart';
import 'package:nomad_mingle/features/activities/models/activity.dart';
import 'package:nomad_mingle/features/activities/presentation/activity_detail_controller.dart';
import 'package:nomad_mingle/features/create/presentation/create_activity_controller.dart';
import 'package:nomad_mingle/features/discover/presentation/discover_controller.dart';

import '../support/fakes.dart';

Future<void> pump() => Future<void>.delayed(Duration.zero);

class FakeLocation implements LocationService {
  FakeLocation(this.result);
  LocationResult result;
  int calls = 0;
  @override
  Future<LocationResult> current() async {
    calls++;
    return result;
  }

  @override
  Future<LocationResult> currentIfPermitted() => current();

  @override
  Future<void> openSettings() async {}
}

class PagingRepo extends FakeActivityRepository {
  final queries = <ActivityQuery>[];
  Completer<ActivityPage>? gate;
  @override
  Future<ActivityPage> list(ActivityQuery q) async {
    queries.add(q);
    if (gate != null) return gate!.future;
    if (q.cursor == null) {
      return ActivityPage([
        sampleActivity(id: 'a'),
        sampleActivity(id: 'b'),
      ], 'c1');
    }
    return ActivityPage([
      sampleActivity(id: 'b'),
      sampleActivity(id: 'c'),
    ], null);
  }
}

void _fill(CreateActivityController c, DateTime now) {
  c.title = 'Sunday brunch plan';
  c.description = 'A relaxed brunch for new people to meet.';
  c.category = 'food';
  c.startAt = now.add(const Duration(days: 2));
  c.venueName = 'Cafe Leopold';
  c.location = const LatLng(18.92, 72.83);
}

void main() {
  final now = DateTime(2026, 10, 10, 12);

  group('CreateActivityController', () {
    test('empty form reports every required field', () {
      final c = CreateActivityController(
        FakeActivityRepository(),
        city: 'mumbai',
      );
      final e = c.validate(now: now);
      expect(
        e.keys,
        unorderedEquals(['title', 'category', 'startAt', 'location']),
      );
    });

    test('description and venue name are optional', () {
      final c = CreateActivityController(
        FakeActivityRepository(),
        city: 'mumbai',
      );
      _fill(c, now);
      c.description = '';
      c.venueName = '   ';
      expect(c.validate(now: now), isEmpty);
      final draft = c.buildDraft();
      expect(draft.description, '');
      expect(draft.venueName, CreateActivityController.fallbackVenue);
      c.venueName = 'Cafe Leopold';
      expect(c.buildDraft().venueName, 'Cafe Leopold');
    });

    test('validateStep only reports the fields on that step', () {
      final c = CreateActivityController(
        FakeActivityRepository(),
        city: 'mumbai',
      );
      expect(c.validateStep(0, now: now), isFalse);
      expect(c.errors.keys, unorderedEquals(['category', 'title']));
      expect(c.validateStep(1, now: now), isFalse);
      expect(c.errors.keys, unorderedEquals(['startAt', 'location']));
      // Capacity defaults to a valid size and the plan is free, so step 3 is ok.
      expect(c.validateStep(2, now: now), isTrue);
      expect(c.validateStep(3, now: now), isTrue);
    });

    test('firstStepWithError finds the earliest step with a problem', () {
      expect(CreateActivityController.firstStepWithError({}), isNull);
      expect(
        CreateActivityController.firstStepWithError({
          'capacity': 'x',
          'location': 'y',
        }),
        1,
      );
    });

    test('shown errors clear as soon as the field becomes valid', () {
      final c = CreateActivityController(
        FakeActivityRepository(),
        city: 'mumbai',
      );
      c.validateStep(0, now: now);
      expect(c.errors, contains('title'));
      c.edit(() => c.title = 'Sunday brunch plan');
      expect(c.errors, isNot(contains('title')));
      expect(c.errors, contains('category'));
      c.update(() => c.category = 'food');
      expect(c.errors, isNot(contains('category')));
    });

    test('rejects past date, bad capacity, and paid without cost note', () {
      final c = CreateActivityController(
        FakeActivityRepository(),
        city: 'mumbai',
      );
      _fill(c, now);
      c.startAt = now.subtract(const Duration(days: 1));
      c.capacity = 1;
      c.costType = CostType.paid;
      final e = c.validate(now: now);
      expect(e['startAt'], isNotNull);
      expect(e['capacity'], isNotNull);
      expect(e['costDescription'], isNotNull);
    });

    test(
      'valid form builds a draft with UTC ISO times and no cost text when free',
      () {
        final c = CreateActivityController(
          FakeActivityRepository(),
          city: 'pune',
        );
        _fill(c, now);
        c.costDescription = 'ignored';
        expect(c.validate(now: now), isEmpty);
        final json = c.buildDraft().toJson();
        expect(json['city'], 'pune');
        expect(json['costDescription'], '');
        expect((json['startAt'] as String).endsWith('Z'), isTrue);
        expect(json['visibility'], 'public');
        expect(json.containsKey('coverImageUrl'), isFalse);
      },
    );

    test('duplicate submit while in flight only creates once', () async {
      final repo = FakeActivityRepository();
      final c = CreateActivityController(repo, city: 'mumbai');
      _fill(c, now);
      final f1 = c.submit(now: now);
      final f2 = c.submit(now: now);
      final results = await Future.wait([f1, f2]);
      expect(repo.createCalls, 1);
      expect(results.where((a) => a != null).length, 1);
    });

    test('server error is surfaced, form kept, submitting reset', () async {
      final repo = FakeActivityRepository()
        ..error = const AppException('Too many active plans.');
      final c = CreateActivityController(repo, city: 'mumbai');
      _fill(c, now);
      expect(await c.submit(now: now), isNull);
      expect(c.submitError, 'Too many active plans.');
      expect(c.submitting, isFalse);
      expect(c.title, 'Sunday brunch plan');
    });

    test('invalid form never reaches the repository', () async {
      final repo = FakeActivityRepository();
      final c = CreateActivityController(repo, city: 'mumbai');
      expect(await c.submit(now: now), isNull);
      expect(repo.createCalls, 0);
      expect(c.errors, isNotEmpty);
    });
  });

  group('ActivityDetailController', () {
    test(
      'join on open activity -> joined message and refreshed state',
      () async {
        final repo = FakeActivityRepository([sampleActivity()]);
        final c = ActivityDetailController(repo, 'a1');
        await pump();
        expect(c.activity, isNotNull);
        await c.join();
        expect(repo.joined, ['a1']);
        expect(c.takeMessage(), 'You\'re in!');
        expect(c.busy, isFalse);
      },
    );

    test('approval-required join reports a pending request', () async {
      final repo = FakeActivityRepository([
        sampleActivity(approvalRequired: true),
      ]);
      final c = ActivityDetailController(repo, 'a1');
      await pump();
      await c.join();
      expect(c.takeMessage(), contains('Request sent'));
    });

    test('duplicate join taps are ignored while busy', () async {
      final repo = FakeActivityRepository([sampleActivity()]);
      final c = ActivityDetailController(repo, 'a1');
      await pump();
      await Future.wait([c.join(), c.join(), c.join()]);
      expect(repo.joined.length, 1);
    });

    test('load error exposes message and can retry', () async {
      final repo = FakeActivityRepository([sampleActivity()])
        ..error = const AppException('offline');
      final c = ActivityDetailController(repo, 'a1');
      await pump();
      expect(c.loadError, 'offline');
      repo.error = null;
      await c.load();
      expect(c.activity?.id, 'a1');
      expect(c.loadError, isNull);
    });

    test('failed join shows the server message', () async {
      final repo = FakeActivityRepository([sampleActivity()]);
      final c = ActivityDetailController(repo, 'a1');
      await pump();
      repo.error = const AppException('This plan is full.');
      await c.join();
      expect(c.takeMessage(), 'This plan is full.');
    });
  });

  group('DiscoverController', () {
    test(
      'loads first page then appends next page without duplicates',
      () async {
        final repo = PagingRepo();
        final c = DiscoverController(
          repo,
          FakeLocation(const LocationResult(LocationOutcome.denied)),
          city: 'mumbai',
        );
        await pump();
        expect(c.items.map((a) => a.id), ['a', 'b']);
        expect(c.hasMore, isTrue);
        await c.loadMore();
        expect(c.items.map((a) => a.id), ['a', 'b', 'c']);
        expect(c.hasMore, isFalse);
        expect(repo.queries.last.cursor, 'c1');
      },
    );

    test('search is debounced to a single request', () async {
      final repo = PagingRepo();
      final c = DiscoverController(
        repo,
        FakeLocation(const LocationResult(LocationOutcome.denied)),
        city: 'mumbai',
        debounce: const Duration(milliseconds: 30),
      );
      await pump();
      final before = repo.queries.length;
      c.setKeyword('h');
      c.setKeyword('hi');
      c.setKeyword('hik');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(repo.queries.length, before + 1);
      expect(repo.queries.last.keyword, 'hik');
    });

    test('filters are sent to the API', () async {
      final repo = PagingRepo();
      final c = DiscoverController(
        repo,
        FakeLocation(const LocationResult(LocationOutcome.denied)),
        city: 'pune',
      );
      await pump();
      await c.setCategory('hiking');
      await c.setFreeOnly(true);
      await c.setSpotsOnly(true);
      await c.setDateFilter(DateFilter.today);
      final q = repo.queries.last;
      expect(q.city, 'pune');
      expect(q.category, 'hiking');
      expect(q.freeOnly, isTrue);
      expect(q.minSpots, 1);
      expect(q.from, isNotNull);
      expect(q.to, isNotNull);
      expect(q.toQuery()['free'], 'true');
    });

    test(
      'location denied: proximity/radius not applied, notice shown',
      () async {
        final repo = PagingRepo();
        final c = DiscoverController(
          repo,
          FakeLocation(const LocationResult(LocationOutcome.denied)),
          city: 'mumbai',
        );
        await pump();
        await c.setRadius(5);
        expect(c.radiusKm, isNull);
        expect(c.locationNotice, isNotNull);
        await c.setSort(DiscoverSort.proximity);
        expect(c.sort, DiscoverSort.date);
      },
    );

    test(
      'location granted: lat/lng/radius sent, distances computed client-side',
      () async {
        final repo = PagingRepo();
        final loc = FakeLocation(
          const LocationResult(LocationOutcome.granted, LatLng(18.9, 72.8)),
        );
        final c = DiscoverController(repo, loc, city: 'mumbai');
        await pump();
        await c.setRadius(5);
        final q = repo.queries.last;
        expect(q.lat, 18.9);
        expect(q.radiusKm, 5);
        expect(c.items.first.distanceKm, isNotNull);
        await c.setRadius(15);
        expect(
          loc.calls,
          1,
          reason: 'location is fetched once, not per filter change',
        );
      },
    );

    test('stale response from superseded query is ignored', () async {
      final repo = PagingRepo()..gate = Completer<ActivityPage>();
      final c = DiscoverController(
        repo,
        FakeLocation(const LocationResult(LocationOutcome.denied)),
        city: 'mumbai',
      );
      final slow = repo.gate!;
      repo.gate = null;
      final fast = c.setFreeOnly(true);
      await fast;
      slow.complete(ActivityPage([sampleActivity(id: 'stale')], null));
      await pump();
      expect(c.items.any((a) => a.id == 'stale'), isFalse);
    });

    test('error then retry', () async {
      final repo = FakeActivityRepository()
        ..error = const AppException('offline');
      // FakeActivityRepository.list ignores error; use PagingRepo-like failure instead.
      final failing = _FailingRepo();
      final c = DiscoverController(
        failing,
        FakeLocation(const LocationResult(LocationOutcome.denied)),
        city: 'mumbai',
      );
      await pump();
      expect(c.error, 'offline');
      failing.fail = false;
      await c.refresh();
      expect(c.error, isNull);
      expect(c.items, isNotEmpty);
      expect(repo.createCalls, 0);
    });

    test('weekend range covers Saturday 00:00 to Monday 00:00', () async {
      final c = DiscoverController(
        PagingRepo(),
        FakeLocation(const LocationResult(LocationOutcome.denied)),
        city: 'mumbai',
        clock: () => DateTime(2026, 10, 7, 10), // Wednesday
      );
      c.dateFilter = DateFilter.weekend;
      final (from, to) = c.dateRange;
      expect(from, DateTime(2026, 10, 10));
      expect(to, DateTime(2026, 10, 12));
    });
  });
}

class _FailingRepo extends FakeActivityRepository {
  bool fail = true;
  @override
  Future<ActivityPage> list(ActivityQuery q) async {
    if (fail) throw const AppException('offline');
    return ActivityPage([sampleActivity()], null);
  }
}
