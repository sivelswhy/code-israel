import { useEffect, useMemo, useState } from 'react'
import { asset, CATEGORIES, EXAM, shuffle, type Category, type Question } from './data'
import { BackButton, Rings } from './App'
import { useSigns, type Sign } from './Signs'
import { passStreak, plan, readiness, weakest, type Readiness } from './readiness'
import { play } from './journey/sounds'
import type { ExamRecord, Stat } from './store'
import './prep.css'

const pct = (p: number) => `${Math.min(99, Math.max(0, Math.round(p * 100)))} %`
const gaugeColor = (p: number) => (p >= 0.8 ? 'var(--ring-green)' : p >= 0.5 ? 'var(--ring-orange)' : 'var(--sign-red)')

/**
 * "Am I ready?": the estimated chance of passing a mock exam, the weakest themes, the exam date and the history of mock
 * exams. An estimate from the learner's answers, never a promise.
 */
export function ReadinessCard({ pool, stats, exams, examDate, onPractice, onExamDate }: {
  pool: Question[]
  stats: Record<string, Stat>
  exams: ExamRecord[]
  examDate?: string
  onPractice: (category: Category) => void
  onExamDate: (date: string | undefined) => void
}) {
  const r = useMemo(() => readiness(pool, stats), [pool, stats])
  const p = plan(examDate, pool, stats)
  const streak = passStreak(exams)
  const [editing, setEditing] = useState(false)
  const last = exams.slice(-10)

  return (
    <section className="card readiness" aria-label="Préparation à l’examen">
      <h3>Préparation à l’examen</h3>
      <div className="readiness-top">
        <div className="gauge" role="img" aria-label={r.enoughData ? `Chance estimée de réussir un examen blanc : ${pct(r.passChance)}` : 'Estimation pas encore disponible'}>
          <Rings rings={[{ value: r.enoughData ? r.passChance : r.coverage, color: r.enoughData ? gaugeColor(r.passChance) : 'var(--ring-blue)' }]} size={84} stroke={12} />
          <span>{r.enoughData ? pct(r.passChance) : '–'}</span>
        </div>
        <div>
          <strong>{verdict(r)}</strong>
          <p className="muted small">
            {r.enoughData
              ? `Chance estimée de réussir un examen blanc (${EXAM.maxErrors} erreurs au plus). C’est une estimation d’après vos réponses, pas une garantie.`
              : `Répondez à des questions : l’estimation apparaît quand 25 % de la banque a été vue (${pct(r.coverage)} pour l’instant).`}
          </p>
        </div>
      </div>

      {r.enoughData && (
        <div className="weak">
          {weakest(r).slice(0, 2).map((t) => (
            <button key={t.category} onClick={() => onPractice(t.category)} aria-label={`Travailler ${CATEGORIES[t.category].label}, réussite estimée ${pct(t.chance)}`}>
              <strong>{CATEGORIES[t.category].label}</strong>
              <span className="meter-bar"><span style={{ transform: `scaleX(${t.chance})` }} /></span>
              <span className="mono muted small">{pct(t.chance)}</span>
            </button>
          ))}
        </div>
      )}

      <p className={`streak-line ${streak >= 3 ? 'ok' : ''}`}>
        {streak === 0 ? '🏁 Réussissez 3 examens blancs de suite avant le jour J.' : `${streak >= 3 ? '✅' : '🏁'} ${streak} examen${streak > 1 ? 's' : ''} blanc${streak > 1 ? 's' : ''} réussi${streak > 1 ? 's' : ''} d’affilée · visez 3`}
      </p>

      {last.length >= 2 && (
        <figure className="exam-bars" aria-label="Résultats des derniers examens blancs">
          <figcaption className="muted small">Mes derniers examens blancs</figcaption>
          <svg viewBox={`0 0 ${last.length * 22} 64`} preserveAspectRatio="none" role="img" aria-label={last.map((e) => `${EXAM.size - e.errors} sur ${EXAM.size}`).join(', ')}>
            {last.map((e, i) => {
              const h = ((EXAM.size - e.errors) / EXAM.size) * 60
              return <rect key={i} x={i * 22 + 3} y={62 - h} width="16" height={h} rx="3" fill={e.errors <= EXAM.maxErrors ? 'var(--ring-green)' : 'var(--sign-red)'} />
            })}
            <line x1="0" x2={last.length * 22} y1={62 - ((EXAM.size - EXAM.maxErrors) / EXAM.size) * 60} y2={62 - ((EXAM.size - EXAM.maxErrors) / EXAM.size) * 60} stroke="currentColor" strokeDasharray="3 3" opacity="0.4" />
          </svg>
        </figure>
      )}

      <hr />
      {p && !editing ? (
        <div className="exam-date">
          {p.isPast ? (
            <strong>📅 La date de votre examen est passée.</strong>
          ) : (
            <>
              <strong>📅 {p.daysLeft === 0 ? 'Votre examen est aujourd’hui. Bon courage !' : `Examen dans ${p.daysLeft} jour${p.daysLeft > 1 ? 's' : ''}`}</strong>
              <p className="muted small">
                {p.toLearn === 0
                  ? 'Tout est acquis : gardez le rythme avec un examen blanc de temps en temps.'
                  : `Il reste ${p.toLearn} question${p.toLearn > 1 ? 's' : ''} à apprendre ou à consolider : environ ${p.perDay} par jour.`}
              </p>
            </>
          )}
          <button className="link" onClick={() => setEditing(true)}>Changer la date</button>
        </div>
      ) : editing || !p ? (
        <div className="exam-date">
          {editing ? (
            <form onSubmit={(e) => { e.preventDefault(); setEditing(false) }}>
              <label className="date-field">
                Date de l’examen
                <input type="date" min={new Date().toISOString().slice(0, 10)} value={examDate ?? ''} onChange={(e) => onExamDate(e.target.value || undefined)} />
              </label>
              <div className="date-actions">
                <button type="submit" className="primary">Enregistrer</button>
                {examDate && <button type="button" className="link" onClick={() => { onExamDate(undefined); setEditing(false) }}>Retirer la date</button>}
              </div>
            </form>
          ) : (
            <button className="link strong" onClick={() => setEditing(true)}>📅 Définir la date de mon examen</button>
          )}
        </div>
      ) : null}
    </section>
  )
}

