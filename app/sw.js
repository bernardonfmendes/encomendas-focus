// Deixa a app abrir sem rede (rede primeiro, cópia guardada como reserva) e mostra as notificações.
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

// Notificações push
self.addEventListener("push", e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { d = { title: "Compras", body: e.data ? e.data.text() : "" }; }
  e.waitUntil(self.registration.showNotification(d.title || "Compras", {
    body: d.body || "", icon: "/icon-192.png", badge: "/icon-192.png",
    tag: d.tag || undefined, renotify: !!d.tag, data: { url: d.url || "/#pedidos" }
  }));
});
self.addEventListener("notificationclick", e => {
  e.notification.close();
  const url = (e.notification.data && e.notification.data.url) || "/#pedidos";
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(cs => {
    for (const c of cs) { if ("focus" in c) { if (c.navigate) c.navigate(url).catch(() => {}); return c.focus(); } }
    return self.clients.openWindow(url);
  }));
});
