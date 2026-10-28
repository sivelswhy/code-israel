import { useEffect, useState } from 'react'
import './install.css'
import { Mobile } from 'reicon-react'

/** The browser's install prompt (Chrome on Android), not in the standard typings. */
interface InstallPrompt extends Event {
  prompt: () => Promise<void>
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>
}

const KEY = 'code-israel:install-hint'
/** After "Plus tard", the hint stays away this long. */
const SNOOZE_MS = 14 * 24 * 3600 * 1000

type Platform = 'ios' | 'android' | 'other'

function platform(): Platform {
  const ua = navigator.userAgent
  // An iPad asks for the desktop site and says it is a Mac: touch gives it away.
  if (/iPhone|iPad|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)) return 'ios'
  if (/Android/.test(ua)) return 'android'
  return 'other'
}

const installed = () => matchMedia('(display-mode: standalone)').matches || (navigator as Navigator & { standalone?: boolean }).standalone === true
const onPhone = () => matchMedia('(pointer: coarse)').matches && Math.min(screen.width, screen.height) < 820

function hiddenByChoice() {
  try {
    const v = localStorage.getItem(KEY)
    return v === 'done' || (!!v && Date.now() - Number(v) < SNOOZE_MS)
  } catch {
    return false
  }
}

function remember(value: string) {
  try {
    localStorage.setItem(KEY, value)
  } catch {
    // Storage unavailable: the hint comes back next time.
  }
}

/** On a phone, in the browser: tells the visitor that the site installs like an app, with the steps for their phone. */
export function InstallHint() {
  const [show, setShow] = useState(() => onPhone() && !installed() && !hiddenByChoice())
  const [steps, setSteps] = useState(false)
  const [prompt, setPrompt] = useState<InstallPrompt | null>(null)
  const kind = platform()

  useEffect(() => {
    const before = (e: Event) => {
      e.preventDefault()
      setPrompt(e as InstallPrompt)
    }
    const done = () => {
      remember('done')
      setShow(false)
    }
    window.addEventListener('beforeinstallprompt', before)
    window.addEventListener('appinstalled', done)
    return () => {
      window.removeEventListener('beforeinstallprompt', before)
      window.removeEventListener('appinstalled', done)
    }
  }, [])

  if (!show) return null

  const later = () => {
    remember(String(Date.now()))
    setShow(false)
  }
  const never = () => {
    remember('done')
    setShow(false)
  }
  const install = async () => {
    if (!prompt) return
    await prompt.prompt()
    const { outcome } = await prompt.userChoice
    if (outcome === 'accepted') never()
    setPrompt(null)
  }

  return (
    <aside className="install-hint" aria-label="Installer l’application">
      <div className="install-head">
        <span className="install-icon" aria-hidden="true"><Mobile size={28} /></span>
        <div>
          <strong>Installez l’app sur votre téléphone</strong>
          <p>Elle s’ouvre comme une vraie app, en plein écran, et marche aussi sans connexion.</p>
        </div>
      </div>

      {steps && (
        <ol className="install-steps">
          {kind === 'ios' && (
            <>
              <li>Ouvrez ce site dans <strong>Safari</strong>.</li>
              <li>Touchez le bouton <strong>Partager</strong> <ShareIcon /> en bas de l’écran.</li>
              <li>Faites défiler et touchez <strong>« Sur l’écran d’accueil »</strong>.</li>
              <li>Touchez <strong>« Ajouter »</strong> : l’icône apparaît avec vos autres apps.</li>
            </>
          )}
          {kind === 'android' && (
            <>
              <li>Touchez le menu <strong>⋮</strong> en haut à droite de Chrome.</li>
              <li>Touchez <strong>« Installer l’application »</strong> (ou « Ajouter à l’écran d’accueil »).</li>
              <li>Confirmez : l’icône apparaît avec vos autres apps.</li>
            </>
          )}
          {kind === 'other' && (
            <>
              <li>Ouvrez le menu de votre navigateur.</li>
              <li>Choisissez <strong>« Installer l’application »</strong> ou <strong>« Ajouter à l’écran d’accueil »</strong>.</li>
              <li>Confirmez : l’icône apparaît avec vos autres apps.</li>
            </>
          )}
        </ol>
      )}

      <div className="install-actions">
        {prompt && <button className="primary" onClick={install}>Installer maintenant</button>}
        <button className={prompt ? 'secondary' : 'primary'} onClick={() => setSteps(!steps)} aria-expanded={steps}>
          {steps ? 'Masquer les étapes' : 'Comment faire ?'}
        </button>
        <button className="link" onClick={later}>Plus tard</button>
        <button className="link" onClick={never}>Ne plus afficher</button>
      </div>
    </aside>
  )
}

/** The Share button of Safari: a square with an arrow going up. */
function ShareIcon() {
  return (
    <svg className="share-icon" width="18" height="20" viewBox="0 0 18 22" aria-label="icône Partager" role="img">
      <path d="M9 1v13M5 5l4-4 4 4M3 9H2a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1V10a1 1 0 0 0-1-1h-1" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}
