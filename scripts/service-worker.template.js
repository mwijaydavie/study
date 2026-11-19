const PREFIX = 'studydesk-';
const CACHE = `${PREFIX}__CACHE_VERSION__`;
const PRECACHE = __PRECACHE_URLS__;
const PATHS = new Set(PRECACHE);

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await cache.addAll(PRECACHE.map((url) => new Request(url, { cache: 'reload' })));
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((key) => key.startsWith(PREFIX) && key !== CACHE).map((key) => caches.delete(key)));
    await self.clients.claim();
  })());
});

async function offlineCopyReady() {
  if (!await caches.has(CACHE)) return false;
  const cache = await caches.open(CACHE);
  const saved = new Set((await cache.keys()).map((request) => new URL(request.url).pathname));
  return PRECACHE.every((path) => saved.has(path));
}

self.addEventListener('message', (event) => {
  if (event.data?.type === 'STUDYDESK_OFFLINE_STATUS' && event.ports[0]) {
    const port = event.ports[0];
    event.waitUntil(offlineCopyReady().catch(() => false).then((ready) => port.postMessage({ ready })));
  } else if (event.data?.type === 'STUDYDESK_ACTIVATE_UPDATE') {
    event.waitUntil((async () => {
      if (await offlineCopyReady()) await self.skipWaiting();
    })());
  }
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;
  const appNavigation = request.mode === 'navigate' && ['/', '/index.html'].includes(url.pathname);
  if (!appNavigation && (!PATHS.has(url.pathname) || url.search)) return;

  event.respondWith((async () => {
    // Start from the active release even on a weak connection. Updates have
    // their own complete precache, so the HTML never depends on the next release.
    // Match the canonical URL even if the request adds Origin (Vary: Origin).
    const path = appNavigation ? '/' : url.pathname;
    const saved = await caches.match(path, { cacheName: CACHE, ignoreVary: true }).catch(() => undefined);
    return saved || fetch(request);
  })());
});
