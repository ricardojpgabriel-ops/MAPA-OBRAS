// Service worker — torna a app instalável e disponível offline.
// resultados.json usa "network-first" para apanhar dados novos; o resto é "cache-first".
const CACHE = 'scanner-taloes-v1';
const ASSETS = [
  './',
  './index.html',
  './manifest.webmanifest',
  './resultados.json',
  './icon-192.png',
  './icon-512.png'
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);
  if (e.request.method !== 'GET') return;

  // resultados.json: tenta a rede primeiro, cai para a cache se estiver offline.
  if (url.pathname.endsWith('resultados.json')) {
    e.respondWith(
      fetch(e.request).then((res) => {
        const copy = res.clone();
        caches.open(CACHE).then((c) => c.put(e.request, copy));
        return res;
      }).catch(() => caches.match(e.request))
    );
    return;
  }

  // restantes recursos próprios: cache-first.
  if (url.origin === location.origin) {
    e.respondWith(caches.match(e.request).then((hit) => hit || fetch(e.request)));
  }
});
