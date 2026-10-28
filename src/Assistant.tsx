import { useEffect, useMemo, useRef, useState } from 'react'
import { motion } from 'motion/react'
import { loadLaw, type LawExcerpt, type Question } from './data'
import { convertUnits } from './assistant/units'
import { FOLLOW_UP_HINT, kindHint, LawIndex, personalNote, QuestionIndex, questionKind, REFERS_TO_PREVIOUS, reply, retrieve, sources, tidyAnswer, tokens, unsupported, vehicleMismatch, type Stat } from './assistant/search'
import { answer, cancel, detect, explain, isCached, load, type Support } from './assistant/llm'
import type { AssistantTopic } from './assistant-context'
import { spring } from './App'
import { MagicStar } from 'reicon-react'
import { useSigns } from './Signs'

interface Message {
  role: 'user' | 'assistant'
  text: string
  hits?: Question[]
  streaming?: boolean
  /** A remark about the learner's own results, composed by the app. */
  note?: string | null
}

type Engine =
  | { state: 'detecting' }
  | { state: 'unsupported'; reason: string }
  | { state: 'idle'; support: Extract<Support, { ok: true }>; resume?: string }
  | { state: 'loading'; modelId: string; progress: number; text: string; support: Extract<Support, { ok: true }> }
  | { state: 'ready'; modelId: string }
  | { state: 'error'; message: string; support: Extract<Support, { ok: true }>; modelId: string }

const COMPLETE = 'code-israel:assistant-complete'

/** Models whose download finished; the browser cache alone can't tell a partial download from a full one. */
function completed(): string[] {
  try {
    return JSON.parse(localStorage.getItem(COMPLETE) ?? '[]')
  } catch {
    return []
  }
}

function markComplete(id: string) {
  try {
    localStorage.setItem(COMPLETE, JSON.stringify([...new Set([...completed(), id])]))
  } catch {
    // Not remembered: the model is simply re-verified from cache next time.
  }
}

/** Openers of a question that continues the previous one ("et pour les motos ?"). */
const FOLLOW_UP = /^\s*(et|mais|alors|donc|aussi|pareil|même|pour|avec|sans|si)\b/i

