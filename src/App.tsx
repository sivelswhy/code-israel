import { lazy, Suspense, useEffect, useMemo, useRef, useState } from 'react'
import { AnimatePresence, motion } from 'motion/react'
import { ACTIVE_LICENSES, CATEGORIES, EXAM, LICENSES, drawExam, loadQuestions, shuffle, type Category, type License, type Question } from './data'
import { localDay, streak, useProgress, type ExamRecord, type Stat } from './store'
import { addXP, applyStreakFreezes, claim, finish, openChest, RULES, streakOf, xpToday, type ChestReward, type Outcome, type QuestKind } from './journey/engine'
import { InstallHint } from './InstallHint'
import { GuideScreen, ReadinessCard, SignQuiz } from './Preparation'
import { SyncPanel, useSync } from './SyncPanel'
import { trapIDs, weakestIn } from './readiness'
import { Journey, type StartLesson } from './journey/Journey'
import { LessonPlayer } from './journey/LessonPlayer'
import { MatchGame } from './journey/MatchGame'
import { ModeSwitch, type Mode } from './journey/ModeSwitch'
import { scheduleReminders } from './journey/reminders'
import { Quiz, type Answer } from './Quiz'
import { Results } from './Results'
import { Browse } from './Browse'
import { Sources } from './Sources'
import { SignLexicon } from './Signs'
import { AssistantContext, type AssistantTopic } from './assistant-context'
import { CloudDownload, Car, CloseCircle, AddCircle, Danger, Search, Stopwatch, Flame as FlameIcon, MagicStar, Star } from 'reicon-react'

type Screen =
  | { name: 'home' }
  | { name: 'quiz'; mode: 'exam' | 'practice'; title: string; questions: Question[] }
  | { name: 'results'; mode: 'exam' | 'practice'; questions: Question[]; answers: Answer[] }
  | { name: 'browse' }
  | { name: 'sources' }
  | { name: 'signs' }
  | { name: 'lesson'; start: StartLesson; xpBefore: number }
  | { name: 'match' }
  | { name: 'guide' }
  | { name: 'sync' }
  | { name: 'signquiz' }

const PRACTICE_SIZE = 20
const Assistant = lazy(() => import('./Assistant').then((m) => ({ default: m.Assistant })))
export const spring = { type: 'spring', bounce: 0, duration: 0.4 } as const

