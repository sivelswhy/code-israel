import { useEffect, useMemo, useState } from 'react'
import { AnimatePresence, motion, useReducedMotion } from 'motion/react'
import { EXAM, loadQuestions, shuffle, type Question } from './data'
import { BackButton, spring } from './App'
import { Explanation } from './Explanation'
import { useAssistant } from './assistant-context'
import { answerSign, SignImage, useSigns } from './Signs'
import { Star } from 'reicon-react'

/** Index chosen in `question.a`, or null when unanswered. */
export type Answer = number | null

interface Props {
  mode: 'exam' | 'practice'
  title: string
  questions: Question[]
  onRecord: (id: string, ok: boolean) => void
  favorites: string[]
  onFavorite: (id: string) => void
  onQuit: () => void
  onFinish: (answers: Answer[]) => void
}

export function Quiz({ mode, title, questions, onRecord, favorites, onFavorite, onQuit, onFinish }: Props) {
  const [index, setIndex] = useState(0)
  const [answers, setAnswers] = useState<Answer[]>(() => questions.map(() => null))
  const [direction, setDirection] = useState(1)
  const orders = useMemo(() => questions.map((q) => shuffle(q.a.map((_, i) => i))), [questions])
  const q = questions[index]
  const chosen = answers[index]
  const revealed = mode === 'practice' && chosen !== null
  const last = index === questions.length - 1
  const ask = useAssistant()
  const signs = useSigns()
  const still = useReducedMotion()

  const go = (to: number) => {
    setDirection(to > index ? 1 : -1)
    setIndex(to)
  }

  const choose = (i: number) => {
    if (revealed) return
    setAnswers((prev) => prev.map((a, k) => (k === index ? i : a)))
    if (mode === 'practice') {
      onRecord(q.id, i === q.c)
      navigator.vibrate?.(i === q.c ? 10 : [20, 40, 20])
    }
  }

  const submit = () => {
    if (mode === 'exam') questions.forEach((qq, i) => onRecord(qq.id, answers[i] === qq.c))
    onFinish(answers)
  }

  return (
    <main className="page quiz">
      <header className="quiz-bar">
        <BackButton onClick={() => (answers.some((a) => a !== null) && !confirm('Quitter cette série ?') ? null : onQuit())} label="Quitter" />
        <span className="quiz-title">{title}</span>
        {mode === 'exam' ? <Timer onTimeout={submit} /> : <span className="quiz-count">{index + 1}/{questions.length}</span>}
      </header>
      <div className="track" aria-hidden="true">
        <motion.div className="track-fill" animate={{ scaleX: (index + 1) / questions.length }} transition={spring} />
      </div>

      <AnimatePresence mode="popLayout" initial={false} custom={direction}>
        <motion.article
          key={q.id + index}
          custom={direction}
          variants={{
            enter: (d: number) => ({ opacity: 0, x: d * 40 }),
            center: { opacity: 1, x: 0 },
            exit: (d: number) => ({ opacity: 0, x: d * -40 }),
          }}
          initial="enter"
          animate="center"
          exit="exit"
          transition={spring}
          className="question"
        >
          <p className="qmeta">
            Question {index + 1} sur {questions.length} · <span className="mono">n° {q.id}</span>
            <FavoriteButton on={favorites.includes(q.id)} onClick={() => onFavorite(q.id)} />
          </p>
          <h1 className="qtext">{q.q}</h1>
          {q.img && <Picture id={q.img} />}

          <ol className="answers">
            {orders[index].map((ai, n) => {
              const state = revealed
                ? ai === q.c
                  ? 'correct'
                  : ai === chosen
                    ? 'wrong'
                    : 'dim'
                : ai === chosen
                  ? 'selected'
                  : ''
              return (
                <li key={ai}>
                  <motion.button
                    className={`answer ${state}`}
                    onClick={() => choose(ai)}
                    aria-pressed={ai === chosen}
                    disabled={revealed}
                    // Feedback fires on the answer itself: a pop for the right one, an iOS-style shake for a wrong pick.
                    animate={still ? undefined : state === 'correct' ? { scale: [1, 1.025, 1] } : state === 'wrong' ? { x: [0, -8, 8, -5, 5, 0] } : { scale: 1, x: 0 }}
                    transition={state === 'wrong' ? { duration: 0.4 } : { type: 'spring', bounce: 0.4, duration: 0.45 }}
                  >
                    <span className="letter">{'ABCD'[n]}</span>
                    <AnswerText q={q} text={q.a[ai]} signs={signs} revealed={revealed} />
                    {state === 'correct' && <Mark ok />}
                    {state === 'wrong' && <Mark ok={false} />}
                  </motion.button>
                </li>
              )
            })}
          </ol>

          {revealed && (
            <Explanation question={q} chosen={chosen} open={chosen !== q.c} onAsk={() => ask({ question: q, chosen })} />
          )}
          <Original question={q} revealed={revealed} />
        </motion.article>
      </AnimatePresence>

      <nav className="quiz-actions">
        {mode === 'exam' ? (
          <>
            <button className="secondary" onClick={() => go(index - 1)} disabled={index === 0}>
              Précédente
            </button>
            {last ? (
              <button
                className="primary"
                onClick={() => {
                  const missing = answers.filter((a) => a === null).length
                  if (!missing || confirm(`${missing} question(s) sans réponse. Terminer quand même ?`)) submit()
                }}
              >
                Terminer
              </button>
            ) : (
              <button className="primary" onClick={() => go(index + 1)}>
                Suivante
              </button>
            )}
          </>
        ) : (
          <button className="primary wide" disabled={!revealed} onClick={() => (last ? submit() : go(index + 1))}>
            {last ? 'Voir le bilan' : 'Continuer'}
          </button>
        )}
      </nav>

      {mode === 'exam' && (
        <div className="dots" role="navigation" aria-label="Aller à la question">
          {questions.map((_, i) => (
            <button
              key={i}
              className={`qdot ${answers[i] !== null ? 'done' : ''} ${i === index ? 'here' : ''}`}
              onClick={() => go(i)}
              aria-label={`Question ${i + 1}`}
            >
              {i + 1}
            </button>
          ))}
        </div>
      )}
    </main>
  )
}

