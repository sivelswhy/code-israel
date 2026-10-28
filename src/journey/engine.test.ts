// Run with: npm run test:journey
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { test } from 'node:test'
import * as j from './engine.ts'
import type { Question } from '../data.ts'

const pool: Question[] = JSON.parse(readFileSync(new URL('../../public/data/questions.fr.json', import.meta.url), 'utf8')).filter((q: Question) => q.lic.includes('B'))
const at = (day: number, hour = 12) => new Date(2026, 9, day, hour)
const play = (ids: string[], answers: boolean[], seconds?: number) => {
  let s = j.newSession(ids)
  for (const a of answers) s = j.submit(s, a, seconds)
  return s
}

test('the path covers every question once, in lessons of the right size', () => {
  const units = j.buildPath(pool)
  const seen = new Set<string>()
  for (const u of units) {
    u.lessons.forEach((l, i) => {
      assert.equal(l.number, i + 1)
      assert.ok(l.questionIDs.length >= j.RULES.minimumLessonSize, l.id)
      assert.ok(l.questionIDs.length < j.RULES.lessonSize + j.RULES.minimumLessonSize, l.id)
      for (const id of l.questionIDs) assert.ok(!seen.has(id) && seen.add(id), `${id} is in two lessons`)
    })
  }
  assert.deepEqual(seen, new Set(pool.map((q) => q.id)))
})

test('wrong questions come back until right', () => {
  let s = j.newSession(['a', 'b', 'c'])
  s = j.submit(s, false)
  assert.deepEqual(s.queue, ['b', 'c', 'a'])
  s = j.submit(j.submit(s, true), true)
  assert.equal(j.isFirstAttempt(s), false)
  s = j.submit(s, false)
  assert.equal(j.isFinished(s), false)
  s = j.submit(s, true)
  assert.ok(j.isFinished(s))
  const o = j.outcome(s)
  assert.equal(o.mistakes, 2)
  assert.equal(o.firstTry, 2)
  assert.equal(o.xp, 2 * j.RULES.xpFirstTry + j.RULES.xpRetry + j.RULES.xpLessonBonus)
  assert.equal(o.stars, 1)
})

test('perfect lesson, stars and speed bonus', () => {
  const ids = ['1', '2', '3', '4']
  const fast = j.outcome(play(ids, [true, true, true, true], 5))
  assert.ok(fast.perfect && fast.speedBonus)
  assert.equal(fast.xp, 4 * j.RULES.xpFirstTry + j.RULES.xpLessonBonus + j.RULES.xpPerfectBonus + j.RULES.xpSpeedBonus)
  assert.equal(j.outcome(play(ids, [true, true, true, true], 30)).speedBonus, false)
  assert.equal(j.outcome(play(ids, [true, true, true, true])).speedBonus, false)
  assert.equal(j.outcome(play(ids, [true, true, true, true], 5), false).speedBonus, false)
  assert.equal(j.outcome(play(ids, [true, true, true, true], 5), false).xp, 4 * j.RULES.xpFirstTry)
  assert.equal(play(ids, [true, true, false, true]).bestRun, 2)
})

test('lessons unlock one after another and turn gold', () => {
  const unit = j.buildPath(pool)[0]
  let p = j.emptyJourney()
  assert.ok(j.isUnlocked(p, unit.lessons[0], unit))
  assert.ok(!j.isUnlocked(p, unit.lessons[1], unit))
  const perfect = j.outcome(play(unit.lessons[0].questionIDs, unit.lessons[0].questionIDs.map(() => true)))
  p = j.finish(p, unit.lessons[0], perfect, true, at(28))
  assert.ok(j.isUnlocked(p, unit.lessons[1], unit))
  assert.ok(!j.isUnlocked(p, unit.lessons[2], unit))
  assert.ok(j.isGold(p, unit.lessons[0]))
  assert.equal(j.xpToday(p, at(28)), perfect.xp)
  assert.equal(j.currentLesson(p, unit), unit.lessons[1])
})

test('memory follows the half-life and mistakes come back sooner', () => {
  let p = j.emptyJourney()
  p = j.finish(p, null, j.outcome(play(['right', 'wrong'], [true, false, true]), false), true, at(28))
  assert.equal(p.review.right.h, 2)
  assert.equal(p.review.wrong.h, 1)
  assert.deepEqual(j.dueQuestionIDs(p, at(28)), [])
  assert.deepEqual(j.dueQuestionIDs(p, at(29)), ['wrong'])
  assert.deepEqual(j.dueQuestionIDs(p, at(30)), ['wrong', 'right'])
  p = j.finish(p, null, j.outcome(play(['right'], [true]), false), true, at(30))
  assert.equal(p.review.right.h, 4)
  assert.ok(!j.dueQuestionIDs(p, at(32)).includes('right'))
  assert.ok(j.dueQuestionIDs(p, at(33)).includes('right'))
  assert.ok(Math.abs(j.recallAfter({ h: 4, last: '' }, 4) - 0.5) < 1e-9)
  assert.ok(j.memoryStrength(p, at(30))! > 0.5)
})

