import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { runInNewContext } from 'node:vm';

const origin = 'https://study.example.test';
const appPaths = ['/', '/index.html', '/assets/app.js', '/downloads/timetable.pdf'];
const template = await readFile(new URL('../scripts/service-worker.template.js', import.meta.url), 'utf8');
const script = template.replace('__CACHE_VERSION__', 'test').replace('__PRECACHE_URLS__', JSON.stringify(appPaths));

function worker() {
  const handlers = new Map();
  const storage = new Map([['studydesk-earlier', new Map()], ['other-app', new Map()]]);
  const network = [];
  let skipped = 0;
  let claims = 0;
  const urlOf = (entry) => new URL(entry.url ?? entry, origin).href;
  const caches = {
    has: async (name) => storage.has(name),
    keys: async () => [...storage.keys()],
    delete: async (name) => storage.delete(name),
    open: async (name) => {
      if (!storage.has(name)) storage.set(name, new Map());
      const cache = storage.get(name);
      return {
        addAll: async (urls) => { for (const url of urls) cache.set(urlOf(url), `saved: ${new URL(urlOf(url)).pathname}`); },
        keys: async () => [...cache.keys()].map((url) => new Request(url)),
      };
    },
    match: async (entry, { cacheName, ignoreVary }) => {
      assert.equal(ignoreVary, true);
      const saved = storage.get(cacheName)?.get(urlOf(entry));
      return saved ? new Response(saved) : undefined;
    },
  };
  runInNewContext(script, {
    URL, Request: function (path, options) { return new Request(urlOf(path), options); }, caches,
    fetch: async (request) => {
      network.push(request.url);
      return new Response('network copy');
    },
    self: {
      location: { origin }, clients: { claim: async () => { claims += 1; } },
      skipWaiting: async () => { skipped += 1; },
      addEventListener: (name, handler) => handlers.set(name, handler),
    },
  });

  async function dispatch(name, event = {}) {
    let result;
    const respond = (promise) => { result = promise; };
    handlers.get(name)({ ...event, waitUntil: respond, respondWith: respond });
    return result;
  }
  async function status() {
    let reply;
    await dispatch('message', {
      data: { type: 'STUDYDESK_OFFLINE_STATUS' },
      ports: [{ postMessage(message) { reply = message.ready; } }],
    });
    return reply;
  }
  function load(path, { mode = 'navigate', method = 'GET' } = {}) {
    return dispatch('fetch', { request: { url: urlOf(path), mode, method } });
  }
  return { dispatch, status, load, storage, network, get skipped() { return skipped; }, get claims() { return claims; } };
}

test('the worker serves the pinned HTML and downloads without waiting for the network', async () => {
  const app = worker();
  await app.dispatch('install');
  assert.equal(await (await app.load('/?from=homescreen')).text(), 'saved: /');
  assert.equal(await (await app.load('/index.html')).text(), 'saved: /');
  assert.equal(await (await app.load('/downloads/timetable.pdf', { mode: 'cors' })).text(), 'saved: /downloads/timetable.pdf');
  assert.deepEqual(app.network, []);
});

test('readiness and update activation require a complete cache', async () => {
  const app = worker();
  assert.equal(await app.status(), false);
  await app.dispatch('install');
  assert.equal(await app.status(), true);
  const activate = () => app.dispatch('message', { data: { type: 'STUDYDESK_ACTIVATE_UPDATE' }, ports: [] });
  await activate();
  assert.equal(app.skipped, 1);
  app.storage.get('studydesk-test').delete(`${origin}/assets/app.js`);
  assert.equal(await app.status(), false);
  await activate();
  assert.equal(app.skipped, 1);
  assert.equal(await (await app.load('/assets/app.js', { mode: 'cors' })).text(), 'network copy');
});

test('activation prunes only old StudyDesk caches; unrelated requests are not intercepted', async () => {
  const app = worker();
  await app.dispatch('install');
  await app.dispatch('activate');
  assert.deepEqual([...app.storage.keys()], ['other-app', 'studydesk-test']);
  assert.equal(app.claims, 1);
  assert.equal(await app.load('https://another.example.test/'), undefined);
  assert.equal(await app.load('/api/account', { mode: 'cors' }), undefined);
  assert.equal(await app.load('/', { method: 'POST' }), undefined);
});
