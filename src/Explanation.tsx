import { useEffect, useState } from 'react'
import { AnimatePresence, motion } from 'motion/react'
import { loadLaw, type LawExcerpt, type Question } from './data'
import { spring } from './App'
import { citedSigns, SignRow, useSigns } from './Signs'
import { MagicStar } from 'reicon-react'
import { ReportLink } from './Preparation'

interface Props {
  question: Question
  /** Index chosen in `question.a`, when the user answered. */
  chosen?: number | null
  /** Open by default (after a mistake). */
  open?: boolean
  onAsk?: () => void
}

export function Explanation({ question, chosen, open: initiallyOpen = false, onAsk }: Props) {
  const [open, setOpen] = useState(initiallyOpen)
  const wrong = chosen != null && chosen !== question.c
  const signs = useSigns()
  const cited = citedSigns(question, signs)
  if (!question.e && !cited.length && !onAsk) return null

  return (
    <section className={`explain ${wrong ? 'is-wrong' : ''}`}>
      <button className="explain-head" onClick={() => setOpen(!open)} aria-expanded={open}>
        <span>{wrong ? 'Pourquoi ce n’est pas la bonne réponse' : 'Explication et texte de loi'}</span>
        <svg className={`disclosure ${open ? 'open' : ''}`} width="12" height="8" viewBox="0 0 12 8" aria-hidden="true">
          <path d="M1 1.5l5 5 5-5" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </button>
      <AnimatePresence initial={false}>
        {open && (
          <motion.div
            className="explain-body"
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={spring}
          >
            {wrong && (
              <div className="compare">
                <p>
                  <span className="tag ko">Votre réponse</span>
                  {question.a[chosen!]}
                </p>
                <p>
                  <span className="tag ok">Bonne réponse</span>
                  {question.a[question.c]}
                </p>
              </div>
            )}
            {question.e ? (
              <p className="explain-text">{question.e}</p>
            ) : (
              !cited.length && <p className="muted">Explication en cours de rédaction pour cette question.</p>
            )}
            {cited.length > 0 && (
              <div className="refs">
                <p className="refs-title">Les panneaux de la question</p>
                {cited.map((n) => (
                  <SignRow key={n} n={n} sign={signs[n]} />
                ))}
              </div>
            )}
            {question.r && question.r.length > 0 && <References refs={question.r} />}
            {onAsk && (
              <button className="ask" onClick={onAsk}>
                <MagicStar size={18} weight="Filled" /> Poser une question à l'assistant
              </button>
            )}
            <ReportLink question={question} />
          </motion.div>
        )}
      </AnimatePresence>
    </section>
  )
}

function References({ refs }: { refs: string[] }) {
  const [law, setLaw] = useState<Record<string, LawExcerpt> | null>(null)
  useEffect(() => {
    loadLaw().then(setLaw, () => setLaw({}))
  }, [])

  return (
    <div className="refs">
      <p className="refs-title">Ce que dit la loi</p>
      {refs.map((r) => (
        <Reference key={r} excerpt={law?.[r]} fallback={r} />
      ))}
    </div>
  )
}

function Reference({ excerpt, fallback }: { excerpt?: LawExcerpt; fallback: string }) {
  const [open, setOpen] = useState(false)
  if (!excerpt) return <p className="muted small">{fallback}</p>
  return (
    <div className="ref">
      <button className="ref-head" onClick={() => setOpen(!open)} aria-expanded={open}>
        <span>
          <strong>{excerpt.l}</strong>
          <small dir="rtl" lang="he">{excerpt.t}</small>
        </span>
        <span className="ref-toggle">{open ? 'Masquer' : 'Texte officiel'}</span>
      </button>
      {open && (
        <div className="ref-body">
          <p dir="rtl" lang="he" className="law-text">
            {excerpt.x}
          </p>
          <a href={excerpt.u} target="_blank" rel="noreferrer">
            {excerpt.src} — texte complet
          </a>
        </div>
      )}
    </div>
  )
}
