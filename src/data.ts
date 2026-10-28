export type Category = 'rules' | 'safety' | 'signs' | 'vehicle'
export type License = 'B' | 'A' | '1' | 'C1' | 'C' | 'D'

export interface Question {
  id: string
  q: string
  a: string[]
  /** Index of the correct answer in `a`. */
  c: number
  /** Official picture id, served from /img/<id>.jpg. */
  img: string | null
  lic: License[]
  cat: Category
  /** True when the French text was revised against the Hebrew original. */
  rev?: boolean
  /** Explanation of the rule, in French. */
  e?: string
  /** Legal references (keys of law.json). */
  r?: string[]
}

export interface LawExcerpt {
  /** French label, e.g. "Règlement de la circulation, art. 47(d)". */
  l: string
  /** Hebrew section title. */
  t: string
  /** Official Hebrew text of the cited excerpt. */
  x: string
  /** French rendering of the excerpt (translated from the Hebrew), when available. */
  f?: string
  src: string
  u: string
}

export const CATEGORIES: Record<Category, { label: string; hint: string }> = {
  rules: { label: 'Code de la route', hint: 'Priorités, vitesses, stationnement, documents' },
  safety: { label: 'Sécurité', hint: 'Comportement, distances, conditions difficiles' },
  signs: { label: 'Panneaux', hint: 'Signalisation et marquages au sol' },
  vehicle: { label: 'Connaissance du véhicule', hint: 'Mécanique, entretien, équipements' },
}

export const LICENSES: Record<License, string> = {
  B: 'Voiture (B)',
  A: 'Moto (A)',
  '1': 'Tracteur (1)',
  C1: 'Poids lourd léger (C1)',
  C: 'Poids lourd (C)',
  D: 'Autobus (D)',
}

/**
 * Licenses currently offered. The others (tractor, trucks, bus) are on hold: their questions stay in
 * the data, but nothing in the interface exposes them. Add a key here to bring one back.
 */
export const ACTIVE_LICENSES: License[] = ['B', 'A']

import { EXAM } from './exam.ts'
export { EXAM }

/** Resolves a path of the site (e.g. `/img/3012.jpg`) against the base URL, since the site may live in a subfolder. */
export const asset = (path: string) => import.meta.env.BASE_URL + path.replace(/^\//, '')

const cache = new Map<string, Promise<Question[]>>()

export function loadQuestions(lang: 'fr' | 'he'): Promise<Question[]> {
  if (!cache.has(lang)) {
    cache.set(
      lang,
      fetch(asset(`data/questions.${lang}.json`)).then((r) => {
        if (!r.ok) throw new Error(`HTTP ${r.status}`)
        return r.json()
      }),
    )
  }
  return cache.get(lang)!
}

let lawCache: Promise<Record<string, LawExcerpt>> | null = null

export function loadLaw(): Promise<Record<string, LawExcerpt>> {
  lawCache ??= fetch(asset('data/law.json')).then((r) => {
    if (!r.ok) throw new Error(`HTTP ${r.status}`)
    return r.json()
  })
  return lawCache
}

export function shuffle<T>(items: T[]): T[] {
  const a = items.slice()
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[a[i], a[j]] = [a[j], a[i]]
  }
  return a
}

/** Draw an exam that keeps each category's share of the pool for this license. */
export function drawExam(pool: Question[]): Question[] {
  const byCat = new Map<Category, Question[]>()
  for (const q of pool) byCat.set(q.cat, [...(byCat.get(q.cat) ?? []), q])
  const picked: Question[] = []
  for (const qs of byCat.values()) {
    picked.push(...shuffle(qs).slice(0, Math.round((qs.length / pool.length) * EXAM.size)))
  }
  const rest = shuffle(pool.filter((q) => !picked.includes(q)))
  return shuffle([...picked, ...rest].slice(0, EXAM.size))
}
