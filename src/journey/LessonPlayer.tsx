import { useEffect, useMemo, useRef, useState } from 'react'
import { loadLaw, loadQuestions, shuffle, type LawExcerpt, type Question } from '../data'
import { AnswerText, Picture } from '../Quiz'
import { useSigns } from '../Signs'
import { exerciseKind, isFinished, isFirstAttempt, newSession, outcome as sessionOutcome, RULES, sessionProgress, statement, submit, translations, type Lesson, type Outcome, type Session } from './engine'
import { Mascot, TalkingMascot } from './Mascots'
import { hebrewExercisesOn } from './options'
import { ReportLink } from '../Preparation'
import { play, setSounds, soundsOn } from './sounds'
import { X, Check, VolumeSlash, VolumeHigh, Star, Bolt, Trophy } from 'reicon-react'

interface Props {
  title: string
  /** Null for a review or a training, which belong to no lesson. */
  lesson: Lesson | null
  questions: Question[]
  /** The whole pool of the license, for the Hebrew exercises' wrong translations. */
  pool: Question[]
  color: string
  /** XP earned today before this lesson, to know whether it reaches the daily goal. */
  xpBefore: number
  onRecord: (id: string, ok: boolean) => void
  /** Called once, with the result, when the lesson ends. */
  onFinish: (result: Outcome) => void
  onClose: () => void
}

const PRAISE = ['Bravo !', 'Exact !', 'Excellent !', 'Bien joué !', 'Parfait !']
const KIND_LABEL = { choice: 'Choix', trueFalse: 'Vrai ou faux', hebrew: 'Hébreu' } as const

