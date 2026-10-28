// Run with: npm run test:journey
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { test } from 'node:test'
import * as p from './readiness.ts'
import type { Question } from './data.ts'

const pool: Question[] = JSON.parse(readFileSync(new URL('../public/data/questions.fr.json', import.meta.url), 'utf8')).filter((q: Question) => q.lic.includes('B'))
const near = (a: number, b: number, eps = 1e-9) => assert.ok(Math.abs(a - b) < eps, `${a} ≠ ${b}`)

test('pass probability is exact', () => {
  near(p.passProbability(new Array(30).fill(1)), 1)
  near(p.passProbability(new Array(30).fill(0)), 0)
  near(p.passProbability([0.5, 0.5, 0.5], 1), 0.5)
  assert.ok(p.passProbability(new Array(30).fill(0.95)) > 0.9)
  assert.ok(p.passProbability(new Array(30).fill(0.8)) < 0.5)
})

test('readiness grows with good answers', () => {
  const fresh = p.readiness(pool, {})
  assert.equal(fresh.enoughData, false)
  assert.ok(fresh.passChance < 0.01)
  const good = Object.fromEntries(pool.map((q) => [q.id, { ok: 4, ko: 0, last: true }]))
  const ready = p.readiness(pool, good)
  assert.ok(ready.enoughData && ready.coverage === 1 && ready.passChance > 0.8)
  const bad = Object.fromEntries(pool.map((q) => [q.id, { ok: 0, ko: 3, last: false }]))
  assert.ok(p.readiness(pool, bad).passChance < 0.01)
  const mixed = { ...good, ...Object.fromEntries(pool.filter((q) => q.cat === 'signs').map((q) => [q.id, { ok: 0, ko: 3, last: false }])) }
  assert.equal(p.weakest(p.readiness(pool, mixed))[0].category, 'signs')
})

test('traps, plan and pass streak', () => {
  const ids = pool.slice(0, 5).map((q) => q.id)
  const stats = {
    [ids[0]]: { ok: 1, ko: 3, last: false },
    [ids[1]]: { ok: 5, ko: 2, last: true },
    [ids[2]]: { ok: 0, ko: 1, last: false },
    [ids[3]]: { ok: 3, ko: 1, last: false },
    [ids[4]]: { ok: 9, ko: 0, last: true },
  }
  assert.deepEqual(p.trapIDs(pool, stats), [ids[2], ids[0], ids[1]])
  assert.deepEqual(p.trapIDs(pool, stats, 1), [ids[2]])
  const now = new Date(2026, 9, 28, 9)
  assert.equal(p.plan(undefined, pool, {}, now), null)
  assert.equal(p.plan('bientôt', pool, {}, now), null)
  const plan = p.plan('2026-11-07', pool, {}, now)!
  assert.equal(plan.daysLeft, 10)
  assert.equal(plan.toLearn, pool.length)
  assert.equal(plan.perDay, Math.ceil(pool.length / 9))
  assert.ok(p.plan('2026-10-20', pool, {}, now)!.isPast)
  assert.equal(p.plan('2026-10-29', pool, {}, now)!.perDay, pool.length)
  const exam = (errors: number) => ({ date: 0, errors, license: 'B' as const })
  assert.equal(p.passStreak([]), 0)
  assert.equal(p.passStreak([exam(9), exam(2), exam(4)]), 2)
  assert.equal(p.passStreak([exam(2), exam(5)]), 0)
})