export function Assistant({ questions, stats, topic, onClose }: { questions: Question[]; stats: Record<string, Stat>; topic?: AssistantTopic; onClose: () => void }) {
  const index = useMemo(() => new QuestionIndex(questions), [questions])
  const [law, setLaw] = useState<Record<string, LawExcerpt>>({})
  const lawIndex = useMemo(() => new LawIndex(law), [law])
  const signs = useSigns()
  const [engine, setEngine] = useState<Engine>({ state: 'detecting' })
  const [messages, setMessages] = useState<Message[]>([])
  const [input, setInput] = useState('')
  const abort = useRef<AbortController | null>(null)
  // What the last answer was based on, so a follow-up ("et ça fait combien en miles ?") can use the same sources.
  const carry = useRef<{ sourceText: string; hits: Question[]; answer: string } | null>(null)
  const stopped = useRef(false)
  const scroller = useRef<HTMLDivElement>(null)
  const desktop = useMemo(() => matchMedia('(min-width: 900px)').matches, [])

  useEffect(() => {
    loadLaw().then(setLaw, () => {})
    detect().then(async (support) => {
      if (!support.ok) return setEngine({ state: 'unsupported', reason: support.reason })
      const done = completed()
      const m = support.model
      if (done.includes(m.id) && (await isCached(m.id))) return start(m.id, support)
      // A partial download may exist: offer to resume it rather than silently using mobile data.
      if (await isCached(m.id)) return setEngine({ state: 'idle', support, resume: m.id })
      setEngine({ state: 'idle', support })
    })
    return () => abort.current?.abort()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  useEffect(() => {
    scroller.current?.scrollTo({ top: scroller.current.scrollHeight, behavior: 'smooth' })
  }, [messages])

  function start(modelId: string, support: Extract<Support, { ok: true }>) {
    stopped.current = false
    setEngine({ state: 'loading', modelId, progress: 0, text: '', support })
    load(modelId, (progress, text) => !stopped.current && setEngine({ state: 'loading', modelId, progress, text, support })).then(
      () => {
        markComplete(modelId)
        setEngine({ state: 'ready', modelId })
      },
      (e: unknown) => {
        if (stopped.current) return
        detect().then((support) => support.ok && setEngine({ state: 'error', message: explain(e), support, modelId }))
      },
    )
  }

  function stop(support: Extract<Support, { ok: true }>) {
    stopped.current = true
    cancel()
    setEngine({ state: 'idle', support })
  }

  async function send(text: string) {
    const clean = text.trim()
    if (!clean || messages.some((m) => m.streaming)) return
    setInput('')
    const focus = topic?.question
    // A unit conversion is answered exactly by the app, from the previous answer or the question in focus.
    const converted = convertUnits(clean, carry.current?.answer ?? (focus ? `${focus.a[focus.c]} ${focus.e ?? ''}` : undefined))
    if (converted) {
      setMessages((m) => [...m, { role: 'user', text: clean }, { role: 'assistant', text: converted, hits: carry.current?.hits ?? [] }])
      return
    }
    // A short follow-up ("et pour plus de 125 ?") only makes sense with the previous question.
    const previous = [...messages].reverse().find((m) => m.role === 'user')?.text
    const query = focus ? `${clean} ${focus.q}` : previous && FOLLOW_UP.test(clean) || (previous && tokens(clean).length <= 1) ? `${previous} ${clean}` : clean
    const found = retrieve(index, lawIndex, query)
    // Sources about another kind of vehicle than the one asked about are not an answer.
    const off = !focus && vehicleMismatch(query, found.hits[0], found.lawHits[0])
    const hits = off ? [] : found.hits
    const lawHits = off ? [] : found.lawHits
    const found2 = focus ? [focus, ...hits.filter((h) => h.id !== focus.id)].slice(0, 4) : hits
    // A follow-up keeps the sources and the answer of the previous turn: the new search may find nothing,
    // or something unrelated, for "plus simplement" or "ça fait combien".
    const last = carry.current
    const followUp = !!last && !focus && REFERS_TO_PREVIOUS.test(clean)
    const extra = last ? found2.filter((h) => !last.hits.some((p) => p.id === h.id)) : found2
    const shown = followUp ? [...last.hits, ...extra].slice(0, 4) : found2
    // With no matching official source the model would improvise, so it is not asked.
    const ai = engine.state === 'ready' && shown.length > 0
    // Without the on-device model the answer is composed directly from the best official question.
    const kind = questionKind(clean)
    const direct = followUp
      ? `Je n’ai pas de source plus précise pour cette demande. Rappel de ma réponse précédente :\n${last.answer}`
      : reply(shown, law, signs, focus, topic?.chosen, lawHits, query, clean)
    const note = personalNote(topic, shown, stats, questions)
    setMessages((m) => [...m, { role: 'user', text: clean }, { role: 'assistant', text: ai ? '' : direct, hits: shown, streaming: ai, note }])
    const sourceText = followUp
      ? last.sourceText + (extra.length ? `\n\n${sources(extra, law, undefined, signs, [], query)}` : '')
      : sources(shown, law, focus, signs, lawHits, query)
    if (!ai) {
      // Only an answer built on sources becomes the next context (not a reminder).
      if (!followUp && shown.length && direct) carry.current = { sourceText, hits: shown, answer: direct }
      return
    }

    const ctl = new AbortController()
    abort.current = ctl
    const context = focus && topic.chosen != null && topic.chosen !== focus.c ? `\n(L'élève avait répondu « ${focus.a[topic.chosen]} », ce qui est faux : explique d'abord en une phrase pourquoi cette réponse est fausse, puis donne la bonne règle.)` : ''
    // Only a follow-up carries the previous question; with a question in focus the focus is the context.
    const asked = !focus && query !== clean ? `${previous} (suite) ${clean}` : clean
    let written = ''
    try {
      // No chat history: the model's earlier (possibly wrong) answers would feed its next ones.
      for await (const delta of answer(engine.modelId, asked + context + (followUp ? FOLLOW_UP_HINT : kindHint(kind) ? `\nTYPE DE DEMANDE : ${kindHint(kind)}` : ''), sourceText, [], ctl.signal, followUp ? last.answer : undefined)) {
        written += delta
        setMessages((m) => m.map((msg, i) => (i === m.length - 1 ? { ...msg, text: msg.text + delta } : msg)))
      }
      // A small model sometimes invents figures or law articles. If the answer cites one found neither in the
      // sources nor in the question, fall back to the answer composed from the official text.
      if (unsupported(written, sourceText, query) && !ctl.signal.aborted) setMessages((m) => m.map((msg, i) => (i === m.length - 1 ? { ...msg, text: direct } : msg)))
      else {
        const tidy = tidyAnswer(written)
        setMessages((m) => m.map((msg, i) => (i === m.length - 1 ? { ...msg, text: tidy } : msg)))
        carry.current = { sourceText, hits: shown, answer: tidy }
      }
    } catch {
      setMessages((m) => m.map((msg, i) => (i === m.length - 1 ? { ...msg, text: msg.text || direct } : msg)))
    } finally {
      setMessages((m) => m.map((msg, i) => (i === m.length - 1 ? { ...msg, streaming: false } : msg)))
    }
  }

  const suggestions = topic
    ? [
        topic.chosen != null && topic.chosen !== topic.question.c
          ? `Pourquoi ma réponse « ${topic.question.a[topic.chosen]} » est-elle fausse ?`
          : `Pourquoi la bonne réponse est-elle « ${topic.question.a[topic.question.c]} » ?`,
        'Donne-moi un moyen simple de retenir cette règle.',
      ]
    : ['Quelle est la vitesse maximale en agglomération ?', 'Qui doit céder le passage à une intersection sans panneau ?', 'Quelles règles pour un nouveau conducteur ?']

  return (
    <>
      {!desktop && <motion.div className="scrim" onClick={onClose} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} />}
      <motion.aside
        className="assistant"
        role="dialog"
        aria-label="Assistant code de la route"
        initial={desktop ? { x: '100%' } : { y: '100%' }}
        animate={desktop ? { x: 0 } : { y: 0 }}
        exit={desktop ? { x: '100%' } : { y: '100%' }}
        transition={spring}
      >
        <header className="assistant-bar">
          <span className="assistant-title">
            <MagicStar size={20} weight="Filled" /> Assistant
          </span>
          <button className="link" onClick={onClose}>
            Fermer
          </button>
        </header>

        <div className="assistant-scroll" ref={scroller}>
          <EngineCard engine={engine} onStart={(id) => engine.state === 'idle' || engine.state === 'error' ? start(id, engine.support) : undefined} onStop={() => engine.state === 'loading' && stop(engine.support)} />

          {topic && (
            <div className="topic">
              <span className="mono muted small">Question n° {topic.question.id}</span>
              <p>{topic.question.q}</p>
            </div>
          )}

          {messages.map((m, i) =>
            m.role === 'user' ? (
              <p key={i} className="bubble user">
                {m.text}
              </p>
            ) : (
              <div key={i} className="bubble bot">
                {m.note && <p className="bot-note">{m.note}</p>}
                {m.text && <p className="bot-text">{m.text}</p>}
                {m.streaming && !m.text && <p className="muted">Réflexion…</p>}
                {!m.streaming && m.hits?.length === 0 && !m.text && (
                  <p className="muted">Je n'ai rien trouvé à ce sujet dans la banque officielle. Essayez d'autres mots.</p>
                )}
                {!m.streaming && m.hits && m.hits.length > 0 && (
                  <details className="sources-fold">
                    <summary className="muted small">Voir les {m.hits.length} questions officielles utilisées</summary>
                    <Sources hits={m.hits} law={law} />
                  </details>
                )}
              </div>
            ),
          )}

          {messages.length === 0 && (
            <div className="suggestions">
              {suggestions.map((s) => (
                <button key={s} onClick={() => send(s)}>
                  {s}
                </button>
              ))}
            </div>
          )}
        </div>

        <form
          className="assistant-input"
          onSubmit={(e) => {
            e.preventDefault()
            send(input)
          }}
        >
          <input value={input} onChange={(e) => setInput(e.target.value)} placeholder="Posez votre question sur le code de la route" enterKeyHint="send" />
          <button className="primary" type="submit" disabled={!input.trim() || messages.some((m) => m.streaming)} aria-label="Envoyer">
            ↑
          </button>
        </form>
      </motion.aside>
    </>
  )
}

function EngineCard({ engine, onStart, onStop }: { engine: Engine; onStart: (id: string) => void; onStop: () => void }) {
  switch (engine.state) {
    case 'detecting':
      return null
    case 'ready':
      return <p className="engine-note">IA active sur votre appareil — gratuite, hors ligne, rien n'est envoyé sur internet.</p>
    case 'unsupported':
      return (
        <p className="engine-note">
          {engine.reason} L'assistant fonctionne en mode recherche : il retrouve les questions officielles, les explications et les articles de loi correspondants.
        </p>
      )
    case 'error':
      return (
        <div className="engine-card">
          <p>{engine.message}</p>
          <div className="engine-actions">
            <button className="primary" onClick={() => onStart(engine.modelId)}>
              Réessayer
            </button>
          </div>
          <p className="muted small">Le mode recherche reste disponible en attendant.</p>
        </div>
      )
    case 'loading':
      return (
        <div className="engine-card">
          <p>Préparation de l'IA… {Math.round(engine.progress * 100)} %</p>
          <div className="track" aria-hidden="true">
            <div className="track-fill" style={{ transform: `scaleX(${engine.progress})` }} />
          </div>
          {engine.text && <p className="muted small">{engine.text}</p>}
          <button className="link" onClick={onStop}>
            Annuler
          </button>
          <p className="muted small">Téléchargement unique, ensuite l'IA fonctionne même hors ligne. Vous pouvez déjà poser des questions en mode recherche.</p>
        </div>
      )
    case 'idle':
      return (
        <div className="engine-card">
          {engine.resume && (
            <p>
              <strong>Téléchargement interrompu.</strong> Ce qui est déjà reçu est conservé : la reprise ne retélécharge pas tout.
            </p>
          )}
          <p>
            <strong>Activer l'IA gratuite ?</strong> Elle fonctionne entièrement sur votre appareil et répond à partir des textes officiels.
          </p>
          <p className="muted small">
            {engine.support.model.label} : téléchargement unique de {engine.support.model.size}. Wi-Fi recommandé.
          </p>
          <div className="engine-actions">
            <button className="primary" onClick={() => onStart(engine.resume ?? engine.support.model.id)}>
              {engine.resume ? 'Reprendre' : 'Activer'}
            </button>
          </div>
          <p className="muted small">Sans IA, l'assistant fonctionne déjà en mode recherche.</p>
        </div>
      )
  }
}

function Sources({ hits, law }: { hits: Question[]; law: Record<string, LawExcerpt> }) {
  return (
    <ul className="sources">
      {hits.map((q) => (
        <li key={q.id}>
          <span className="mono muted small">n° {q.id}</span>
          <p className="src-q">{q.q}</p>
          <p className="right-text">{q.a[q.c]}</p>
          {q.e && <p className="small">{q.e}</p>}
          {q.r && q.r.length > 0 && <p className="muted small">{q.r.map((r) => law[r]?.l ?? r).join(' · ')}</p>}
          {q.r?.map((r) => law[r]?.f && (
            <p key={r} className="small law-text">
              <strong>{law[r].l}</strong> — {law[r].f}
            </p>
          ))}
        </li>
      ))}
    </ul>
  )
}
