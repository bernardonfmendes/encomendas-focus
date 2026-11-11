// Deixa a app abrir sem rede: rede primeiro, cópia guardada como reserva.
// Só ficheiros do próprio site; os pedidos à base de dados nunca passam por aqui.
const V = "cf-v1";
self.addEventListener("install", e => { e.waitUntil(caches.open(V).then(c => c.addAll(["/", "/manifest.webmanifest", "/icon.svg", "/icon-192.png"])).then(() => self.skipWaiting())); });
self.addEventListener("activate", e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== V).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener("fetch", e => {
  const r = e.request, u = new URL(r.url);
  if (r.method !== "GET" || u.origin !== location.origin) return;
  e.respondWith(fetch(r).then(res => { if (res.ok) { const cp = res.clone(); caches.open(V).then(c => c.put(r, cp)); } return res; })
    .catch(() => caches.match(r).then(m => m || (r.mode === "navigate" ? caches.match("/") : Response.error()))));
});