test('streak freeze saves a missed day only when it keeps the streak', () => {
  const daily: Record<string, number> = {}
  for (const d of [24, 25, 26]) daily[j.localDay(at(d))] = 3
  let p = { ...j.emptyJourney(), freezes: 1 }
  assert.equal(j.streakOf(daily, p.frozenDays, at(27)), 3)
  assert.equal(j.streakOf(daily, p.frozenDays, at(28)), 0)
  const used = j.applyStreakFreezes(p, daily, at(28))
  assert.equal(used.used, 1)
  p = used.journey
  assert.equal(p.freezes, 0)
  assert.equal(j.streakOf(daily, p.frozenDays, at(28)), 3)
  daily[j.localDay(at(28))] = 2
  assert.equal(j.streakOf(daily, p.frozenDays, at(28)), 4)
  // Two missed days with a single freeze: lost anyway, the freeze is kept.
  const late = j.applyStreakFreezes({ ...j.emptyJourney(), freezes: 1 }, { [j.localDay(at(20))]: 1 }, at(23))
  assert.equal(late.used, 0)
  assert.equal(late.journey.freezes, 1)
  assert.equal(j.applyStreakFreezes({ ...j.emptyJourney(), freezes: 2 }, {}, at(23)).used, 0)
})

test('quests, chest and the freeze reward', () => {
  let p = j.emptyJourney()
  const day = at(28)
  const quests = j.questsOf(day)
  assert.equal(new Set(quests).size, 3)
  assert.deepEqual(quests, j.questsOf(day))
  assert.equal(j.claim(p, quests[0], day), p, 'not done yet')
  const lesson = j.buildPath(pool)[0].lessons
  const perfect = j.outcome(play(['1', '2', '3', '4', '5', '6', '7', '8'], Array(8).fill(true), 3))
  p = j.finish(p, lesson[0], perfect, true, day)
  p = j.finish(p, lesson[1], perfect, true, day)
  p = j.finish(p, null, j.outcome(play(['a'], [true]), false), true, day)
  for (const q of quests) assert.ok(j.isDone(p, q, day), q)
  const before = p.xp
  for (const q of quests) p = j.claim(p, q, day)
  assert.equal(p.xp, before + 3 * j.RULES.questXP)
  assert.equal(j.claim(p, quests[0], day), p, 'only once')
  const opened = j.openChest(p, day)!
  assert.deepEqual(opened.reward, { xp: j.RULES.chestXP, freeze: false })
  assert.equal(j.openChest(opened.journey, day), null)
  // The third chest also holds a freeze.
  const next = at(29)
  const third = { ...opened.journey, chestsOpened: 2, today: { ...opened.journey.today, day: j.localDay(next), claimed: j.questsOf(next), chestOpened: false } }
  const chest = j.openChest(third, next)!
  assert.ok(chest.reward.freeze)
  assert.equal(chest.journey.freezes, 1)
  assert.equal(j.questProgress(chest.journey, 'lessons', at(30)), 0)
})

test('adaptive training aims at the target success rate', () => {
  let p = j.emptyJourney()
  assert.ok(Math.abs(j.successChance(p, 'x') - 0.5) < 1e-9)
  p = { ...p, ability: 1400, difficulty: { easy: 600, ok: 1000, hard: 1800 } }
  assert.ok(j.successChance(p, 'easy') > 0.95 && j.successChance(p, 'hard') < 0.1)
  assert.deepEqual(j.adaptivePick(p, ['hard', 'easy', 'ok'], 1), ['ok'])
  const k = j.finish(j.emptyJourney(), null, j.outcome(play(['a', 'b'], [true, false]), false), true, at(28))
  assert.ok(k.difficulty.a < 1000 && k.difficulty.b > 1000)
})

test('reminders at the usual hour', () => {
  assert.equal(j.habitualHour({}), 19)
  assert.equal(j.habitualHour({ 8: 2, 21: 5, 19: 5 }), 19)
  assert.equal(j.streakAlert(at(28, 9), false).getDate(), 28)
  assert.equal(j.streakAlert(at(28, 9), false).getHours(), 20)
  assert.equal(j.streakAlert(at(28, 9), true).getDate(), 29)
  assert.equal(j.streakAlert(at(28, 22), false).getDate(), 29)
})

test('exercises', () => {
  assert.deepEqual([0, 1, 2, 3].map((i) => j.exerciseKind(i, true, true)), ['choice', 'trueFalse', 'listening', 'hebrew'])
  assert.equal(j.exerciseKind(3, true, false), 'choice')
  assert.equal(j.exerciseKind(1, false, true), 'choice')
  let trues = 0
  for (const q of pool.slice(0, 200)) {
    const st = j.statement(q)
    assert.equal(st.isTrue, st.answerIndex === q.c)
    const t = j.translations(q, pool)
    assert.equal(t.options[t.correct], q.q)
    assert.equal(new Set(t.options).size, t.options.length)
  }
  for (const q of pool) if (j.statement(q).isTrue) trues++
  assert.ok(trues > pool.length / 3 && trues < (pool.length * 2) / 3)
  const signs = JSON.parse(readFileSync(new URL('../../public/data/signs.json', import.meta.url), 'utf8'))
  const pairs = j.matchPairs(signs, 5, 3)
  assert.equal(pairs.length, 5)
  assert.equal(new Set(pairs.map((s) => s.fr)).size, 5)
})