export function FavoriteButton({ on, onClick }: { on: boolean; onClick: () => void }) {
  return (
    <button className={`fav ${on ? 'on' : ''}`} onClick={onClick} aria-pressed={on} aria-label={on ? 'Retirer des favoris' : 'Ajouter aux favoris'}>
      <Star size={20} weight={on ? 'Filled' : 'Outline'} />
    </button>
  )
}

function AnswerText({ q, text, signs, revealed }: { q: Question; text: string; signs: ReturnType<typeof useSigns>; revealed: boolean }) {
  const n = answerSign(q, text, signs)
  if (!n) return <span>{text}</span>
  return (
    <span className="answer-sign">
      <SignImage n={n} sign={signs[n]} size={64} />
      <span>
        <span className="mono">Panneau {n}</span>
        {revealed && <small>{signs[n].fr}</small>}
      </span>
    </span>
  )
}

function Timer({ onTimeout }: { onTimeout: () => void }) {
  const [end] = useState(() => Date.now() + EXAM.minutes * 60_000)
  const [now, setNow] = useState(() => Date.now())
  const left = Math.max(0, end - now)

  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), 1000)
    return () => clearInterval(t)
  }, [])

  useEffect(() => {
    if (left === 0) onTimeout()
  }, [left, onTimeout])

  const m = Math.floor(left / 60_000)
  const s = Math.floor((left % 60_000) / 1000)
  return (
    <span className={`timer ${left < 5 * 60_000 ? 'urgent' : ''}`} aria-label="Temps restant">
      {m}:{String(s).padStart(2, '0')}
    </span>
  )
}

function Mark({ ok }: { ok: boolean }) {
  return (
    <svg className="mark" width="22" height="22" viewBox="0 0 22 22" aria-label={ok ? 'Bonne réponse' : 'Votre réponse, incorrecte'}>
      <circle cx="11" cy="11" r="11" fill="currentColor" />
      <path
        d={ok ? 'M6.5 11.5l3 3 6-7' : 'M7.5 7.5l7 7M14.5 7.5l-7 7'}
        stroke="var(--on-accent)"
        strokeWidth="2.2"
        fill="none"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
}

export function Picture({ id }: { id: string }) {
  const [open, setOpen] = useState(false)
  return (
    <>
      <motion.button layoutId={`img-${id}`} className="picture" onClick={() => setOpen(true)} transition={spring} aria-label="Agrandir l'image">
        <img src={`/img/${id}.jpg`} alt="Illustration officielle de la question" loading="lazy" />
      </motion.button>
      <AnimatePresence>
        {open && (
          <motion.div className="lightbox" onClick={() => setOpen(false)} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}>
            <motion.img layoutId={`img-${id}`} src={`/img/${id}.jpg`} alt="Illustration officielle agrandie" transition={spring} />
          </motion.div>
        )}
      </AnimatePresence>
    </>
  )
}

/** Shows the authoritative Hebrew wording of the question. */
export function Original({ question, revealed }: { question: Question; revealed: boolean }) {
  const [open, setOpen] = useState(false)
  const [he, setHe] = useState<Question | null | undefined>()

  useEffect(() => {
    if (open && he === undefined) loadQuestions('he').then((all) => setHe(all.find((x) => x.id === question.id) ?? null), () => setHe(null))
  }, [open, he, question.id])

  return (
    <div className="original">
      <button className="link" onClick={() => setOpen(!open)} aria-expanded={open}>
        {open ? 'Masquer' : 'Afficher'} l'original en hébreu (texte officiel)
      </button>
      <AnimatePresence initial={false}>
        {open && (
          <motion.div
            className="original-body"
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={spring}
          >
            {he === undefined && <p className="muted">Chargement…</p>}
            {he === null && <p className="muted">Pas de version hébraïque pour cette question.</p>}
            {he && (
              <div dir="rtl" lang="he">
                <p className="he-q">{he.q}</p>
                <ul>
                  {he.a.map((a, i) => (
                    <li key={i} className={revealed && i === he.c ? 'he-correct' : ''}>
                      {a}
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}