function verdict(r: Readiness) {
  if (!r.enoughData) return 'Estimation bientôt disponible'
  return r.passChance >= 0.8 ? 'Niveau très bon' : r.passChance >= 0.5 ? 'Niveau correct, à consolider' : 'Niveau à renforcer'
}

/** Opens a pre-filled public issue on GitHub to report a mistake in a question or its translation. */
export function ReportLink({ question }: { question: Question }) {
  const url = new URL('https://github.com/sivelswhy/code-israel/issues/new')
  url.searchParams.set('title', `Erreur dans la question ${question.id}`)
  url.searchParams.set('body', `Question n° ${question.id}\n\n> ${question.q}\n\nCe qui n’est pas correct (traduction, réponse, explication, image…) :\n`)
  return (
    <a className="report-link" href={url.toString()} target="_blank" rel="noreferrer">
      🚩 Signaler une erreur dans cette question
    </a>
  )
}

// ----------------------------------------------------------------------------------------------------- Guide

interface GuideData {
  sections: { title: string; items: string[] }[]
  links: { label: string; url: string }[]
  note: string
}
interface GlossaryGroup {
  title: string
  terms: { fr: string; he: string }[]
}

const fold = (s: string) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()

/** Practical help around the exam in Israel, and a French ↔ Hebrew glossary of the terms of the road code. */
export function GuideScreen({ onBack }: { onBack: () => void }) {
  const [guide, setGuide] = useState<GuideData | null>(null)
  const [glossary, setGlossary] = useState<GlossaryGroup[]>([])
  const [query, setQuery] = useState('')

  useEffect(() => {
    fetch(asset('data/guide.json')).then((r) => r.json()).then(setGuide, () => {})
    fetch(asset('data/glossary.json')).then((r) => r.json()).then(setGlossary, () => {})
  }, [])

  const q = fold(query.trim())
  const groups = glossary.map((g) => ({ ...g, terms: g.terms.filter((t) => !q || fold(t.fr).includes(q) || t.he.includes(query.trim())) })).filter((g) => g.terms.length)

  return (
    <main className="page">
      <BackButton onClick={onBack} />
      <h1 className="title">Guide</h1>
      {guide?.sections.map((s) => (
        <section key={s.title} className="card guide-section">
          <h2>{s.title}</h2>
          <ul>{s.items.map((i) => <li key={i}>{i}</li>)}</ul>
        </section>
      ))}
      {guide && (
        <section className="card guide-section">
          <h2>Pour aller plus loin</h2>
          <ul>{guide.links.map((l) => <li key={l.url}><a href={l.url} target="_blank" rel="noreferrer">{l.label}</a></li>)}</ul>
          <p className="muted small">{guide.note}</p>
        </section>
      )}

      <h2 className="section-title">Glossaire français ↔ hébreu</h2>
      <div className="search-bar">
        <input type="search" placeholder="Un mot, en français ou en hébreu" value={query} onChange={(e) => setQuery(e.target.value)} />
      </div>
      {groups.map((g) => (
        <section key={g.title}>
          <h3 className="glossary-title">{g.title}</h3>
          <div className="card glossary">
            {g.terms.map((t) => (
              <div key={t.fr} className="term">
                <span>{t.fr}</span>
                <span dir="rtl" lang="he">{t.he}</span>
              </div>
            ))}
          </div>
        </section>
      ))}
      <p className="muted small footer">Traductions indicatives. Le texte officiel de l’examen et de la loi est en hébreu : c’est lui qui fait foi.</p>
    </main>
  )
}

