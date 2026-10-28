import { lazy, Suspense, useEffect, useMemo, useState } from 'react'
import { AnimatePresence, motion } from 'motion/react'
import { ACTIVE_LICENSES, CATEGORIES, EXAM, LICENSES, drawExam, loadQuestions, shuffle, type Category, type License, type Question } from './data'
import { localDay, streak, useProgress, type ExamRecord } from './store'
import { Quiz, type Answer } from './Quiz'
import { Results } from './Results'
import { Browse } from './Browse'
import { Sources } from './Sources'
import { SignLexicon } from './Signs'
import { AssistantContext, type AssistantTopic } from './assistant-context'
import { Car, CloseCircle, AddCircle, Danger, Search, Stopwatch, Flame as FlameIcon, MagicStar, Star } from 'reicon-react'

type Screen =
  | { name: 'home' }
  | { name: 'quiz'; mode: 'exam' | 'practice'; title: string; questions: Question[] }
  | { name: 'results'; mode: 'exam' | 'practice'; questions: Question[]; answers: Answer[] }
  | { name: 'browse' }
  | { name: 'sources' }
  | { name: 'signs' }

const PRACTICE_SIZE = 20
const Assistant = lazy(() => import('./Assistant').then((m) => ({ default: m.Assistant })))
export const spring = { type: 'spring', bounce: 0, duration: 0.4 } as const

export default function App() {
  const [all, setAll] = useState<Question[] | null>(null)
  const [error, setError] = useState(false)
  const [screen, setScreen] = useState<Screen>({ name: 'home' })
  const { progress, update, record, toggleFavorite, addExam } = useProgress()
  const [assistant, setAssistant] = useState<{ topic?: AssistantTopic } | null>(null)

  useEffect(() => {
    loadQuestions('fr').then(setAll, () => setError(true))
  }, [])

  useEffect(() => {
    window.scrollTo(0, 0)
  }, [screen])

  const pool = useMemo(() => all?.filter((q) => q.lic.includes(progress.license)) ?? [], [all, progress.license])

  if (error) return <p className="center">Impossible de charger les questions. Vérifiez votre connexion et rechargez la page.</p>
  if (!all) return <p className="center muted">Chargement…</p>

  const start = (mode: 'exam' | 'practice', title: string, questions: Question[]) =>
    setScreen({ name: 'quiz', mode, title, questions })
  const home = () => setScreen({ name: 'home' })

  const inExam = screen.name === 'quiz' && screen.mode === 'exam'
  const showFab = screen.name !== 'quiz' && screen.name !== 'results'

  return (
    <AssistantContext.Provider value={(topic) => setAssistant({ topic })}>
    <AnimatePresence mode="wait" initial={false}>
      <motion.div
        key={screen.name}
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -8 }}
        transition={spring}
      >
        {screen.name === 'home' && (
          <Home
            pool={pool}
            license={progress.license}
            stats={progress.stats}
            exams={progress.exams.filter((e) => e.license === progress.license)}
            favorites={pool.filter((q) => progress.favorites.includes(q.id))}
            daily={progress.daily}
            onLicense={(license) => update((p) => ({ ...p, license }))}
            onExam={() => start('exam', 'Examen blanc', drawExam(pool))}
            onCategory={(cat) =>
              start('practice', CATEGORIES[cat].label, shuffle(pool.filter((q) => q.cat === cat)).slice(0, PRACTICE_SIZE))
            }
            onMistakes={(qs) => start('practice', 'Mes erreurs', shuffle(qs).slice(0, PRACTICE_SIZE))}
            onUnseen={(qs) => start('practice', 'Jamais vues', shuffle(qs).slice(0, PRACTICE_SIZE))}
            onFavorites={(qs) => start('practice', 'Mes favoris', shuffle(qs).slice(0, PRACTICE_SIZE))}
            onReview={(exam) => {
              const byId = new Map(all.map((q) => [q.id, q]))
              const questions = exam.ids!.map((id) => byId.get(id)).filter((q): q is Question => !!q)
              // A question missing from the bank would shift the answers: show nothing rather than a wrong review.
              if (questions.length === exam.ids!.length) setScreen({ name: 'results', mode: 'exam', questions, answers: exam.answers! })
            }}
            onBrowse={() => setScreen({ name: 'browse' })}
            onSources={() => setScreen({ name: 'sources' })}
            onSigns={() => setScreen({ name: 'signs' })}
          />
        )}
        {screen.name === 'quiz' && (
          <Quiz
            mode={screen.mode}
            title={screen.title}
            questions={screen.questions}
            onRecord={record}
            favorites={progress.favorites}
            onFavorite={toggleFavorite}
            onQuit={home}
            onFinish={(answers) => {
              if (screen.mode === 'exam') {
                const errors = answers.filter((a, i) => a !== screen.questions[i].c).length
                addExam({ date: Date.now(), errors, license: progress.license, ids: screen.questions.map((q) => q.id), answers })
              }
              setScreen({ name: 'results', mode: screen.mode, questions: screen.questions, answers })
            }}
          />
        )}
        {screen.name === 'results' && (
          <Results
            mode={screen.mode}
            questions={screen.questions}
            answers={screen.answers}
            onHome={home}
            onRetry={() =>
              screen.mode === 'exam'
                ? start('exam', 'Examen blanc', drawExam(pool))
                : start(
                    'practice',
                    'Questions manquées',
                    screen.questions.filter((q, i) => screen.answers[i] !== q.c),
                  )
            }
          />
        )}
        {screen.name === 'browse' && <Browse pool={pool} stats={progress.stats} favorites={progress.favorites} onFavorite={toggleFavorite} onBack={home} />}
        {screen.name === 'sources' && <Sources onBack={home} />}
        {screen.name === 'signs' && <SignLexicon onBack={home} />}
      </motion.div>
    </AnimatePresence>
    {showFab && !assistant && (
      <button className="fab" onClick={() => setAssistant({})} aria-label="Ouvrir l'assistant">
        <MagicStar size={18} weight="Filled" /> Assistant
      </button>
    )}
    <Suspense>
      <AnimatePresence>
        {assistant && !inExam && <Assistant key="assistant" questions={pool} stats={progress.stats} topic={assistant.topic} onClose={() => setAssistant(null)} />}
      </AnimatePresence>
    </Suspense>
    </AssistantContext.Provider>
  )
}

