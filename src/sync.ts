import type { Stat, Progress, ExamRecord } from './store.ts'
import type { DayCounters, JourneyProgress } from './journey/engine.ts'

/**
 * Progress shared between devices: the learner's sync code is the only key, nobody needs an account. The server only
 * sees a hash of the code. The same rules as the Mac and iPhone apps.
 */
const ALPHABET = 'ABCDEFGHJKMNPQRSTVWXYZ23456789'
export const CODE_LENGTH = 16

/** A new random code, e.g. `K7QM-2XTR-9HBD-4WCN`. */
export function generateCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(CODE_LENGTH * 4))
  // Rejection sampling keeps every letter equally likely.
  const limit = 256 - (256 % ALPHABET.length)
  const out: string[] = []
  for (const b of bytes) if (b < limit && out.length < CODE_LENGTH) out.push(ALPHABET[b % ALPHABET.length])
  return displayCode(out.join(''))
}

/** The code in capitals, without spaces or dashes; null when it cannot be a code. */
export function normalizeCode(text: string): string | null {
  const raw = text.toUpperCase().replace(/[^A-Z0-9]/g, '')
  return raw.length === CODE_LENGTH && [...raw].every((c) => ALPHABET.includes(c)) ? raw : null
}

export const displayCode = (raw: string) => raw.match(/.{1,4}/g)!.join('-')

/** What the server sees instead of the code: its SHA-256. The code itself never leaves the devices. */
export async function codeId(code: string): Promise<string | null> {
  const raw = normalizeCode(code)
  if (!raw) return null
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(`code-israel:${raw}`))
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

// ------------------------------------------------------------------------------------------------------- Merge

const maxBy = (a: Record<string, number>, b: Record<string, number>) => {
  const r = { ...a }
  for (const [k, v] of Object.entries(b)) r[k] = Math.max(r[k] ?? 0, v)
  return r
}
const union = (a: string[], b: string[]) => [...new Set([...a, ...b])].sort()

/** Brings the progress of two devices together. The result is the same whichever device is `a` or `b`. */
export function mergeProgress(a: Progress, b: Progress): Progress {
  // The scalar settings follow the device that changed last; counters only ever grow, so the larger one wins.
  const aNewer = (a.modified ?? 0) >= (b.modified ?? 0)
  const [fresh, old] = aNewer ? [a, b] : [b, a]
  const stats: Record<string, Stat> = { ...b.stats, ...a.stats }
  for (const id of Object.keys(stats)) {
    const x = a.stats[id]
    const y = b.stats[id]
    if (x && y) stats[id] = x.ok + x.ko !== y.ok + y.ko ? (x.ok + x.ko > y.ok + y.ko ? x : y) : aNewer ? x : y
  }
  return {
    ...fresh,
    modified: fresh.modified,
    license: fresh.license,
    examDate: fresh.examDate ?? old.examDate,
    favorites: fresh.favorites,
    stats,
    daily: maxBy(a.daily, b.daily),
    exams: mergeExams(a.exams, b.exams),
    journey: mergeJourney(a.journey, b.journey, aNewer),
  }
}

const REVIEWABLE = 20

function mergeExams(a: ExamRecord[], b: ExamRecord[]): ExamRecord[] {
  const byKey = new Map<string, ExamRecord>()
  for (const e of [...a, ...b]) {
    const key = `${Math.floor(e.date / 1000)}-${e.license}-${e.errors}`
    const old = byKey.get(key)
    // The copy that kept its answers is preferred.
    if (old && (old.ids || !e.ids)) continue
    byKey.set(key, e)
  }
  const exams = [...byKey.values()].sort((x, y) => x.date - y.date || x.errors - y.errors)
  return exams.map((e, i) => (i < exams.length - REVIEWABLE ? { date: e.date, errors: e.errors, license: e.license } : e))
}

function mergeJourney(a: JourneyProgress, b: JourneyProgress, aNewer: boolean): JourneyProgress {
  const [fresh, old] = aNewer ? [a, b] : [b, a]
  const lessons = { ...a.lessons }
  for (const [id, r] of Object.entries(b.lessons)) {
    const x = lessons[id]
    lessons[id] = x ? { stars: Math.max(x.stars, r.stars), completions: Math.max(x.completions, r.completions) } : r
  }
  const xpByDay = maxBy(a.xpByDay, b.xpByDay)
  const review = { ...a.review }
  for (const [id, y] of Object.entries(b.review)) {
    const x = review[id]
    review[id] = !x ? y : x.last !== y.last ? (x.last > y.last ? x : y) : x.h >= y.h ? x : y
  }
  return {
    lessons,
    xpByDay,
    // The total is at least the XP of every day: two devices that earned XP on different days add up.
    xp: Math.max(a.xp, b.xp, Object.values(xpByDay).reduce((n, v) => n + v, 0)),
    review,
    frozenDays: union(a.frozenDays, b.frozenDays),
    freezes: fresh.freezes,
    chestsOpened: Math.max(a.chestsOpened, b.chestsOpened),
    hours: maxBy(a.hours, b.hours),
    ability: fresh.ability,
    difficulty: { ...old.difficulty, ...fresh.difficulty },
    today: mergeDay(a.today, b.today),
  }
}

