import type { Category, Question } from '../data'

/**
 * Rules of the Parcours mode: a path of short lessons with XP, stars, spaced repetition (half-life model), daily
 * quests, streak freezes and adaptive difficulty. Pure functions over plain JSON, so the progress is easy to save.
 * The same rules as the Mac and iPhone apps.
 */
export const RULES = {
  lessonSize: 8,
  /** A last lesson shorter than this is merged into the one before it. */
  minimumLessonSize: 4,
  reviewSize: 10,
  xpFirstTry: 10,
  xpRetry: 4,
  xpLessonBonus: 10,
  xpPerfectBonus: 5,
  xpSpeedBonus: 5,
  /** Fast lesson: first answers averaging under this many seconds with at least 70 % right. */
  speedSeconds: 12,
  xpPerLevel: 100,
  dailyXP: 50,
  /** A question starts with a half-life of one day; it doubles at each first-try success and resets after a mistake. */
  startHalfLife: 1,
  maxHalfLife: 180,
  /** A question is due for review once the chance to remember it falls to this value or below. */
  dueRecall: 0.6,
  targetSuccess: 0.8,
  adaptiveSize: 8,
  questXP: 10,
  chestXP: 20,
  chestFreezeEvery: 3,
  maxFreezes: 2,
  matchPairs: 5,
  xpMatch: 15,
}

const CATEGORY_ORDER: Category[] = ['rules', 'safety', 'signs', 'vehicle']

export interface Lesson {
  /** For example `rules-3`. */
  id: string
  category: Category
  /** Position in its unit, from 1. */
  number: number
  questionIDs: string[]
}

export interface JourneyUnit {
  category: Category
  lessons: Lesson[]
}

/** Each theme is a unit of lessons, in the order of the official question bank. */
export function buildPath(pool: Question[]): JourneyUnit[] {
  const units: JourneyUnit[] = []
  for (const category of CATEGORY_ORDER) {
    const ids = pool.filter((q) => q.cat === category).map((q) => q.id).sort(byNumber)
    if (!ids.length) continue
    const chunks: string[][] = []
    for (let i = 0; i < ids.length; i += RULES.lessonSize) chunks.push(ids.slice(i, i + RULES.lessonSize))
    if (chunks.length > 1 && chunks[chunks.length - 1].length < RULES.minimumLessonSize) {
      const last = chunks.pop()!
      chunks[chunks.length - 1].push(...last)
    }
    units.push({ category, lessons: chunks.map((questionIDs, i) => ({ id: `${category}-${i + 1}`, category, number: i + 1, questionIDs })) })
  }
  return units
}

const byNumber = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0)

// ---------------------------------------------------------------------------------------------- Lesson session

export interface Session {
  queue: string[]
  total: number
  firstTry: Record<string, boolean>
  solved: string[]
  mistakes: number
  bestRun: number
  run: number
  firstSeconds: number
  timed: number
}

export interface Outcome {
  xp: number
  stars: number
  firstTry: number
  total: number
  mistakes: number
  perfect: boolean
  firstTryByQuestion: Record<string, boolean>
  speedBonus: boolean
  bestRun: number
  accuracy: number
}

export const newSession = (ids: string[]): Session => ({
  queue: ids, total: ids.length, firstTry: {}, solved: [], mistakes: 0, bestRun: 0, run: 0, firstSeconds: 0, timed: 0,
})

export const isFinished = (s: Session) => s.queue.length === 0
export const isFirstAttempt = (s: Session) => s.queue.length > 0 && s.firstTry[s.queue[0]] === undefined
export const sessionProgress = (s: Session) => (s.total === 0 ? 1 : s.solved.length / s.total)

/** Records the answer to the current question. A wrong one goes to the end and comes back until it is answered right. */
export function submit(s: Session, correct: boolean, seconds?: number): Session {
  const id = s.queue[0]
  if (id === undefined) return s
  const next: Session = { ...s, firstTry: { ...s.firstTry }, queue: s.queue.slice(1) }
  if (next.firstTry[id] === undefined) {
    next.firstTry[id] = correct
    if (seconds !== undefined) {
      next.firstSeconds += seconds
      next.timed += 1
    }
  }
  if (correct) {
    next.solved = [...s.solved, id]
    next.run = s.run + 1
    next.bestRun = Math.max(s.bestRun, next.run)
  } else {
    next.mistakes = s.mistakes + 1
    next.queue.push(id)
    next.run = 0
  }
  return next
}