export default function App() {
  const [all, setAll] = useState<Question[] | null>(null)
  const [error, setError] = useState(false)
  const [screen, setScreen] = useState<Screen>({ name: 'home' })
  const { progress, update, replace, record, toggleFavorite, addExam } = useProgress()
  const sync = useSync(progress, replace)
  const [assistant, setAssistant] = useState<{ topic?: AssistantTopic } | null>(null)
  const [mode, setMode] = useState<Mode>(() => {
    try {
      return localStorage.getItem('code-israel:mode') === 'journey' ? 'journey' : 'classic'
    } catch {
      return 'classic'
    }
  })
  const [freezeNotice, setFreezeNotice] = useState(0)
  const latest = useRef(progress)
  latest.current = progress

  const changeMode = (m: Mode) => {
    setMode(m)
    try {
      localStorage.setItem('code-israel:mode', m)
    } catch {
      // Storage unavailable: the choice lasts until the page is reloaded.
    }
  }

  // Streak freezes are spent on the days missed, when the page opens and whenever it comes back to the front.
  useEffect(() => {
    const apply = () => {
      const { journey, used } = applyStreakFreezes(latest.current.journey, latest.current.daily)
      if (!used) return
      update((p) => ({ ...p, journey }))
      setFreezeNotice(used)
    }
    apply()
    const onVisible = () => document.visibilityState === 'visible' && apply()
    document.addEventListener('visibilitychange', onVisible)
    return () => document.removeEventListener('visibilitychange', onVisible)
  }, [update])

  useEffect(() => {
    scheduleReminders(progress.journey, progress.daily, streakOf(progress.daily, progress.journey.frozenDays))
  }, [progress.journey, progress.daily])

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
  const switcher = (
    <div className="top-actions">
      <ModeSwitch mode={mode} onChange={changeMode} />
      {sync.available && (
        <button className={`sync-btn ${sync.code ? 'on' : ''}`} onClick={() => setScreen({ name: 'sync' })} aria-label={sync.code ? 'Synchronisation active : mes appareils' : 'Synchroniser mes appareils'}>
          <CloudDownload size={20} /> <span>{sync.code ? 'Synchronisé' : 'Synchroniser'}</span>
        </button>
      )}
    </div>
  )
  const finishLesson = (s: StartLesson, result: Outcome) => update((p) => ({ ...p, journey: finish(p.journey, s.lesson, result, s.countsAsReview) }))
  const claimQuest = (quest: QuestKind) => update((p) => ({ ...p, journey: claim(p.journey, quest) }))
  const openDailyChest = (): ChestReward | null => {
    const opened = openChest(progress.journey)
    if (!opened) return null
    update((p) => ({ ...p, journey: opened.journey }))
    return opened.reward
  }
  const setExamDate = (examDate: string | undefined) => update((p) => ({ ...p, examDate }))
  const practiceWeak = (cat: Category) => start('practice', `Points faibles : ${CATEGORIES[cat].label}`, weakestIn(pool, progress.stats, cat))
  const traps = pool.filter((q) => trapIDs(pool, progress.stats).includes(q.id))
  // A sign quiz round counts as practice today, so that it keeps the streak alive.
  const finishSignQuiz = (correct: number) =>
    update((p) => {
      const today = localDay(new Date())
      return { ...p, daily: { ...p.daily, [today]: (p.daily[today] ?? 0) + 1 }, journey: addXP(p.journey, correct) }
    })
  const finishMatch = () =>
    update((p) => {
      // A round counts as practice today, so that it keeps the streak alive.
      const today = localDay(new Date())
      return { ...p, daily: { ...p.daily, [today]: (p.daily[today] ?? 0) + 1 }, journey: addXP(p.journey, RULES.xpMatch) }
    })

  const inExam = screen.name === 'quiz' && screen.mode === 'exam'
  const showFab = !['quiz', 'results', 'lesson', 'match', 'signquiz'].includes(screen.name)

  return (
    <AssistantContext.Provider value={(topic) => setAssistant({ topic })}>
    {screen.name === 'home' && <InstallHint />}
    <AnimatePresence mode="wait" initial={false}>
      <motion.div
        key={screen.name}
        initial={{ opacity: 0, y: 8 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -8 }}
        transition={spring}
      >
        {screen.name === 'home' && mode === 'journey' && (
          <Journey
            pool={pool}
            progress={progress}
            freezeNotice={freezeNotice}
            onDismissNotice={() => setFreezeNotice(0)}
            onStart={(start) => setScreen({ name: 'lesson', start, xpBefore: xpToday(progress.journey) })}
            onMatch={() => setScreen({ name: 'match' })}
            onSignQuiz={() => setScreen({ name: 'signquiz' })}
            onGuide={() => setScreen({ name: 'guide' })}
            onPractice={(title, questions, color) => setScreen({ name: 'lesson', start: { title, lesson: null, questions, color, countsAsReview: false }, xpBefore: xpToday(progress.journey) })}
            onWeak={practiceWeak}
            onExamDate={setExamDate}
            traps={traps}
            onClaim={claimQuest}
            onChest={openDailyChest}
            switcher={switcher}
          />
        )}
        {screen.name === 'lesson' && (
          <LessonPlayer
            title={screen.start.title}
            lesson={screen.start.lesson}
            questions={screen.start.questions}
            pool={pool}
            color={screen.start.color}
            xpBefore={screen.xpBefore}
            onRecord={record}
            onFinish={(result) => finishLesson(screen.start, result)}
            onClose={home}
          />
        )}
        {screen.name === 'match' && <MatchGame onFinish={finishMatch} onClose={home} />}
        {screen.name === 'signquiz' && <SignQuiz onFinish={finishSignQuiz} onClose={home} />}
        {screen.name === 'guide' && <GuideScreen onBack={home} />}
        {screen.name === 'sync' && (
          <main className="page">
            <BackButton onClick={home} />
            <h1 className="title">Mes appareils</h1>
            <SyncPanel sync={sync} />
          </main>
        )}
        {screen.name === 'home' && mode === 'classic' && (
          <Home
            switcher={switcher}
            pool={pool}
            license={progress.license}
            stats={progress.stats}
            exams={progress.exams.filter((e) => e.license === progress.license)}
            favorites={pool.filter((q) => progress.favorites.includes(q.id))}
            daily={progress.daily}
            frozenDays={progress.journey.frozenDays}
            examDate={progress.examDate}
            traps={traps}
            onWeak={practiceWeak}
            onExamDate={setExamDate}
            onTraps={(qs) => start('practice', 'Pièges', qs.slice(0, PRACTICE_SIZE))}
            onSignQuiz={() => setScreen({ name: 'signquiz' })}
            onGuide={() => setScreen({ name: 'guide' })}
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
  stats: Record<string, Stat>
  exams: ExamRecord[]
  favorites: Question[]
  daily: Record<string, number>
  frozenDays: string[]
  examDate?: string
  traps: Question[]
  onWeak: (c: Category) => void
  onExamDate: (d: string | undefined) => void
  onTraps: (qs: Question[]) => void
  onSignQuiz: () => void
  onGuide: () => void
  switcher: React.ReactNode
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

function Home({ pool, license, stats, exams, favorites, daily, frozenDays, examDate, traps, onWeak, onExamDate, onTraps, onSignQuiz, onGuide, switcher, onLicense, onExam, onCategory, onMistakes, onUnseen, onFavorites, onReview, onBrowse, onSources, onSigns }: HomeProps) {
  const mistakes = pool.filter((q) => stats[q.id] && !stats[q.id].last)
  const unseen = pool.filter((q) => !stats[q.id])
  const mastered = pool.length - unseen.length - mistakes.length
  const lastExams = exams.slice(-5).reverse()
  const today = daily[localDay(new Date())] ?? 0
  const days = streak(daily, frozenDays)
  const share = (n: number) => (pool.length ? n / pool.length : 0)

  return (
    <main className="page">
      <header className="hero">
        {switcher}
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

      <ReadinessCard pool={pool} stats={stats} exams={exams} examDate={examDate} onPractice={onWeak} onExamDate={onExamDate} />

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
        <Row icon="ko" title="Pièges" hint="Les questions où vous vous trompez le plus souvent" count={traps.length} onClick={() => onTraps(traps)} disabled={!traps.length} />
        <Row icon="new" title="Jamais vues" hint="Couvrir toute la banque, petit à petit" count={unseen.length} onClick={() => onUnseen(unseen)} disabled={!unseen.length} />
        <Row icon="signs" title="Quiz des panneaux" hint="Reconnaître les panneaux : 1 XP par bonne réponse" onClick={onSignQuiz} />
        <Row icon="browse" title="Guide et glossaire" hint="Les étapes du permis en Israël, les mots du code en français et en hébreu" onClick={onGuide} />
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
