import { useCallback, useEffect, useRef, useState } from 'react'
import type { Progress } from './store'
import { codeId, displayCode, generateCode, lastSync, normalizeCode, saveCode, savedCode, syncNow, syncServer } from './sync'
import './prep.css'

export interface SyncState {
  /** False when no sync server has been set up: the feature stays hidden. */
  available: boolean
  code: string | null
  busy: boolean
  error: string | null
  at: number | null
  enable: (code?: string) => Promise<void>
  now: () => Promise<void>
  stop: () => void
}

const BASE = import.meta.env.BASE_URL

/**
 * Keeps the progress the same on every device that uses the same sync code: on opening, when the page comes back to the
 * front, and a few seconds after each change.
 */
export function useSync(progress: Progress, replace: (p: Progress) => void): SyncState {
  const [available, setAvailable] = useState(false)
  const [code, setCode] = useState<string | null>(savedCode)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [at, setAt] = useState<number | null>(lastSync)
  const latest = useRef(progress)
  latest.current = progress
  const uploaded = useRef<number | undefined>(undefined)
  const running = useRef(false)

  useEffect(() => {
    syncServer(BASE).then((url) => setAvailable(!!url))
  }, [])

  const run = useCallback(
    async (c: string) => {
      if (running.current) return
      running.current = true
      setBusy(true)
      try {
        const merged = await syncNow(latest.current, c, BASE)
        uploaded.current = merged.modified
        replace(merged)
        setError(null)
        setAt(Date.now())
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Synchronisation impossible.')
      } finally {
        running.current = false
        setBusy(false)
      }
    },
    [replace],
  )

  useEffect(() => {
    if (!available || !code) return
    void run(code)
    const onVisible = () => document.visibilityState === 'visible' && void run(code)
    document.addEventListener('visibilitychange', onVisible)
    return () => document.removeEventListener('visibilitychange', onVisible)
  }, [available, code, run])

  // A few seconds after the last change made on this device (not after one that came from the server).
  useEffect(() => {
    if (!available || !code || progress.modified === uploaded.current) return
    const t = setTimeout(() => void run(code), 8000)
    return () => clearTimeout(t)
  }, [available, code, progress.modified, run])

  return {
    available,
    code,
    busy,
    error,
    at,
    enable: async (entered) => {
      const next = entered ? normalizeCode(entered) : generateCode()
      if (!next || !(await codeId(next))) {
        setError('Ce code n’est pas valide : il comporte 16 lettres et chiffres.')
        return
      }
      saveCode(displayCode(normalizeCode(next)!))
      setCode(displayCode(normalizeCode(next)!))
    },
    now: async () => {
      if (code) await run(code)
    },
    stop: () => {
      saveCode(null)
      setCode(null)
      setAt(null)
      setError(null)
    },
  }
}

/** The "keep my progress on all my devices" card of the guide. */
export function SyncPanel({ sync }: { sync: SyncState }) {
  const [entering, setEntering] = useState(false)
  const [text, setText] = useState('')
  const [copied, setCopied] = useState(false)
  if (!sync.available) return null

  if (!sync.code) {
    return (
      <section className="card sync-card">
        <h2>Garder ma progression sur tous mes appareils</h2>
        <p className="muted small">
          Un code secret suffit : pas de compte, pas d’e-mail, gratuit. Le même code sur le site, sur l’iPhone et sur le Mac, et la progression est la même partout.
        </p>
        {entering ? (
          <form onSubmit={(e) => { e.preventDefault(); void sync.enable(text) }}>
            <label className="date-field">
              Votre code
              <input value={text} onChange={(e) => setText(e.target.value)} placeholder="XXXX-XXXX-XXXX-XXXX" autoCapitalize="characters" autoComplete="off" spellCheck={false} />
            </label>
            <div className="date-actions">
              <button className="primary" type="submit">Rejoindre</button>
              <button type="button" className="link" onClick={() => setEntering(false)}>Annuler</button>
            </div>
          </form>
        ) : (
          <div className="date-actions">
            <button className="primary" onClick={() => void sync.enable()}>Créer mon code</button>
            <button className="link" onClick={() => setEntering(true)}>J’ai déjà un code</button>
          </div>
        )}
        {sync.error && <p className="sync-error" role="alert">{sync.error}</p>}
      </section>
    )
  }

  return (
    <section className="card sync-card">
      <h2>Synchronisation active</h2>
      <p className="muted small">Entrez ce code sur vos autres appareils (« J’ai déjà un code »). Gardez-le secret : celui qui le connaît peut lire et modifier votre progression.</p>
      <div className="sync-code" aria-label={`Votre code : ${sync.code}`}>
        <code>{sync.code}</code>
        <button className="secondary" onClick={() => navigator.clipboard?.writeText(sync.code!).then(() => { setCopied(true); setTimeout(() => setCopied(false), 2000) })}>
          {copied ? 'Copié ✓' : 'Copier'}
        </button>
      </div>
      <p className="muted small" role="status">
        {sync.busy ? 'Synchronisation…' : sync.error ? '' : sync.at ? `Dernière synchronisation : ${new Date(sync.at).toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}` : ''}
      </p>
      {sync.error && <p className="sync-error" role="alert">{sync.error}</p>}
      <div className="date-actions">
        <button className="primary" onClick={() => void sync.now()} disabled={sync.busy}>Synchroniser maintenant</button>
        <button className="link" onClick={() => window.confirm('Arrêter la synchronisation sur cet appareil ? Votre progression reste ici ; notez votre code pour la retrouver ailleurs.') && sync.stop()}>Arrêter</button>
      </div>
    </section>
  )
}