/** What the lesson earned. `bonus` is false for a review, which has no completion or speed bonus. */
export function outcome(s: Session, bonus = true): Outcome {
  const values = Object.values(s.firstTry)
  const right = values.filter(Boolean).length
  const retried = values.length - right
  const perfect = s.mistakes === 0 && s.total > 0
  const accuracy = s.total === 0 ? 0 : right / s.total
  const stars = accuracy >= 0.9 ? 3 : accuracy >= 0.7 ? 2 : 1
  const speedBonus = bonus && s.timed === s.total && s.total > 0 && accuracy >= 0.7 && s.firstSeconds / s.total <= RULES.speedSeconds
  const xp =
    right * RULES.xpFirstTry + retried * RULES.xpRetry +
    (bonus ? RULES.xpLessonBonus + (perfect ? RULES.xpPerfectBonus : 0) : 0) +
    (speedBonus ? RULES.xpSpeedBonus : 0)
  return { xp, stars, firstTry: right, total: s.total, mistakes: s.mistakes, perfect, firstTryByQuestion: s.firstTry, speedBonus, bestRun: s.bestRun, accuracy }
}

// ---------------------------------------------------------------------------------------------- Progress

export type QuestKind = 'xp' | 'lessons' | 'perfect' | 'run' | 'review'

export const QUESTS: Record<QuestKind, { target: number; title: string }> = {
  xp: { target: 40, title: 'Gagner 40 XP' },
  lessons: { target: 2, title: 'Terminer 2 leçons' },
  perfect: { target: 1, title: 'Réussir une leçon parfaite' },
  run: { target: 5, title: 'Enchaîner 5 bonnes réponses' },
  review: { target: 1, title: 'Faire la révision du jour' },
}
const QUEST_KINDS = Object.keys(QUESTS) as QuestKind[]

export interface DayCounters {
  day: string
  lessons: number
  perfect: number
  reviews: number
  bestRun: number
  claimed: QuestKind[]
  chestOpened: boolean
}

export interface ReviewState {
  /** Memory half-life in days. */
  h: number
  /** Day of the last answer, YYYY-MM-DD. */
  last: string
}

export interface JourneyProgress {
  lessons: Record<string, { stars: number; completions: number }>
  xp: number
  xpByDay: Record<string, number>
  review: Record<string, ReviewState>
  freezes: number
  frozenDays: string[]
  today: DayCounters
  chestsOpened: number
  /** Adaptive difficulty (Elo): the learner's ability and each question's difficulty, both starting at 1000. */
  ability: number
  difficulty: Record<string, number>
  /** Lessons finished at each hour of the day, to remind at the usual time. */
  hours: Record<string, number>
}

const emptyDay = (day = ''): DayCounters => ({ day, lessons: 0, perfect: 0, reviews: 0, bestRun: 0, claimed: [], chestOpened: false })

export const emptyJourney = (): JourneyProgress => ({
  lessons: {}, xp: 0, xpByDay: {}, review: {}, freezes: 0, frozenDays: [], today: emptyDay(), chestsOpened: 0, ability: 1000, difficulty: {}, hours: {},
})

/** Fills in what an older save does not have. */
export const loadJourney = (saved: Partial<JourneyProgress> | undefined): JourneyProgress => ({ ...emptyJourney(), ...saved })

