import { mkdir, readFile, writeFile } from 'node:fs/promises';

const root = new URL('../', import.meta.url);
const check = process.argv.includes('--check');
const assets = new Map([
  ['src/data/semester.json', 'data/semester.json'],
  ['src/data/plan.json', 'data/plan.json'],
  ['src/data/guides.json', 'data/guides.json'],
  ['src/data/finance-quiz.json', 'data/finance-quiz.json'],
  ['public/art/planner.webp', 'art/planner.webp'],
  ['public/icons/icon-192.png', 'art/app-mark.png'],
  ['public/downloads/bit-year-2-timetable.pdf', 'downloads/bit-year-2-timetable.pdf'],
  ['public/downloads/bit-year-2-study-planner.docx', 'downloads/bit-year-2-study-planner.docx'],
  ['public/downloads/is274-ooad-revision.pptx', 'downloads/is274-ooad-revision.pptx'],
]);

// Copy only the app's curated assets. Never bundle the private materials directory.
const stale = [];
for (const [source, path] of assets) {
  const content = await readFile(new URL(source, root));
  const target = new URL(`mobile/assets/${path}`, root);
  if (check) {
    const current = await readFile(target).catch(() => null);
    if (!current?.equals(content)) stale.push(path);
  } else {
    await mkdir(new URL('./', target), { recursive: true });
    await writeFile(target, content);
  }
}
if (stale.length) {
  console.error(`Flutter assets out of sync: ${stale.join(', ')}. Run npm run flutter:sync.`);
  process.exitCode = 1;
} else {
  console.log(`${check ? 'Verified' : 'Synced'} ${assets.size} offline Flutter assets.`);
}
