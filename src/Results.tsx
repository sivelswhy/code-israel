import { EXAM, type Question } from './data'
import type { Answer } from './Quiz'
import { Picture } from './Quiz'
import { Explanation } from './Explanation'
import { useAssistant } from './assistant-context'
import { Rings } from './App'

interface Props {
  mode: 'exam' | 'practice'
  questions: Question[]
  answers: Answer[]
  onHome: () => void
  onRetry: () => void
}

export function Results({ mode, questions, answers, onHome, onRetry }: Props) {
  const wrong = questions.map((q, i) => ({ q, a: answers[i] })).filter(({ q, a }) => a !== q.c)
  const score = questions.length - wrong.length
  const passed = mode === 'exam' && wrong.length <= EXAM.maxErrors
  const ask = useAssistant()

  return (
    <main className="page">
      <header className="hero">
        <p className="eyebrow">{mode === 'exam' ? 'Examen blanc' : 'Bilan'}</p>
        <div className="score">
          <Rings size={150} stroke={16} rings={[{ value: questions.length ? score / questions.length : 0, color: mode === 'practice' || passed ? 'var(--ring-green)' : 'var(--sign-red)' }]} />
          <h1 className="display">
            {score}
            <small>/{questions.length}</small>
          </h1>
        </div>
        {mode === 'exam' ? (
          <p className={`verdict ${passed ? 'pass' : 'fail'}`}>
            {passed
              ? `Réussi : ${wrong.length} erreur${wrong.length > 1 ? 's' : ''}, la limite est de ${EXAM.maxErrors}.`
              : `Échoué : ${wrong.length} erreurs, il en faut ${EXAM.maxErrors} au maximum.`}
          </p>
        ) : (
          <p className="lede">{wrong.length ? `${wrong.length} question(s) à revoir ci-dessous.` : 'Sans faute.'}</p>
        )}
      </header>

      <div className="result-actions">
        <button className="secondary" onClick={onHome}>
          Accueil
        </button>
        {(mode === 'exam' || wrong.length > 0) && (
          <button className="primary" onClick={onRetry}>
            {mode === 'exam' ? 'Nouvel examen' : 'Refaire les erreurs'}
          </button>
        )}
      </div>

      {wrong.length > 0 && <h2 className="section-title">Corrections</h2>}
      {wrong.map(({ q, a }) => (
        <article key={q.id} className="card review">
          <p className="qmeta mono">n° {q.id}</p>
          <h3>{q.q}</h3>
          {q.img && <Picture id={q.img} />}
          {a !== null && <p className="your wrong-text">Votre réponse : {q.a[a]}</p>}
          {a === null && <p className="your wrong-text">Sans réponse</p>}
          <p className="your right-text">Bonne réponse : {q.a[q.c]}</p>
          <Explanation question={q} chosen={a} onAsk={() => ask({ question: q, chosen: a })} />
        </article>
      ))}
    </main>
  )
}