function mergeDay(a: DayCounters, b: DayCounters): DayCounters {
  if (a.day !== b.day) return a.day > b.day ? a : b
  return {
    day: a.day,
    lessons: Math.max(a.lessons, b.lessons),
    perfect: Math.max(a.perfect, b.perfect),
    reviews: Math.max(a.reviews, b.reviews),
    bestRun: Math.max(a.bestRun, b.bestRun),
    claimed: union(a.claimed, b.claimed) as DayCounters['claimed'],
    chestOpened: a.chestOpened || b.chestOpened,
  }
}

// -------------------------------------------------------------------------------------------------- Wire format

/** The progress as it travels between devices (the Mac and iPhone apps read the same shape). */
export interface Wire {
  v: 1
  modified: number
  license: string
  examDate?: string
  favorites: string[]
  stats: Record<string, Stat>
  exams: { date: number; errors: number; license: string; ids?: string[]; answers?: (number | null)[] }[]
  daily: Record<string, number>
  journey: Omit<JourneyProgress, 'review'> & { review: Record<string, { halfLife: number; last: string }> }
}

export function toWire(p: Progress): Wire {
  const review = Object.fromEntries(Object.entries(p.journey.review).map(([id, r]) => [id, { halfLife: r.h, last: r.last }]))
  return {
    v: 1,
    modified: p.modified ?? 0,
    license: p.license,
    examDate: p.examDate,
    favorites: p.favorites,
    stats: p.stats,
    exams: p.exams,
    daily: p.daily,
    journey: { ...p.journey, review },
  }
}

export function fromWire(w: Wire, base: Progress): Progress {
  const review = Object.fromEntries(Object.entries(w.journey?.review ?? {}).map(([id, r]) => [id, { h: r.halfLife, last: r.last }]))
  return {
    ...base,
    modified: w.modified,
    license: w.license as Progress['license'],
    examDate: w.examDate,
    favorites: w.favorites ?? [],
    stats: w.stats ?? {},
    exams: (w.exams ?? []) as Progress['exams'],
    daily: w.daily ?? {},
    journey: { ...base.journey, ...w.journey, review },
  }
}

// ---------------------------------------------------------------------------------------------------- Client

const CODE_KEY = 'code-israel:sync-code'
const LAST_KEY = 'code-israel:sync-last'

export const savedCode = () => {
  try {
    return localStorage.getItem(CODE_KEY)
  } catch {
    return null
  }
}

export function saveCode(code: string | null) {
  try {
    if (code) localStorage.setItem(CODE_KEY, code)
    else {
      localStorage.removeItem(CODE_KEY)
      localStorage.removeItem(LAST_KEY)
    }
  } catch {
    // Storage unavailable: the code lasts until the page is reloaded.
  }
}

export const lastSync = () => {
  try {
    return Number(localStorage.getItem(LAST_KEY)) || null
  } catch {
    return null
  }
}

interface SyncConfig {
  /** The sync server. */
  url: string | null
  /** The function that mails the code, when one has been set up. */
  mail: string | null
}

let config: Promise<SyncConfig> | null = null

/** Addresses from `sync.json` (written when the servers are deployed). A null `url`: sync is not available. */
export function syncConfig(base: string): Promise<SyncConfig> {
  config ??= fetch(`${base}sync.json`)
    .then((r): Promise<{ url?: string; mail?: string }> => (r.ok ? r.json() : Promise.resolve({})))
    .then(
      (j) => ({ url: j?.url ? String(j.url).replace(/\/$/, '') : null, mail: j?.mail ? String(j.mail) : null }),
      () => ({ url: null, mail: null }),
    )
  return config
}

export const syncServer = (base: string) => syncConfig(base).then((c) => c.url)

/** Asks the mail function to send the code. Returns an error message, or null when it was sent. */
export async function mailCode(email: string, code: string, base: string): Promise<string | null> {
  const { mail } = await syncConfig(base)
  if (!mail) return 'L’envoi par e-mail n’est pas disponible.'
  try {
    const r = await fetch(mail, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ email, code }) })
    if (r.ok) return null
    return (await r.json().catch(() => null))?.error ?? `Envoi impossible (${r.status}).`
  } catch {
    return 'Pas de connexion : réessayez plus tard.'
  }
}

/** Downloads the saved progress, merges it with this device's, uploads the result and returns it. */
export async function syncNow(local: Progress, code: string, base: string): Promise<Progress> {
  const server = await syncServer(base)
  const id = await codeId(code)
  if (!server || !id) throw new Error('Synchronisation indisponible.')
  const response = await fetch(`${server}/p/${id}`)
  let merged = local
  if (response.ok) merged = mergeProgress(local, fromWire((await response.json()) as Wire, local))
  else if (response.status !== 404) throw new Error(`Le serveur a répondu ${response.status}.`)
  const put = await fetch(`${server}/p/${id}`, { method: 'PUT', headers: { 'content-type': 'application/json' }, body: JSON.stringify(toWire(merged)) })
  if (!put.ok) throw new Error(`Envoi impossible (${put.status}).`)
  try {
    localStorage.setItem(LAST_KEY, String(Date.now()))
  } catch {
    // Storage unavailable: only the "last synchronisation" label is lost.
  }
  return merged
}
