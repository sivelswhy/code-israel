import type { WebWorkerMLCEngine } from '@mlc-ai/web-llm'

// The library is ~6 MB: load it only when the assistant needs it.
const webllm = () => import('@mlc-ai/web-llm')

/**
 * Free, on-device language model (WebLLM + WebGPU). Nothing is sent to a server; the model is
 * downloaded once from Hugging Face and then served from the browser cache.
 */

export interface ModelChoice {
  id: string
  label: string
  /** Approximate download / memory size, for the consent prompt. */
  size: string
}

const MODEL = { base: 'Qwen3.5-2B', label: 'Qwen3.5 2B', size: '≈ 2,2 Go' }

export type Support = { ok: true; model: ModelChoice } | { ok: false; reason: string }

export async function detect(): Promise<Support> {
  const gpu = (navigator as Navigator & { gpu?: { requestAdapter(): Promise<{ features: Set<string> } | null> } }).gpu
  if (!gpu) return { ok: false, reason: 'Ce navigateur ne prend pas en charge WebGPU.' }
  const adapter = await gpu.requestAdapter().catch(() => null)
  if (!adapter) return { ok: false, reason: 'Aucune carte graphique compatible WebGPU n’a été trouvée.' }
  const quant = adapter.features.has('shader-f16') ? 'q4f16_1' : 'q4f32_1'
  const model: ModelChoice = { id: `${MODEL.base}-${quant}-MLC`, label: MODEL.label, size: MODEL.size }
  return { ok: true, model }
}

export const isCached = (id: string) => webllm().then((m) => m.hasModelInCache(id)).catch(() => false)

type Listener = (progress: number, text: string) => void

let engine: Promise<WebWorkerMLCEngine> | null = null
let loadedId: string | null = null
let worker: Worker | null = null
let last = { progress: 0, text: '' }
const listeners = new Set<Listener>()

const ATTEMPTS = 4
const wait = (ms: number) => new Promise((r) => setTimeout(r, ms))

function emit(progress: number, text: string) {
  // Never go backwards: WebLLM reports per-phase progress that can briefly drop.
  last = { progress: Math.max(last.progress, progress), text }
  listeners.forEach((l) => l(last.progress, last.text))
}

/** Turns WebLLM's English status lines into short French ones. */
function describe(raw: string) {
  const m = /Fetching param cache\[(\d+)\/(\d+)\]: (\d+)MB fetched/.exec(raw)
  if (m) return `Téléchargement : ${m[3]} Mo (fichier ${m[1]}/${m[2]})`
  if (/Loading GPU shader|Finish loading on WebGPU/i.test(raw)) return 'Préparation sur la carte graphique…'
  if (/Start to fetch params|Loading model from cache/i.test(raw)) return 'Lecture du modèle…'
  return raw
}

async function create(id: string) {
  const m = await webllm()
  worker?.terminate()
  worker = new Worker(new URL('./llm.worker.ts', import.meta.url), { type: 'module' })
  return m.CreateWebWorkerMLCEngine(worker, id, {
    initProgressCallback: (r) => emit(r.progress, describe(r.text)),
  })
}

/**
 * Loads (and downloads, the first time) a model. Calling it again while the same model is loading
 * just attaches another progress listener, so closing and reopening the panel keeps working.
 * Files already fetched stay in the browser cache, so every retry resumes instead of restarting.
 */
export function load(id: string, onProgress: Listener) {
  if (loadedId !== id) {
    cancel()
    loadedId = id
    last = { progress: 0, text: '' }
  }
  listeners.add(onProgress)
  onProgress(last.progress, last.text)
  if (engine) return engine

  // Ask the browser not to evict the multi-hundred-MB cache when storage runs low.
  navigator.storage?.persist?.().catch(() => {})

  const run = (async () => {
    let failure: unknown
    for (let attempt = 1; attempt <= ATTEMPTS; attempt++) {
      try {
        return await create(id)
      } catch (e) {
        failure = e
        if (loadedId !== id) break // cancelled
        if (attempt < ATTEMPTS) {
          emit(last.progress, `Connexion interrompue, nouvelle tentative (${attempt + 1}/${ATTEMPTS})…`)
          await wait(1500 * attempt)
        }
      }
    }
    throw failure
  })()
  engine = run
  const done = () => {
    listeners.clear()
    if (engine === run) {
      // Keep a successful engine; drop a failed one so the next click starts clean.
      run.catch(() => {
        if (engine === run) {
          engine = null
          loadedId = null
          worker?.terminate()
          worker = null
        }
      })
    }
  }
  run.then(done, done)
  return run
}