/** One lesson of the Parcours: answer, check, see why, continue. Several kinds of exercise; a wrong question comes back at the end. */
export function LessonPlayer({ title, lesson, questions, pool, color, xpBefore, onRecord, onFinish, onClose }: Props) {
  const [session, setSession] = useState<Session>(() => newSession(questions.map((q) => q.id)))
  const [chosen, setChosen] = useState<number | null>(null)
  const [checked, setChecked] = useState(false)
  const [result, setResult] = useState<Outcome | null>(null)
  const [hebrew, setHebrew] = useState<Map<string, Question> | null>(null)
  const [law, setLaw] = useState<Record<string, LawExcerpt>>({})
  const [muted, setMuted] = useState(!soundsOn())
  const signs = useSigns()
  const shownAt = useRef(Date.now())
  const seconds = useRef(0)
  const orders = useMemo(() => new Map(questions.map((q) => [q.id, shuffle(q.a.map((_, i) => i))])), [questions])
  const byId = useMemo(() => new Map(questions.map((q) => [q.id, q])), [questions])

  useEffect(() => {
    // The Hebrew exercises are an option, and need the official Hebrew wording: without either they are skipped.
    if (hebrewExercisesOn()) loadQuestions('he').then((all) => setHebrew(new Map(all.map((q) => [q.id, q]))), () => setHebrew(new Map()))
    else setHebrew(new Map())
    loadLaw().then(setLaw, () => {})
  }, [])

  const q = session.queue[0] !== undefined ? byId.get(session.queue[0]) : undefined
  const first = isFirstAttempt(session)
  const position = q ? questions.indexOf(q) : 0
  const kind = q ? exerciseKind(position, first, !!hebrew?.has(q.id)) : 'choice'
  const trans = useMemo(() => (q && kind === 'hebrew' ? translations(q, pool) : null), [q, kind, pool])

  const count = !q ? 0 : kind === 'trueFalse' ? 2 : kind === 'hebrew' ? trans!.options.length : q.a.length
  const correctIndex = !q ? -1 : kind === 'trueFalse' ? (statement(q).isTrue ? 0 : 1) : kind === 'hebrew' ? trans!.correct : q.c
  const right = chosen !== null && chosen === correctIndex
  const choiceAt = (n: number) => (!q ? n : kind === 'choice' ? orders.get(q.id)![n] : n)
  const choiceText = (ai: number) => (!q ? '' : kind === 'trueFalse' ? (ai === 0 ? 'Vrai' : 'Faux') : kind === 'hebrew' ? trans!.options[ai] : q.a[ai])
  const correctText = !q ? '' : kind === 'trueFalse' ? `${statement(q).isTrue ? 'Vrai' : 'Faux'}. La bonne réponse est : ${q.a[q.c]}` : kind === 'hebrew' ? trans!.options[trans!.correct] : q.a[q.c]

  const select = (ai: number) => {
    if (checked) return
    setChosen(ai)
    play('tap')
  }

  const check = () => {
    if (!q || chosen === null) return
    seconds.current = (Date.now() - shownAt.current) / 1000
    // A Hebrew exercise tests the reading, not the rule: it stays out of the statistics.
    if (first && kind !== 'hebrew') onRecord(q.id, right)
    play(right ? 'right' : 'wrong')
    navigator.vibrate?.(right ? 10 : [20, 40, 20])
    setChecked(true)
  }

  const next = () => {
    const after = submit(session, right, seconds.current)
    setSession(after)
    setChosen(null)
    setChecked(false)
    shownAt.current = Date.now()
    if (isFinished(after)) {
      const done = sessionOutcome(after, lesson !== null)
      setResult(done)
      onFinish(done)
    }
  }

  const keys = useRef({ select, check, next, chosen })
  keys.current = { select, check, next, chosen }
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.metaKey || e.ctrlKey || e.altKey || !q) return
      const target = e.target as HTMLElement
      if (e.key === 'Enter') {
        e.preventDefault()
        // On an answer reached with Tab, Enter picks it first; Enter again checks.
        if (!checked && target.matches?.('.answer') && target.getAttribute('aria-pressed') !== 'true') target.click()
        else if (checked) keys.current.next()
        else keys.current.check()
      } else if (!checked && /^[1-9]$/.test(e.key) && Number(e.key) <= count) {
        keys.current.select(choiceAt(Number(e.key) - 1))
      } else if (!checked && ['ArrowDown', 'ArrowRight', 'ArrowUp', 'ArrowLeft'].includes(e.key)) {
        // The arrows move the choice from one answer to the next.
        e.preventDefault()
        const step = e.key === 'ArrowDown' || e.key === 'ArrowRight' ? 1 : -1
        const at = Array.from({ length: count }, (_, n) => choiceAt(n)).indexOf(keys.current.chosen ?? -1)
        const to = at === -1 ? (step > 0 ? 0 : count - 1) : (at + step + count) % count
        keys.current.select(choiceAt(to))
        document.querySelectorAll<HTMLButtonElement>('.lesson-body .answer')[to]?.focus({ preventScroll: true })
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  })

  const quit = () => {
    if (!session.queue.length || window.confirm('Quitter la leçon ? Votre avancée dans cette leçon ne sera pas enregistrée, mais les réponses déjà données comptent dans vos statistiques.')) onClose()
  }

  if (result) return <LessonComplete title={lesson ? 'Leçon terminée !' : 'Série terminée !'} result={result} xpBefore={xpBefore} onClose={onClose} />
  if (!hebrew || !q) return <p className="center muted">Chargement…</p>

  const toggleSound = () => {
    setSounds(muted)
    setMuted(!muted)
    if (muted) play('tap')
  }
  const he = hebrew.get(q.id)
  const st = kind === 'trueFalse' ? statement(q) : null
  const state = (ai: number) => (checked ? (ai === correctIndex ? 'correct' : ai === chosen ? 'wrong' : 'dim') : ai === chosen ? 'selected' : '')
  const ref = q.r?.map((r) => law[r]?.l).find(Boolean)

  return (
    <div className="lesson" style={{ ['--lesson' as string]: color }}>
      <header className="lesson-bar">
        <button className="icon-btn" onClick={quit} aria-label="Quitter la leçon"><X size={18} /></button>
        <div className="track lesson-track" role="progressbar" aria-valuenow={Math.round(sessionProgress(session) * 100)} aria-valuemin={0} aria-valuemax={100} aria-label="Avancement">
          <div className="track-fill" style={{ transform: `scaleX(${Math.max(0.04, sessionProgress(session))})` }} />
        </div>
        <button className="icon-btn" onClick={toggleSound} aria-label={muted ? 'Activer les sons' : 'Couper les sons'}>{muted ? <VolumeSlash size={18} /> : <VolumeHigh size={18} />}</button>
      </header>

      <main className="lesson-body">
        {session.queue.length === questions.length && session.mistakes === 0 && !checked && position === 0 && (
          <TalkingMascot name="rouli" mood="happy" size={72} message={`C’est parti ! ${questions.length} questions.`} pool={pool} />
        )}
        <p className="lesson-meta">
          <span>{title}</span>
          <span>{KIND_LABEL[kind]}</span>
        </p>

        {kind === 'choice' && <h1 className="qtext">{q.q}</h1>}
        {kind === 'trueFalse' && st && (
          <>
            <h1 className="qtext">Vrai ou faux ?</h1>
            <p className="lesson-statement">{q.q}</p>
            <div className="card proposed">
              <small>Réponse proposée</small>
              <AnswerText q={q} text={q.a[st.answerIndex]} signs={signs} revealed={false} />
            </div>
          </>
        )}
        {kind === 'hebrew' && (
          <>
            <h1 className="qtext">Que dit cette question ?</h1>
            <p className="card he-card" dir="rtl" lang="he">{he?.q}</p>
          </>
        )}
        {q.img && <Picture id={q.img} />}

        <ol className="answers">
          {Array.from({ length: count }, (_, n) => {
            const ai = choiceAt(n)
            const s = state(ai)
            return (
              <li key={`${q.id}-${kind}-${ai}`}>
                <button className={`answer ${s}`} onClick={() => select(ai)} aria-pressed={ai === chosen} disabled={checked}>
                  <span className="letter">{kind === 'trueFalse' ? 'VF'[n] : 'ABCD'[n]}</span>
                  {kind === 'choice' ? <AnswerText q={q} text={q.a[ai]} signs={signs} revealed={checked} /> : <span>{choiceText(ai)}</span>}
                  {s === 'correct' && <span className="mark ok" aria-label="Bonne réponse"><Check size={18} /></span>}
                  {s === 'wrong' && <span className="mark ko" aria-label="Votre réponse, incorrecte"><X size={18} /></span>}
                </button>
              </li>
            )
          })}
        </ol>
      </main>

      {checked ? (
        <section className={`lesson-feedback ${right ? 'ok' : 'ko'}`} role="status">
          <div className="fb-text">
          <div className="fb-head">
            <Mascot name={right ? 'rouli' : 'stoppy'} mood={right ? (first ? 'cheer' : 'happy') : 'sad'} size={72} />
            <strong>{right ? PRAISE[[...q.id].reduce((h, c) => h + c.charCodeAt(0), 0) % PRAISE.length] : 'Pas tout à fait'}</strong>
          </div>
          {!right && <p className="fb-correct">Bonne réponse : {correctText}</p>}
          {q.e && <p>{q.e}</p>}
          {ref && <p className="muted small">Référence : {ref}</p>}
          <ReportLink question={q} />
          </div>
          <button className="primary wide" onClick={next} autoFocus>{right ? 'Continuer' : 'Compris'}</button>
        </section>
      ) : (
        <div className="lesson-check">
          <button className="primary wide" disabled={chosen === null} onClick={check}>Vérifier</button>
        </div>
      )}
    </div>
  )
}

