import { createHash } from 'node:crypto';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import { join, relative, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const dist = new URL('../dist/', import.meta.url);
const template = await readFile(new URL('./service-worker.template.js', import.meta.url), 'utf8');
const entries = (await readdir(dist, { recursive: true, withFileTypes: true }))
  .filter((item) => item.isFile() && item.name !== 'sw.js')
  .map((item) => relative(fileURLToPath(dist), join(item.parentPath, item.name)).split(sep).join('/'))
  .sort();
if (!entries.includes('index.html')) throw new Error('Build the app before generating the service worker.');

const hash = createHash('sha256').update(template);
for (const file of entries) {
  hash.update(file).update(await readFile(new URL(file, dist)));
}
const version = hash.digest('hex').slice(0, 16);
const precache = ['/', ...entries.map((file) => `/${file}`)];
await writeFile(new URL('sw.js', dist), template
  .replace('__CACHE_VERSION__', version)
  .replace('__PRECACHE_URLS__', JSON.stringify(precache)));
console.log(`Offline cache: ${precache.length} URLs (${version}).`);
