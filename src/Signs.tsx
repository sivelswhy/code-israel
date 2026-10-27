import { useEffect, useMemo, useState } from 'react'
import { asset, type Question } from './data'
import { BackButton } from './App'

export interface Sign {
  cat: string
  fr: string
  he?: string
  img?: string
  credit?: string
  src?: string
}

let cache: Promise<Record<string, Sign>> | null = null

export function loadSigns(): Promise<Record<string, Sign>> {
  cache ??= fetch(asset('data/signs.json')).then((r) => {
    if (!r.ok) throw new Error(`HTTP ${r.status}`)
    return r.json()
  })
  return cache
}

export function useSigns() {
  const [signs, setSigns] = useState<Record<string, Sign>>({})
  useEffect(() => {
    loadSigns().then(setSigns, () => {})
  }, [])
  return signs
}

const SIGN_NUMBER = /^\s*(\d{3}פ?)\s*\.?\s*$/

/** True when the question is about road signs, so 3-digit numbers refer to sign numbers. */
function aboutSigns(q: Question) {
  return q.cat === 'signs' || /panneau|תמרור|signalisation|marquage/i.test(q.q)
}

/** The sign number an answer consists of, e.g. "432", if any. */
export function answerSign(q: Question, answer: string, signs: Record<string, Sign>): string | null {
  const m = answer.match(SIGN_NUMBER)
  return m && aboutSigns(q) && signs[m[1]] ? m[1] : null
}

/** Every sign number cited in the question or its answers. */
export function citedSigns(q: Question, signs: Record<string, Sign>): string[] {
  if (!aboutSigns(q)) return []
  const found = new Set<string>()
  for (const text of [q.q, ...q.a]) {
    for (const m of text.matchAll(/(?<![\d,.])(\d{3}פ?)(?![\d,.]|\s?(?:km|kg|m\b|mètres|%))/g)) if (signs[m[1]]) found.add(m[1])
  }
  return [...found]
}

export function SignImage({ n, sign, size = 56 }: { n: string; sign?: Sign; size?: number }) {
  if (!sign?.img) return <span className="sign-missing" style={{ width: size, height: size }}>{n}</span>
  return <img className="sign-img" src={asset(sign.img)} alt={`Panneau ${n}`} width={size} height={size} loading="lazy" />
}

/** One sign with its official meaning. */
export function SignRow({ n, sign }: { n: string; sign?: Sign }) {
  return (
    <div className="sign-row">
      <SignImage n={n} sign={sign} />
      <div>
        <strong>Panneau {n}</strong>
        <p>{sign?.fr ?? 'Signification non disponible.'}</p>
      </div>
    </div>
  )
}

const CATS = ['Danger', 'Obligation', 'Priorité', 'Interdiction', 'Transports en commun', 'Information', 'Feux', 'Marquage', 'Chantier']

export function SignLexicon({ onBack }: { onBack: () => void }) {
  const signs = useSigns()
  const [query, setQuery] = useState('')
  const groups = useMemo(() => {
    const n = query.trim().toLowerCase()
    const entries = Object.entries(signs).filter(([k, s]) => !n || k.includes(n) || s.fr.toLowerCase().includes(n))
    return CATS.map((c) => [c, entries.filter(([, s]) => s.cat === c)] as const).filter(([, e]) => e.length)
  }, [signs, query])

  return (
    <main className="page">
      <BackButton onClick={onBack} />
      <h1 className="title">Lexique des panneaux</h1>
      <p className="lede">Le tableau officiel israélien des panneaux, avec leur numéro tel qu'il apparaît dans les questions de l'examen.</p>
      <div className="search-bar">
        <input type="search" placeholder="Numéro ou mot-clé (ex. 433, stationnement)" value={query} onChange={(e) => setQuery(e.target.value)} />
      </div>
      {groups.map(([cat, entries]) => (
        <section key={cat}>
          <h2 className="section-title">{cat}</h2>
          <div className="card sign-list">
            {entries.map(([n, s]) => (
              <SignRow key={n} n={n} sign={s} />
            ))}
          </div>
        </section>
      ))}
      <p className="muted small footer">
        Significations : tableau officiel des panneaux (ministère des Transports), via Wikipédia en hébreu. Images : Wikimedia Commons (domaine public ou CC BY-SA), auteurs cités dans le fichier de données.
      </p>
    </main>
  )
}