function LessonComplete({ title, result, xpBefore, onClose }: { title: string; result: Outcome; xpBefore: number; onClose: () => void }) {
  const goal = xpBefore < RULES.dailyXP && xpBefore + result.xp >= RULES.dailyXP
  const cheer = result.perfect ? 'Sans faute ! Vous êtes un as du volant !' : result.accuracy >= 0.7 ? 'Beau travail, continuez comme ça !' : 'On y arrive. Je vous reposerai bientôt les questions ratées.'

  useEffect(() => {
    play('complete')
    for (let n = 0; n < result.stars; n++) play('star', 900 + 350 * n)
  }, [result.stars])

  return (
    <div className="lesson complete">
      <div className="confetti" aria-hidden="true">
        {Array.from({ length: 36 }, (_, i) => (
          <span key={i} style={{ left: `${(i * 37) % 100}%`, animationDelay: `${(i % 9) * 0.18}s`, background: ['#ff7a1a', '#2fd158', '#0a84ff', '#ffcc00', '#e0231b'][i % 5] }} />
        ))}
      </div>
      <div className="complete-body">
        <div className="complete-guides">
          <TalkingMascot name="rouli" mood={result.accuracy >= 0.7 ? 'cheer' : 'happy'} size={120} message={cheer} />
          {goal && <TalkingMascot name="feo" mood="cheer" size={72} message="Objectif du jour atteint !" />}
        </div>
        <div className="stars" aria-label={`${result.stars} étoile${result.stars > 1 ? 's' : ''} sur 3`}>
          {[1, 2, 3].map((n) => (
            <span key={n} className={n <= result.stars ? 'on' : ''} style={{ animationDelay: `${0.15 * n}s` }}><Star size={44} weight="Filled" /></span>
          ))}
        </div>
        <h1 className="title">{title}</h1>
        <p className="muted">{result.perfect ? 'Sans faute, bravo !' : 'Les questions ratées reviendront dans votre révision.'}</p>
        <dl className="complete-stats">
          <div><dt>XP gagnés</dt><dd style={{ color: 'var(--ring-orange)' }}>+{result.xp}</dd></div>
          <div><dt>Précision</dt><dd style={{ color: 'var(--ring-green)' }}>{Math.round(result.accuracy * 100)} %</dd></div>
          <div><dt>Erreurs</dt><dd style={{ color: result.mistakes ? 'var(--sign-red)' : 'var(--ring-green)' }}>{result.mistakes}</dd></div>
        </dl>
        {result.speedBonus && <p className="bonus"><Bolt className="ic" size={18} weight="Filled" /> Bonus de vitesse : +{RULES.xpSpeedBonus} XP</p>}
        {result.stars === 3 && <p className="bonus gold"><Trophy className="ic" size={18} weight="Filled" /> Leçon dorée !</p>}
        <button className="primary wide" onClick={onClose} autoFocus>Continuer</button>
      </div>
    </div>
  )
}
