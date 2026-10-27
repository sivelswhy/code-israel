// Service worker: makes the app work offline once it has been opened.
// The build id and the file list below are filled in at build time by the plugin in vite.config.ts.
const BUILD = '__BUILD__'
// Paths are relative to the service worker's scope, so the site can live in a subfolder.
const ROOT = self.registration.scope
const PRECACHE = __PRECACHE__.map((p) => new URL(p, ROOT).href)
const CACHE = `code-israel-${BUILD}`

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(CACHE)
      .then((cache) => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting()),
  )
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) => Promise.all(keys.filter((k) => k.startsWith('code-israel-') && k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  )
})

self.addEventListener('fetch', (event) => {
  const { request } = event
  const url = new URL(request.url)
  // Only this site's own files: the local AI model is downloaded and cached by its own library.
  if (request.method !== 'GET' || url.origin !== self.location.origin) return

  if (request.mode === 'navigate') {
    // Network first, so a new version shows up as soon as the user is online.
    event.respondWith(fetch(request).catch(() => caches.match(new URL('index.html', ROOT)).then((r) => r ?? Response.error())))
    return
  }

  event.respondWith(
    caches.match(request).then(
      (hit) =>
        hit ??
        fetch(request).then((response) => {
          // Large files left out of the precache (the AI engine) are kept after their first use.
          if (response.ok) {
            const copy = response.clone()
            caches.open(CACHE).then((cache) => cache.put(request, copy))
          }
          return response
        }),
    ),
  )
})
