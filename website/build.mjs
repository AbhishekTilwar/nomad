import { cp, mkdir, rm } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '..');
const source = path.join(here, 'src');
const output = path.join(here, 'dist');

await rm(output, { recursive: true, force: true });
await mkdir(path.join(output, 'assets', 'fonts'), { recursive: true });
await cp(source, output, { recursive: true });

const files = [
  ['app/assets/images/logo_mark.png', 'assets/brand/logo_mark.png'],
  ['app/assets/images/logo_wordmark.png', 'assets/brand/logo_wordmark.png'],
  ['app/assets/fonts/Inter-Regular.ttf', 'assets/fonts/Inter-Regular.ttf'],
  ['app/assets/fonts/Inter-Medium.ttf', 'assets/fonts/Inter-Medium.ttf'],
  ['app/assets/fonts/Inter-SemiBold.ttf', 'assets/fonts/Inter-SemiBold.ttf'],
  ['app/assets/fonts/Inter-Bold.ttf', 'assets/fonts/Inter-Bold.ttf'],
];

for (const [from, to] of files) {
  const destination = path.join(output, to);
  await mkdir(path.dirname(destination), { recursive: true });
  await cp(path.join(repo, from), destination);
}

console.log(`Built Nomad Mingle website to ${path.relative(here, output)}/`);