interface HomeProps {
  pool: Question[]
  license: License
  stats: Record<string, { last: boolean }>
  exams: ExamRecord[]
  favorites: Question[]
  daily: Record<string, number>
  onLicense: (l: License) => void
  onExam: () => void
  onCategory: (c: Category) => void
  onMistakes: (qs: Question[]) => void
  onUnseen: (qs: Question[]) => void
  onFavorites: (qs: Question[]) => void
  onReview: (exam: ExamRecord) => void
  onBrowse: () => void
  onSources: () => void
  onSigns: () => void
}

const DAILY_GOAL = 20

function Home({ pool, license, stats, exams, favorites, daily, onLicense, onExam, onCategory, onMistakes, onUnseen, onFavorites, onReview, onBrowse, onSources, onSigns }: HomeProps) {
  const mistakes = pool.filter((q) => stats[q.id] && !stats[q.id].last)
  const unseen = pool.filter((q) => !stats[q.id])
  const mastered = pool.length - unseen.length - mistakes.length
  const lastExams = exams.slice(-5).reverse()
  const today = daily[localDay(new Date())] ?? 0
  const days = streak(daily)
  const share = (n: number) => (pool.length ? n / pool.length : 0)

  return (
    <main className="page">
      <header className="hero">
        <div className="hero-signs" aria-hidden="true">
          <SignGlyph kind="rules" />
          <SignGlyph kind="safety" />
          <SignGlyph kind="signs" />
        </div>
        <p className="eyebrow">Examen théorique · Israël</p>
        <h1 className="display">Code de la route</h1>
        <p className="lede">{pool.length} questions officielles, expliquées en français avec le texte de loi.</p>
        <label className="select">
          <span>Permis</span>
          <select value={license} onChange={(e) => onLicense(e.target.value as License)}>
            {ACTIVE_LICENSES.map((k) => (
              <option key={k} value={k}>
                {LICENSES[k]}
              </option>
            ))}
          </select>
        </label>
      </header>

      <section className="card activity" aria-label="Progression">
        <Rings
          rings={[
            { value: share(mastered), color: 'var(--ring-green)' },
            { value: share(pool.length - unseen.length), color: 'var(--ring-blue)' },
            { value: Math.min(1, today / DAILY_GOAL), color: 'var(--ring-orange)' },
          ]}
        />
        <dl className="activity-legend">
          <div>
            <dt style={{ color: 'var(--ring-green)' }}>Maîtrisées</dt>
            <dd>
              {mastered}
              <small>/{pool.length}</small>
            </dd>
          </div>
          <div>
            <dt style={{ color: 'var(--ring-blue)' }}>Déjà vues</dt>
            <dd>
              {pool.length - unseen.length}
              <small>/{pool.length}</small>
            </dd>
          </div>
          <div>
            <dt style={{ color: 'var(--ring-orange)' }}>Aujourd'hui</dt>
            <dd>
              {today}
              <small>/{DAILY_GOAL}</small>
            </dd>
          </div>
        </dl>
        {days > 0 && (
          <p className="streak">
            <FlameIcon size={16} weight="Filled" /> {days} jour{days > 1 ? 's' : ''} d'affilée
          </p>
        )}
      </section>

      <button className="exam-tile" onClick={onExam}>
        <span className="exam-icon" aria-hidden="true">
          <Stopwatch size={28} />
        </span>
        <span>
          <strong>Examen blanc</strong>
          <small>
            {EXAM.size} questions · {EXAM.minutes} min · {EXAM.maxErrors} erreurs max.
          </small>
        </span>
        <Chevron />
      </button>
      {lastExams.length > 0 && (
        <p className="history">
          Derniers examens :{' '}
          {lastExams.map((e) =>
            e.ids && e.answers ? (
              <button key={e.date} className={e.errors <= EXAM.maxErrors ? 'pass' : 'fail'} onClick={() => onReview(e)} aria-label={`Revoir l'examen du ${new Date(e.date).toLocaleDateString('fr-FR')}`}>
                {EXAM.size - e.errors}/{EXAM.size}
              </button>
            ) : (
              <span key={e.date} className={e.errors <= EXAM.maxErrors ? 'pass' : 'fail'}>
                {EXAM.size - e.errors}/{EXAM.size}
              </span>
            ),
          )}
        </p>
      )}

      <h2 className="section-title">S'entraîner par thème</h2>
      <div className="theme-grid">
        {(Object.keys(CATEGORIES) as Category[]).map((cat) => {
          const qs = pool.filter((q) => q.cat === cat)
          const done = qs.filter((q) => stats[q.id]?.last).length
          return (
            <button key={cat} className={`theme-tile theme-${cat}`} onClick={() => onCategory(cat)} disabled={!qs.length}>
              <SignGlyph kind={cat} />
              <strong>{CATEGORIES[cat].label}</strong>
              <small>{CATEGORIES[cat].hint}</small>
              <span className="theme-bar" aria-label={`${done} sur ${qs.length} maîtrisées`}>
                <span style={{ transform: `scaleX(${qs.length ? done / qs.length : 0})` }} />
              </span>
              <span className="count">
                {done}/{qs.length}
              </span>
            </button>
          )
        })}
      </div>

      <h2 className="section-title">Réviser</h2>
      <ul className="list">
        <Row icon="ko" title="Mes erreurs" hint="Les questions ratées à la dernière tentative" count={mistakes.length} onClick={() => onMistakes(mistakes)} disabled={!mistakes.length} />
        <Row icon="fav" title="Mes favoris" hint="Les questions que vous avez marquées d'une étoile" count={favorites.length} onClick={() => onFavorites(favorites)} disabled={!favorites.length} />
        <Row icon="new" title="Jamais vues" hint="Couvrir toute la banque, petit à petit" count={unseen.length} onClick={() => onUnseen(unseen)} disabled={!unseen.length} />
        <Row icon="signs" title="Lexique des panneaux" hint="Chaque panneau, son numéro et sa signification officielle" onClick={onSigns} />
        <Row icon="browse" title="Parcourir et rechercher" hint="Toutes les questions avec leur réponse" onClick={onBrowse} />
      </ul>

      <footer className="footer">
        <button className="link" onClick={onSources}>
          Sources officielles et licence
        </button>
        <p>
          Questions et images : ministère des Transports d'Israël, via data.gov.il (CC BY). Application non officielle.
        </p>
      </footer>
    </main>
  )
}