export function localDay(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

const addDays = (d: Date, n: number) => {
  const r = new Date(d)
  r.setDate(r.getDate() + n)
  return r
}

/** Whole days from a YYYY-MM-DD day to a date. */
function daysBetween(day: string, to: Date) {
  const [y, m, d] = day.split('-').map(Number)
  if (!y) return 0
  const start = new Date(y, m - 1, d)
  const end = new Date(to.getFullYear(), to.getMonth(), to.getDate())
  return Math.round((end.getTime() - start.getTime()) / 86_400_000)
}

export const level = (j: JourneyProgress) => Math.floor(j.xp / RULES.xpPerLevel) + 1
export const xpInLevel = (j: JourneyProgress) => j.xp % RULES.xpPerLevel
export const xpToday = (j: JourneyProgress, now = new Date()) => j.xpByDay[localDay(now)] ?? 0

export const isComplete = (j: JourneyProgress, l: Lesson) => j.lessons[l.id] !== undefined
export const isGold = (j: JourneyProgress, l: Lesson) => (j.lessons[l.id]?.stars ?? 0) >= 3

/** A lesson opens once the one before it in its unit is done. */
export const isUnlocked = (j: JourneyProgress, l: Lesson, unit: JourneyUnit) =>
  l.number === 1 || (unit.lessons[l.number - 2] !== undefined && isComplete(j, unit.lessons[l.number - 2]))

export const currentLesson = (j: JourneyProgress, unit: JourneyUnit) => unit.lessons.find((l) => !isComplete(j, l))
export const completedCount = (j: JourneyProgress, unit: JourneyUnit) => unit.lessons.filter((l) => isComplete(j, l)).length

// ------------------------------------------------------------------------- Memory (half-life regression, simplified)

/** Chance to remember a question `days` days after the last answer: 2^(-days / halfLife). */
export const recallAfter = (state: ReviewState, days: number) => 2 ** (-Math.max(0, days) / state.h)

export function recall(j: JourneyProgress, id: string, now = new Date()): number | null {
  const s = j.review[id]
  return s ? recallAfter(s, daysBetween(s.last, now)) : null
}

/** Average chance to remember the questions reviewed so far (null before the first review). */
export function memoryStrength(j: JourneyProgress, now = new Date()): number | null {
  const values = Object.keys(j.review).map((id) => recall(j, id, now)!)
  return values.length ? values.reduce((a, b) => a + b, 0) / values.length : null
}

/** Questions to review today (the chance to remember them fell to the threshold), the most forgotten first. */
export function dueQuestionIDs(j: JourneyProgress, now = new Date()): string[] {
  return Object.entries(j.review)
    .map(([id, s]) => [id, recallAfter(s, daysBetween(s.last, now))] as const)
    .filter(([, p]) => p <= RULES.dueRecall)
    .sort((a, b) => a[1] - b[1] || byNumber(a[0], b[0]))
    .map(([id]) => id)
}

// ------------------------------------------------------------------------------------ Adaptive difficulty (Elo)

/** Chance that the learner answers this question right. */
export const successChance = (j: JourneyProgress, id: string) => 1 / (1 + 10 ** (((j.difficulty[id] ?? 1000) - j.ability) / 400))

const salt = (text: string) => [...text].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % 9973, 7)

/** The questions whose chance of success is closest to the target; the rest of the ties is shuffled by the day. */
export function adaptivePick(j: JourneyProgress, ids: string[], count = RULES.adaptiveSize, now = new Date()): string[] {
  const day = localDay(now)
  const score = (id: string) => Math.abs(successChance(j, id) - RULES.targetSuccess) + (j.review[id] ? 0.03 : 0)
  return ids
    .map((id) => ({ id, score: score(id), salt: salt(day + id) }))
    .sort((a, b) => a.score - b.score || a.salt - b.salt || byNumber(a.id, b.id))
    .slice(0, count)
    .map((x) => x.id)
}

// ------------------------------------------------------------------------------------------------------- Quests

/** Three quests a day, always the same for a given day. */
export function questsOf(now = new Date()): QuestKind[] {
  let s = [...localDay(now)].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % 100_003, 0)
  const kinds = [...QUEST_KINDS]
  const picked: QuestKind[] = []
  while (picked.length < 3) {
    picked.push(kinds.splice(s % kinds.length, 1)[0])
    s = Math.floor(s / 3) + 1
  }
  return picked
}

const countersOf = (j: JourneyProgress, now: Date): DayCounters => (j.today.day === localDay(now) ? j.today : emptyDay(localDay(now)))

export function questProgress(j: JourneyProgress, quest: QuestKind, now = new Date()): number {
  const c = countersOf(j, now)
  const value = { xp: xpToday(j, now), lessons: c.lessons, perfect: c.perfect, run: c.bestRun, review: c.reviews }[quest]
  return Math.min(QUESTS[quest].target, value)
}

export const isDone = (j: JourneyProgress, quest: QuestKind, now = new Date()) => questProgress(j, quest, now) >= QUESTS[quest].target
export const isClaimed = (j: JourneyProgress, quest: QuestKind, now = new Date()) => countersOf(j, now).claimed.includes(quest)

export function addXP(j: JourneyProgress, amount: number, now = new Date()): JourneyProgress {
  const day = localDay(now)
  return { ...j, xp: j.xp + amount, xpByDay: { ...j.xpByDay, [day]: (j.xpByDay[day] ?? 0) + amount } }
}

