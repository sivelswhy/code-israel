import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.tsx'
import { MascotGallery } from './journey/Mascots'

// `?mode=journey` opens the Parcours, like `-appMode journey` in the apps: handy to compare screens.
try {
  const m = new URLSearchParams(location.search).get('mode')
  if (m === 'journey' || m === 'classic') localStorage.setItem('code-israel:mode', m)
} catch {
  // No storage: the mode stays the default one.
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    {new URLSearchParams(location.search).has('mascots') ? <MascotGallery /> : <App />}
  </StrictMode>,
)

// Offline support: only in the built app, where the service worker has the file list.
if ('serviceWorker' in navigator && import.meta.env.PROD) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register(`${import.meta.env.BASE_URL}sw.js`).catch(() => {
      // Private mode or an old browser: the app simply needs a connection.
    })
  })
}

// Progress lives in the browser: ask for persistent storage so it is not cleared when space runs low.
// Browsers may refuse (or ignore) the request; the app works the same, the data is just less protected.
navigator.storage?.persist?.().catch(() => {})