function Row({ icon, title, hint, count, onClick, disabled }: { icon: 'ko' | 'new' | 'fav' | 'signs' | 'browse'; title: string; hint: string; count?: number; onClick: () => void; disabled?: boolean }) {
  return (
    <li>
      <button className="row" onClick={onClick} disabled={disabled}>
        <span className={`row-icon icon-${icon}`} aria-hidden="true">
          {icon === 'ko' && <CloseCircle size={22} strokeWidth={2} />}
          {icon === 'fav' && <Star size={22} strokeWidth={2} />}
          {icon === 'new' && <AddCircle size={22} strokeWidth={2} />}
          {icon === 'signs' && <Danger size={22} strokeWidth={2} />}
          {icon === 'browse' && <Search size={22} strokeWidth={2} />}
        </span>
        <span>
          <strong>{title}</strong>
          <small>{hint}</small>
        </span>
        {count !== undefined && <span className="count">{count}</span>}
        <Chevron />
      </button>
    </li>
  )
}

/** Activity-style concentric progress rings. */
export function Rings({ rings, size = 120, stroke = 13 }: { rings: { value: number; color: string }[]; size?: number; stroke?: number }) {
  return (
    <svg className="rings" width={size} height={size} viewBox={`0 0 ${size} ${size}`} role="img" aria-label="Progression">
      {rings.map((r, i) => {
        const radius = size / 2 - stroke / 2 - i * (stroke + 3)
        const c = 2 * Math.PI * radius
        return (
          <g key={i} transform={`rotate(-90 ${size / 2} ${size / 2})`}>
            <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke={r.color} strokeOpacity="0.18" strokeWidth={stroke} />
            <motion.circle
              cx={size / 2}
              cy={size / 2}
              r={radius}
              fill="none"
              stroke={r.color}
              strokeWidth={stroke}
              strokeLinecap="round"
              strokeDasharray={c}
              initial={{ strokeDashoffset: c }}
              animate={{ strokeDashoffset: c * (1 - Math.max(r.value, 0.001)) }}
              transition={{ type: 'spring', bounce: 0, duration: 1.2, delay: 0.1 * i }}
            />
          </g>
        )
      })}
    </svg>
  )
}

