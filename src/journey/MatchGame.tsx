import { useMemo, useRef, useState } from 'react'
import { asset } from '../data'
import { useSigns, type Sign } from '../Signs'
import { matchPairs, RULES } from './engine'
import { Mascot } from './Mascots'
import { play } from './sounds'

/** A round of the sign matching game: pick a sign, then its meaning. Five pairs; mistakes are counted but cost nothing. */
export function MatchGame({ onFinish, onClose }: { onFinish: () => void; onClose: () => void }) {
  const signs = useSigns()
  const seed = useRef(Math.floor(Math.random() * 10_000)).current
  const pairs = useMemo(() => matchPairs<Sign>(signs, RULES.matchPairs, seed), [signs, seed])
  const meanings = useMemo(() => [...pairs].sort(() => Math.random() - 0.5), [pairs])
  const [picked, setPicked] = useState<string | null>(null)
  const [matched, setMatched] = useState<string[]>([])
  const [wrong, setWrong] = useState<string | null>(null)
  const [mistakes, setMistakes] = useState(0)
  const paid = useRef(false)
  const done = pairs.length > 0 && matched.length === pairs.length

  const pickMeaning = (n: string) => {
    if (matched.includes(n) || !picked) return
    if (picked === n) {
      const all = [...matched, n]
      setMatched(all)
      setPicked(null)
      if (all.length === pairs.length) {
        play('complete')
        if (!paid.current) {
          paid.current = true
          onFinish()
        }
      } else play('star')
    } else {
      setMistakes((m) => m + 1)
      setWrong(n)
      play('wrong')
      setTimeout(() => setWrong(null), 600)
    }
  }

  if (!Object.keys(signs).length) return <p className="center muted">Chargement…</p>

  return (
    <div className="lesson">
      <header className="lesson-bar">
        <button className="icon-btn" onClick={onClose} aria-label="Fermer">✕</button>
        <div className="track lesson-track" aria-hidden="true">
          <div className="track-fill" style={{ transform: `scaleX(${Math.max(0.04, pairs.length ? matched.length / pairs.length : 0)})`, background: 'var(--ring-green)' }} />
        </div>
      </header>
      <main className="lesson-body">
        <div className="talking">
          <p className="bubble">{done ? 'Bravo ! Tous les panneaux sont associés.' : 'Touchez un panneau, puis son sens.'}</p>
          <Mascot name="rouli" mood={done ? 'cheer' : mistakes ? 'thinking' : 'happy'} size={72} />
        </div>
        <h1 className="qtext">Associez chaque panneau à son sens</h1>
        {!pairs.length && <p className="muted">Pas assez de panneaux illustrés pour ce jeu.</p>}
        <div className="match">
          <div className="match-col signs-col">
            {pairs.map((s) => (
              <button key={s.n} className={`match-tile ${picked === s.n ? 'picked' : ''} ${matched.includes(s.n) ? 'done' : ''}`} onClick={() => !matched.includes(s.n) && (setPicked(s.n), play('tap'))} aria-pressed={picked === s.n} aria-label={`Panneau ${s.n}`}>
                <img src={asset(s.img!)} alt="" width="64" height="64" />
              </button>
            ))}
          </div>
          <div className="match-col">
            {meanings.map((s) => (
              <button key={s.n} className={`match-tile meaning ${wrong === s.n ? 'wrong' : ''} ${matched.includes(s.n) ? 'done' : ''}`} onClick={() => pickMeaning(s.n)}>
                <span>{s.fr}</span>
                {matched.includes(s.n) && <span className="mark ok">✓</span>}
              </button>
            ))}
          </div>
        </div>
        {done && (
          <>
            <p className="bonus">⚡ +{RULES.xpMatch} XP</p>
            {mistakes > 0 && <p className="muted small">{mistakes} erreur{mistakes > 1 ? 's' : ''} : le jeu ne retire rien.</p>}
            <button className="primary wide" onClick={onClose} autoFocus>Continuer</button>
          </>
        )}
      </main>
    </div>
  )
}