// ------------------------------------------------------------------------------------------------ Sign quiz

interface Round {
  sign: Sign & { n: string }
  options: string[]
}

/** Recognise the signs: a picture, four meanings, up to ten rounds. Each right answer earns an XP. */
export function SignQuiz({ onFinish, onClose }: { onFinish: (correct: number) => void; onClose: () => void }) {
  const signs = useSigns()
  const rounds = useMemo<Round[]>(() => {
    const all = Object.entries(signs).map(([n, s]) => ({ ...s, n }))
    return shuffle(all.filter((s) => s.img)).slice(0, 10).map((sign) => {
      const seen = new Set([sign.fr])
      const others = shuffle(all.filter((s) => s.cat === sign.cat && s.n !== sign.n)).filter((s) => !seen.has(s.fr) && seen.add(s.fr)).slice(0, 3)
      return { sign, options: shuffle([sign.fr, ...others.map((s) => s.fr)]) }
    })
  }, [signs])
  const [index, setIndex] = useState(0)
  const [chosen, setChosen] = useState<string | null>(null)
  const [correct, setCorrect] = useState(0)
  const finished = rounds.length > 0 && index >= rounds.length

  if (!Object.keys(signs).length) return <p className="center muted">Chargement…</p>
  const round = rounds[index]

  const pick = (option: string) => {
    if (chosen !== null) return
    setChosen(option)
    const ok = option === round.sign.fr
    if (ok) setCorrect((c) => c + 1)
    play(ok ? 'right' : 'wrong')
  }
  const next = () => {
    if (finished) {
      onFinish(correct)
      onClose()
      return
    }
    setChosen(null)
    setIndex(index + 1)
    if (index + 1 >= rounds.length) play('complete')
  }

  return (
    <div className="lesson">
      <header className="lesson-bar">
        <button className="icon-btn" onClick={onClose} aria-label="Fermer">✕</button>
        <div className="track lesson-track" aria-hidden="true">
          <div className="track-fill" style={{ transform: `scaleX(${Math.max(0.04, rounds.length ? index / rounds.length : 0)})`, background: 'var(--ring-orange)' }} />
        </div>
      </header>
      <main className="lesson-body">
        {!rounds.length && <p className="muted">Pas assez de panneaux illustrés pour ce quiz.</p>}
        {finished ? (
          <div className="quiz-end">
            <p className="score">{correct} / {rounds.length}</p>
            <p className="bonus">⚡ +{correct} XP</p>
          </div>
        ) : round ? (
          <>
            <h1 className="qtext">Que signifie ce panneau ?</h1>
            <div className="card sign-big"><img src={asset(round.sign.img!)} alt={`Panneau ${round.sign.n}`} width="150" height="150" /></div>
            <ol className="answers">
              {round.options.map((option, n) => {
                const state = chosen === null ? '' : option === round.sign.fr ? 'correct' : option === chosen ? 'wrong' : 'dim'
                return (
                  <li key={option}>
                    <button className={`answer ${state}`} onClick={() => pick(option)} disabled={chosen !== null}>
                      <span className="letter">{'ABCD'[n]}</span>
                      <span>{option}</span>
                      {state === 'correct' && <span className="mark ok">✓</span>}
                      {state === 'wrong' && <span className="mark ko">✕</span>}
                    </button>
                  </li>
                )
              })}
            </ol>
          </>
        ) : null}
        {(finished || chosen !== null) && <button className="primary wide" onClick={next} autoFocus>{finished ? 'Terminer' : 'Continuer'}</button>}
      </main>
    </div>
  )
}
