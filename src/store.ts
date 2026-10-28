import { useCallback, useState } from 'react'
import { ACTIVE_LICENSES, type License } from './data'
import { emptyJourney, loadJourney, streakOf, type JourneyProgress } from './journey/engine'

export interface Stat {
  ok: number
  ko: number
  /** Whether the last attempt was correct. */
  last: boolean
}

export interface ExamRecord {
  date: number
  errors: number
  license: License
  /** Questions drawn, in order. Only kept for the latest exams, so older ones cannot be reviewed. */
  ids?: string[]
  /** Index chosen in each question's `a` (null = unanswered), parallel to `ids`. */
  answers?: (number | null)[]
}

/** Exams whose questions and answers are kept for review. */
export const REVIEWABLE_EXAMS = 20

export interface Progress {
  license: License
  stats: Record<string, Stat>
  exams: ExamRecord[]
  /** Ids of the questions the learner starred. */
  favorites: string[]
  /** Questions answered per local date (YYYY-MM-DD). */
  daily: Record<string, number>
  /** The Parcours mode: lessons, XP, memory, quests. */
  journey: JourneyProgress
}

const KEY = 'code-israel:v1'
const EMPTY: Progress = { license: 'B', stats: {}, exams: [], favorites: [], daily: {}, journey: emptyJourney() }

function read(): Progress {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return EMPTY
    const parsed = JSON.parse(raw)
    const saved = { ...EMPTY, ...parsed, journey: loadJourney(parsed.journey) } as Progress
    // A license that is on hold falls back to the default one.
    return ACTIVE_LICENSES.includes(saved.license) ? saved : { ...saved, license: EMPTY.license }
  } catch {
    return EMPTY
  }
}

export function localDay(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

/** Consecutive days of practice ending today (or yesterday, so the streak survives until tonight). Days saved by a streak freeze keep it going. */
export function streak(daily: Record<string, number>, frozenDays: string[] = []) {
  return streakOf(daily, frozenDays)
}

export function useProgress() {
  const [progress, setProgress] = useState<Progress>(read)

  const update = useCallback((fn: (p: Progress) => Progress) => {
    setProgress((prev) => {
      const next = fn(prev)
      try {
        localStorage.setItem(KEY, JSON.stringify(next))
      } catch {
        // Storage unavailable (private mode): progress lives for this session only.
      }
      return next
    })
  }, [])

  const record = useCallback(
    (id: string, ok: boolean) =>
      update((p) => {
        const s = p.stats[id] ?? { ok: 0, ko: 0, last: ok }
        const today = localDay(new Date())
        const daily = { ...p.daily, [today]: (p.daily[today] ?? 0) + 1 }
        return { ...p, daily, stats: { ...p.stats, [id]: { ok: s.ok + +ok, ko: s.ko + +!ok, last: ok } } }
      }),
    [update],
  )

  const toggleFavorite = useCallback(
    (id: string) =>
      update((p) => ({ ...p, favorites: p.favorites.includes(id) ? p.favorites.filter((f) => f !== id) : [...p.favorites, id] })),
    [update],
  )

  const addExam = useCallback(
    (exam: ExamRecord) =>
      update((p) => {
        const exams = [...p.exams, exam]
        // Older exams keep their score only, so the saved progress stays small.
        return { ...p, exams: exams.map((e, i) => (i < exams.length - REVIEWABLE_EXAMS ? { date: e.date, errors: e.errors, license: e.license } : e)) }
      }),
    [update],
  )

  return { progress, update, record, toggleFavorite, addExam }
}
