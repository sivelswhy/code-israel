import { useDeferredValue, useMemo, useState } from 'react'
import { CATEGORIES, type Category, type Question } from './data'
import type { Stat } from './store'
import { BackButton } from './App'
import { FavoriteButton, Original, Picture } from './Quiz'
import { Explanation } from './Explanation'
import { useAssistant } from './assistant-context'
import { answerSign, SignImage, useSigns } from './Signs'

const PAGE = 30

function normalize(s: string) {
  return s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
}

export function Browse({ pool, stats, favorites, onFavorite, onBack }: { pool: Question[]; stats: Record<string, Stat>; favorites: string[]; onFavorite: (id: string) => void; onBack: () => void }) {
  const [query, setQuery] = useState('')
  const [cat, setCat] = useState<Category | 'all'>('all')
  const [limit, setLimit] = useState(PAGE)
  const deferred = useDeferredValue(query)
  const ask = useAssistant()
  const signs = useSigns()

  const results = useMemo(() => {
    const n = normalize(deferred.trim())
    return pool.filter(
      (q) =>
        (cat === 'all' || q.cat === cat) &&
        (!n || q.id.includes(n) || normalize(q.q).includes(n) || q.a.some((a) => normalize(a).includes(n))),
    )
  }, [pool, deferred, cat])

  return (
    <main className="page">
      <BackButton onClick={onBack} />
      <h1 className="title">Toutes les questions</h1>
      <div className="search-bar">
        <input
          type="search"
          placeholder="Rechercher un mot ou un numéro"
          value={query}
          onChange={(e) => {
            setQuery(e.target.value)
            setLimit(PAGE)
          }}
        />
        <div className="segmented" role="tablist">
          {(['all', ...Object.keys(CATEGORIES)] as const).map((c) => (
            <button key={c} role="tab" aria-selected={cat === c} onClick={() => (setCat(c as Category | 'all'), setLimit(PAGE))}>
              {c === 'all' ? 'Tout' : CATEGORIES[c as Category].label.split(' ')[0]}
            </button>
          ))}
        </div>
      </div>
      <p className="muted small">{results.length} résultat(s)</p>

      {results.slice(0, limit).map((q) => (
        <article key={q.id} className="card review">
          <p className="qmeta">
            <span className="mono">n° {q.id}</span> · {CATEGORIES[q.cat].label}
            {stats[q.id] && <i className={`dot ${stats[q.id].last ? 'ok' : 'ko'}`} title={stats[q.id].last ? 'Réussie' : 'Ratée'} />}
            <FavoriteButton on={favorites.includes(q.id)} onClick={() => onFavorite(q.id)} />
          </p>
          <h3>{q.q}</h3>
          {q.img && <Picture id={q.img} />}
          <ul className="plain">
            {q.a.map((a, i) => (
              <li key={i} className={i === q.c ? 'right-text' : 'muted'}>
                {answerSign(q, a, signs) ? (
                  <span className="answer-sign">
                    <SignImage n={a.trim()} sign={signs[a.trim()]} size={40} />
                    <span>
                      <span className="mono">Panneau {a.trim()}</span>
                      <small>{signs[a.trim()].fr}</small>
                    </span>
                  </span>
                ) : (
                  a
                )}
              </li>
            ))}
          </ul>
          <Explanation question={q} onAsk={() => ask({ question: q })} />
          <Original question={q} revealed />
        </article>
      ))}
      {limit < results.length && (
        <button className="secondary wide" onClick={() => setLimit(limit + PAGE)}>
          Afficher plus
        </button>
      )}
    </main>
  )
}
