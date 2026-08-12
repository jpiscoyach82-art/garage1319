const CACHE = "garage1319-release-1";
const CORE = ["./","./index.html","./manifest.webmanifest","./g1319-192.png","./g1319-512.png"];

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;
  const url = new URL(event.request.url);

  // Always prefer network for app HTML so a new release is visible immediately.
  if (url.origin === location.origin && (url.pathname.endsWith("/") || url.pathname.endsWith(".html"))) {
    event.respondWith(
      fetch(event.request).then(response => {
        const copy = response.clone();
        caches.open(CACHE).then(c => c.put(event.request, copy));
        return response;
      }).catch(() => caches.match(event.request).then(r => r || caches.match("./index.html")))
    );
    return;
  }

  // Cache-first for static local assets.
  event.respondWith(
    caches.match(event.request).then(cached => cached || fetch(event.request).then(response => {
      if (url.origin === location.origin) {
        const copy=response.clone();
        caches.open(CACHE).then(c=>c.put(event.request,copy));
      }
      return response;
    }))
  );
});