/** Collects the XP of a finished quest (unchanged when it is not done or already collected). */
export function claim(j: JourneyProgress, quest: QuestKind, now = new Date()): JourneyProgress {
  if (!questsOf(now).includes(quest) || !isDone(j, quest, now) || isClaimed(j, quest, now)) return j
  const c = countersOf(j, now)
  return addXP({ ...j, today: { ...c, claimed: [...c.claimed, quest] } }, RULES.questXP, now)
}

/** The chest opens once the three quests are collected, once a day. */
export function canOpenChest(j: JourneyProgress, now = new Date()) {
  const c = countersOf(j, now)
  return !c.chestOpened && questsOf(now).every((q) => c.claimed.includes(q))
}

export interface ChestReward {
  xp: number
  freeze: boolean
}

export function openChest(j: JourneyProgress, now = new Date()): { journey: JourneyProgress; reward: ChestReward } | null {
  if (!canOpenChest(j, now)) return null
  const chestsOpened = j.chestsOpened + 1
  const freeze = chestsOpened % RULES.chestFreezeEvery === 0 && j.freezes < RULES.maxFreezes
  const journey = addXP({ ...j, today: { ...countersOf(j, now), chestOpened: true }, chestsOpened, freezes: j.freezes + (freeze ? 1 : 0) }, RULES.chestXP, now)
  return { journey, reward: { xp: RULES.chestXP, freeze } }
}

// -------------------------------------------------------------------------------------------------- Recording

/**
 * Records a finished lesson (or review when `lesson` is null): XP, stars, quests, memory and difficulty.
 * `countsAsReview` is false for a free training, which belongs to no lesson but is not the daily review.
 */
export function finish(j: JourneyProgress, lesson: Lesson | null, result: Outcome, countsAsReview = true, now = new Date()): JourneyProgress {
  let next = addXP(j, result.xp, now)
  const c = { ...countersOf(next, now) }
  const lessons = { ...next.lessons }
  if (lesson) {
    const old = lessons[lesson.id] ?? { stars: 0, completions: 0 }
    lessons[lesson.id] = { stars: Math.max(old.stars, result.stars), completions: old.completions + 1 }
    c.lessons += 1
    if (result.perfect) c.perfect += 1
  } else if (countsAsReview) {
    c.reviews += 1
  }
  c.bestRun = Math.max(c.bestRun, result.bestRun)
  const hour = String(now.getHours())
  next = { ...next, lessons, today: c, hours: { ...next.hours, [hour]: (next.hours[hour] ?? 0) + 1 }, review: { ...next.review }, difficulty: { ...next.difficulty } }

  const day = localDay(now)
  for (const [id, right] of Object.entries(result.firstTryByQuestion)) {
    // Half-life regression, simplified: right at the first try doubles the half-life, a mistake resets it.
    const h = next.review[id]?.h ?? RULES.startHalfLife
    next.review[id] = { h: right ? Math.min(h * 2, RULES.maxHalfLife) : RULES.startHalfLife, last: day }
    // Elo update: a surprise moves the ratings more than an expected result.
    const delta = 24 * ((right ? 1 : 0) - successChance(next, id))
    next.ability += delta
    next.difficulty[id] = (next.difficulty[id] ?? 1000) - delta
  }
  return next
}

// ----------------------------------------------------------------------------------------------- Streak freezes

/** A day counts for the streak when something was practiced or a freeze saved it. */
const covered = (day: string, daily: Record<string, number>, frozen: Set<string>) => daily[day] !== undefined || frozen.has(day)

/** Consecutive days of practice ending today (or yesterday). A day saved by a freeze keeps the streak without adding to it. */
export function streakOf(daily: Record<string, number>, frozenDays: string[] = [], now = new Date()) {
  const frozen = new Set(frozenDays)
  let d = now
  if (!covered(localDay(d), daily, frozen)) d = addDays(d, -1)
  let n = 0
  while (covered(localDay(d), daily, frozen)) {
    if (daily[localDay(d)] !== undefined) n++
    d = addDays(d, -1)
  }
  return n
}

/**
 * Spends streak freezes on the days missed since the last practice, but only when there are enough of them to keep the
 * streak alive (at most three days).
 */
export function applyStreakFreezes(j: JourneyProgress, daily: Record<string, number>, now = new Date()): { journey: JourneyProgress; used: number } {
  const none = { journey: j, used: 0 }
  if (j.freezes <= 0) return none
  const frozen = new Set(j.frozenDays)
  if (covered(localDay(now), daily, frozen)) return none
  const missed: string[] = []
  let d = addDays(now, -1)
  while (!covered(localDay(d), daily, frozen) && missed.length < 3) {
    missed.push(localDay(d))
    d = addDays(d, -1)
  }
  if (!covered(localDay(d), daily, frozen) || !missed.length || missed.length > j.freezes) return none
  return { journey: { ...j, freezes: j.freezes - missed.length, frozenDays: [...j.frozenDays, ...missed] }, used: missed.length }
}