/** Small road-sign shaped glyph for each theme (circle = rule, triangle = danger, octagon = sign, square = info). */
export function SignGlyph({ kind }: { kind: Category }) {
  if (kind === 'vehicle') {
    return (
      <span className="glyph glyph-vehicle" aria-hidden="true">
        <Car size={26} weight="Filled" color="#fff" />
      </span>
    )
  }
  return (
    <svg className={`glyph glyph-${kind}`} width="40" height="40" viewBox="0 0 40 40" aria-hidden="true">
      {kind === 'rules' && (
        <>
          <circle cx="20" cy="20" r="18" fill="var(--sign-blue)" />
          <path d="M20 29V12m-6.5 6.5L20 12l6.5 6.5" fill="none" stroke="#fff" strokeWidth="3.6" strokeLinecap="round" strokeLinejoin="round" />
        </>
      )}
      {kind === 'safety' && (
        <>
          <path d="M20 3.5L37.5 34h-35z" fill="#fff" stroke="var(--sign-red)" strokeWidth="4" strokeLinejoin="round" />
          <path d="M20 14v9" stroke="#1d1d1f" strokeWidth="3.4" strokeLinecap="round" />
          <circle cx="20" cy="28.2" r="2" fill="#1d1d1f" />
        </>
      )}
      {kind === 'signs' && (
        <>
          <path d="M13 2.5h14l10.5 10.5v14L27 37.5H13L2.5 27V13z" fill="var(--sign-red)" />
          <path d="M13 5.5h14l7.5 7.5v14L27 34.5H13L5.5 27V13z" fill="none" stroke="#fff" strokeWidth="1.8" />
          <text x="20" y="24" textAnchor="middle" fontSize="9.5" fontWeight="800" fill="#fff" fontFamily="system-ui">STOP</text>
        </>
      )}
    </svg>
  )
}


export function Chevron() {
  return (
    <svg className="chevron" width="8" height="14" viewBox="0 0 8 14" aria-hidden="true">
      <path d="M1 1l6 6-6 6" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

export function BackButton({ onClick, label = 'Accueil' }: { onClick: () => void; label?: string }) {
  return (
    <button className="back" onClick={onClick}>
      <svg width="10" height="17" viewBox="0 0 10 17" aria-hidden="true">
        <path d="M8.5 1.5l-7 7 7 7" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      {label}
    </button>
  )
}
