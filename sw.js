// ADULAM — Service Worker v2
// Red primero para la app (así cada publicación llega sola); la caché solo se usa sin internet.
const CACHE = 'adulam-v2';
const SHELL = ['app.html', 'manifest.json'];

self.addEventListener('install', function(e){
  e.waitUntil(caches.open(CACHE).then(function(c){ return c.addAll(SHELL); }));
  self.skipWaiting();
});

self.addEventListener('activate', function(e){
  e.waitUntil(caches.keys().then(function(keys){
    return Promise.all(keys.filter(function(k){ return k!==CACHE; }).map(function(k){ return caches.delete(k); }));
  }));
  self.clients.claim();
});

self.addEventListener('fetch', function(e){
  if(e.request.method !== 'GET') return;
  // Supabase y librerías externas: siempre a la red, sin tocar
  if(e.request.url.includes('supabase.co') || e.request.url.includes('lucide') || e.request.url.includes('tailwind')) return;
  e.respondWith(
    fetch(e.request).then(function(resp){
      if(resp && resp.status===200 && resp.type==='basic'){
        var clone=resp.clone();
        caches.open(CACHE).then(function(c){ c.put(e.request, clone); });
      }
      return resp;
    }).catch(function(){
      return caches.match(e.request).then(function(cached){ return cached || caches.match('app.html'); });
    })
  );
});