/** Stops an in-progress download. Already-fetched files remain cached for next time. */
export function cancel() {
  engine = null
  loadedId = null
  listeners.clear()
  worker?.terminate()
  worker = null
}

/** Human-readable reason for a failed load. */
export function explain(e: unknown) {
  const msg = e instanceof Error ? e.message : String(e)
  if (/quota|storage|disk/i.test(msg)) return 'Espace de stockage insuffisant sur cet appareil. Libérez de la place puis réessayez.'
  if (/fetch|network|load failed|failed to/i.test(msg)) return 'Le téléchargement a été interrompu (connexion instable ?). Réessayez : ce qui est déjà téléchargé est conservé.'
  if (/memory|out of|device lost|gpu/i.test(msg)) return 'Mémoire insuffisante pour ce modèle. Fermez d’autres onglets ou applications, puis réessayez.'
  return msg
}

export const SYSTEM = `Tu es un moniteur d'auto-école qui prépare des francophones à l'examen théorique du code de la route en Israël.
Règles absolues :
- Réponds uniquement à partir des SOURCES fournies (questions officielles, explications, références légales). N'invente jamais un article, un chiffre ou une règle.
- Utilise uniquement la source qui répond directement à la question posée et ignore les autres, même si elles parlent d'un sujet voisin. Ne mélange jamais des règles de sources différentes.
- Si aucune source ne répond précisément à la question, réponds seulement « Je n'ai pas trouvé cette information dans les sources » et propose de reformuler (ne devine pas). Le silence des sources ne prouve jamais qu'une chose est permise, interdite ou sans conséquence : ne conclus jamais « non » ou « ce n'est pas grave » faute de source.
- Reprends les mots des sources sans rien interpréter. Ne commence jamais par « oui » ou « non » : énonce d'abord la règle des sources, puis seulement ensuite la conclusion si elle en découle directement.
- Quand tu t'appuies sur une règle, cite la référence telle qu'elle apparaît dans les sources (par exemple « Règlement de la circulation, art. 47(d) »).
- Chaque chiffre, unité ou numéro de panneau que tu écris doit apparaître tel quel dans les SOURCES. N'ajoute aucune condition, exception ou catégorie de véhicule qui n'y figure pas.
- Réponds directement à ce que l'élève demande : ne répète jamais sa question, commence par la réponse en une phrase (la raison, le chiffre, la personne, le moment ou la manière demandés), puis cite seulement la référence de l'article, sans recopier son texte.
- Réponds en français clair, en 80 mots maximum, avec des phrases courtes.`

export async function* answer(
  id: string,
  question: string,
  sourceText: string,
  history: { role: 'user' | 'assistant'; content: string }[],
  signal: AbortSignal,
  /** The assistant's previous answer, when the message refers to it ("ça", "plus simplement"). */
  previousAnswer?: string,
) {
  const e = await load(id, () => {})
  const stream = await e.chat.completions.create({
    stream: true,
    temperature: 0.1,
    max_tokens: 250,
    // Small models can loop on a single word; discourage repeats.
    frequency_penalty: 0.4,
    presence_penalty: 0.2,
    extra_body: { enable_thinking: false },
    messages: [
      { role: 'system', content: SYSTEM },
      ...history.slice(-4),
      { role: 'user', content: `SOURCES :\n${sourceText}${previousAnswer ? `\n\nTA RÉPONSE PRÉCÉDENTE (pour comprendre « ça », « cela »…) :\n${previousAnswer}` : ''}\n\nQUESTION DE L'ÉLÈVE :\n${question}` },
    ],
  })
  // Qwen may emit an (empty) <think> block even with thinking disabled: never show it.
  const visible = (t: string) => t.replace(/<think>[\s\S]*?<\/think>\s*/g, '').replace(/<think>[\s\S]*$/, '').replace(/<\/?t?h?i?n?k?$/, '')
  let raw = ''
  let shown = 0
  for await (const chunk of stream) {
    if (signal.aborted) {
      e.interruptGenerate()
      return
    }
    raw += chunk.choices[0]?.delta?.content ?? ''
    const text = visible(raw).trimStart()
    if (text.length > shown) {
      yield text.slice(shown)
      shown = text.length
    }
  }
}