// ----------------------------------------------------------------------------------------------------- Reminders

export const REMINDER = { streakHour: 20, streakMinute: 30, defaultHour: 19 }

/** The hour at which the learner usually finishes lessons (the most frequent one, the earliest on a tie). */
export function habitualHour(hours: Record<string, number>): number {
  const entries = Object.entries(hours).map(([h, n]) => [Number(h), n] as const)
  if (!entries.length) return REMINDER.defaultHour
  return entries.sort((a, b) => b[1] - a[1] || a[0] - b[0])[0][0]
}

/** When to warn that the streak is at risk: tonight if nothing was done today, otherwise tomorrow night. */
export function streakAlert(now: Date, practicedToday: boolean): Date {
  const tonight = new Date(now)
  tonight.setHours(REMINDER.streakHour, REMINDER.streakMinute, 0, 0)
  return !practicedToday && tonight > now ? tonight : addDays(tonight, 1)
}

// ------------------------------------------------------------------------------------------------------ Exercises

export type ExerciseKind = 'choice' | 'trueFalse' | 'hebrew'

/** The kind of exercise for the question at `position` of a lesson; a question that comes back is always a plain choice. */
export function exerciseKind(position: number, firstAttempt: boolean, hasHebrew: boolean): ExerciseKind {
  if (!firstAttempt) return 'choice'
  switch (position % 4) {
    case 1: return 'trueFalse'
    case 3: return hasHebrew ? 'hebrew' : 'choice'
    default: return 'choice'
  }
}

const hash = (text: string, seed: number, mod: number) => [...text].reduce((h, c) => (h * 31 + c.charCodeAt(0)) % mod, seed)

/** For a true/false exercise: the answer shown and whether the statement is true. The same question always shows the same one. */
export function statement(q: Question): { answerIndex: number; isTrue: boolean } {
  const h = hash(q.id, 5, 10_007)
  if (h % 2 === 0 || q.a.length < 2) return { answerIndex: q.c, isTrue: true }
  const wrong = q.a.map((_, i) => i).filter((i) => i !== q.c)
  return { answerIndex: wrong[h % wrong.length], isTrue: false }
}

/** For a Hebrew exercise: four French wordings (the right one and three from the same theme), in a fixed order. */
export function translations(q: Question, pool: Question[]): { options: string[]; correct: number } {
  const s = (t: string) => hash(t, 3, 10_007)
  const others = pool
    .filter((x) => x.id !== q.id && x.cat === q.cat && x.q !== q.q && Math.abs(x.q.length - q.q.length) < Math.max(40, q.q.length))
    .sort((a, b) => s(q.id + a.id) - s(q.id + b.id) || byNumber(a.id, b.id))
  // Several questions share the same wording (they differ by their picture): keep each text once.
  const seen = new Set([q.q])
  const distractors: string[] = []
  for (const o of others) if (!seen.has(o.q)) { seen.add(o.q); distractors.push(o.q) }
  const options = [...distractors.slice(0, 3), q.q].sort((a, b) => s(q.id + a) - s(q.id + b) || byNumber(a, b))
  return { options, correct: options.indexOf(q.q) }
}

export interface SignLike {
  cat: string
  fr: string
  img?: string
}

/** Pairs for the sign matching game: signs of one family, with distinct meanings. */
export function matchPairs<T extends SignLike>(signs: Record<string, T>, count = RULES.matchPairs, seed = 0): (T & { n: string })[] {
  const usable = Object.entries(signs).filter(([, s]) => s.img).map(([n, s]) => ({ ...s, n }))
  const families = new Map<string, (T & { n: string })[]>()
  for (const s of usable) families.set(s.cat, [...(families.get(s.cat) ?? []), s])
  const names = [...families.keys()].filter((k) => families.get(k)!.length >= count).sort()
  if (!names.length) return []
  const seen = new Set<string>()
  const sorted = families.get(names[seed % names.length])!.sort((a, b) => byNumber(a.n, b.n)).filter((s) => !seen.has(s.fr) && seen.add(s.fr))
  if (sorted.length < count) return []
  const start = Math.floor(seed / 7) % (sorted.length - count + 1)
  return sorted.slice(start, start + count)
}
