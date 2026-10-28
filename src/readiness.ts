import { EXAM } from './exam.ts'
import type { Category, Question } from './data'
import type { ExamRecord, Stat } from './store'

/**
 * How ready the learner is for the exam, estimated from their answers. An estimate, never a promise.
 * The same rules as the Mac and iPhone apps.
 */
export const PREP = {
  /** A question never answered: unknown, assumed hard to be on the safe side. */
  unseenChance: 0.35,
  /** Enough of the bank has been seen for the estimate to be meaningful. */
  minimumCoverage: 0.25,
  /** Below this chance, a question still has to be learned. */
  learnedChance: 0.7,
}

export interface ThemeReadiness {
  category: Category
  /** Average chance of answering a question of this theme right, 0...1. */
  chance: number
  seen: number
  total: number
}

export interface Readiness {
  /** Chance of passing a mock exam (at most EXAM.maxErrors mistakes), 0...1. */
  passChance: number
  /** Share of the question bank answered at least once, 0...1. */
  coverage: number
  themes: ThemeReadiness[]
  /** False while too little of the bank has been answered for the estimate to mean much. */
  enoughData: boolean
}

const CATEGORIES: Category[] = ['rules', 'safety', 'signs', 'vehicle']

/** Chance of answering this question right: the answers so far (lightly smoothed), pulled by the last attempt. */
export function chance(stat: Stat | undefined): number {
  if (!stat) return PREP.unseenChance
  const base = (stat.ok + 0.5) / (stat.ok + stat.ko + 1)
  return 0.7 * base + 0.3 * (stat.last ? 0.95 : 0.3)
}

/** Probability of making at most `maxErrors` mistakes, each question having its own chance of being right. */
export function passProbability(chances: number[], maxErrors = EXAM.maxErrors): number {
  // errors[k] = probability of exactly k mistakes so far (capped one above the limit).
  let errors = new Array<number>(maxErrors + 2).fill(0)
  errors[0] = 1
  for (const p of chances) {
    const next = new Array<number>(errors.length).fill(0)
    errors.forEach((prob, k) => {
      if (!prob) return
      next[k] += prob * p
      next[Math.min(k + 1, errors.length - 1)] += prob * (1 - p)
    })
    errors = next
  }
  return errors.slice(0, maxErrors + 1).reduce((a, b) => a + b, 0)
}

/** The exam draws each theme in proportion to the bank: how many questions of each, for `size` in all. */
function examShares(pool: Question[], size: number): [Category, number][] {
  if (!pool.length) return []
  const counts = CATEGORIES.map((c) => [c, pool.filter((q) => q.cat === c).length] as const).filter(([, n]) => n > 0)
  const shares = counts.map(([c, n]) => [c, Math.round((n / pool.length) * size)] as [Category, number])
  // Rounding may leave the total off by a few: the largest theme absorbs the difference.
  const diff = size - shares.reduce((a, [, n]) => a + n, 0)
  if (diff) {
    const biggest = counts.reduce((best, c, i) => (c[1] > counts[best][1] ? i : best), 0)
    shares[biggest][1] += diff
  }
  return shares
}

export function readiness(pool: Question[], stats: Record<string, Stat>): Readiness {
  const themes: ThemeReadiness[] = []
  for (const category of CATEGORIES) {
    const qs = pool.filter((q) => q.cat === category)
    if (!qs.length) continue
    themes.push({ category, chance: qs.reduce((a, q) => a + chance(stats[q.id]), 0) / qs.length, seen: qs.filter((q) => stats[q.id]).length, total: qs.length })
  }
  const byCategory = new Map(themes.map((t) => [t.category, t.chance]))
  const chances = examShares(pool, EXAM.size).flatMap(([c, n]) => new Array<number>(n).fill(byCategory.get(c) ?? PREP.unseenChance))
  const seen = pool.filter((q) => stats[q.id]).length
  const coverage = pool.length ? seen / pool.length : 0
  return { passChance: passProbability(chances), coverage, themes, enoughData: coverage >= PREP.minimumCoverage && seen >= EXAM.size }
}

/** The themes where the learner is the weakest, weakest first. */
export const weakest = (r: Readiness) => [...r.themes].sort((a, b) => a.chance - b.chance || (a.category < b.category ? -1 : 1))

/** The questions of a theme the learner is least likely to answer right. */
export function weakestIn(pool: Question[], stats: Record<string, Stat>, category: Category, count = 20): Question[] {
  return pool
    .filter((q) => q.cat === category)
    .sort((a, b) => chance(stats[a.id]) - chance(stats[b.id]) || (a.id < b.id ? -1 : 1))
    .slice(0, count)
}

/** Questions the learner keeps getting wrong, the worst first: more mistakes than right answers, or at least two mistakes. */
export function trapIDs(pool: Question[], stats: Record<string, Stat>, limit = 20): string[] {
  return pool
    .flatMap((q) => {
      const s = stats[q.id]
      return s && (s.ko >= 2 || (s.ko >= 1 && s.ko > s.ok)) ? [{ id: q.id, rate: s.ko / (s.ok + s.ko), ko: s.ko }] : []
    })
    .sort((a, b) => b.rate - a.rate || b.ko - a.ko || (a.id < b.id ? -1 : 1))
    .slice(0, limit)
    .map((t) => t.id)
}

/** Consecutive mock exams passed, counting back from the latest one (the advice: pass a few in a row before the real exam). */
export function passStreak(exams: ExamRecord[]): number {
  let n = 0
  for (let i = exams.length - 1; i >= 0 && exams[i].errors <= EXAM.maxErrors; i--) n++
  return n
}

export interface ExamPlan {
  daysLeft: number
  /** Questions never seen, plus those answered with a low chance of success. */
  toLearn: number
  /** Questions to work on each day, keeping the last day for a final review. */
  perDay: number
  isPast: boolean
}

/** The days left to the exam and the daily workload. Null when no date is set or it cannot be read. */
export function plan(examDate: string | undefined, pool: Question[], stats: Record<string, Stat>, now = new Date()): ExamPlan | null {
  if (!examDate) return null
  const [y, m, d] = examDate.split('-').map(Number)
  if (!y || !m || !d) return null
  const days = Math.round((new Date(y, m - 1, d).getTime() - new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()) / 86_400_000)
  const toLearn = pool.filter((q) => chance(stats[q.id]) < PREP.learnedChance).length
  return { daysLeft: days, toLearn, perDay: days <= 1 ? toLearn : Math.ceil(toLearn / (days - 1)), isPast: days < 0 }
}
