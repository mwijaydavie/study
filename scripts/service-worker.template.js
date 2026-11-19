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

self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;
  if (request.mode === 'navigate' && ['/', '/index.html'].includes(url.pathname)) {
    event.respondWith((async () => {
      // A versioned shell and its asset set are kept together for offline loads.
      const cache = await caches.open(CACHE);
      try {
        const response = await fetch(request);
        return response.ok ? response : (await cache.match('/')) || response;
      } catch {
        return (await cache.match('/')) || Response.error();
      }
    })());
  } else if (PATHS.has(url.pathname) && !url.search) {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE);
      // This allowlist is static and same-origin. Match the precache URL even
      // when a module or font request adds an Origin header (Vary: Origin).
      return (await cache.match(url.pathname, { ignoreVary: true })) || fetch(request);
    })());
  }
});
