// Run with: npm run test:journey
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { codeId, displayCode, fromWire, generateCode, mergeProgress, normalizeCode, toWire } from './sync.ts'
import { emptyJourney } from './journey/engine.ts'
import type { Progress } from './store.ts'

const base = (): Progress => ({ license: 'B', stats: {}, exams: [], favorites: [], daily: {}, journey: emptyJourney() })

test('sync code', async () => {
  const code = generateCode()
  assert.equal(code.length, 19)
  assert.ok(normalizeCode(code))
  assert.equal(normalizeCode(code.toLowerCase().replaceAll('-', ' ')), normalizeCode(code))
  assert.equal(normalizeCode('ABCD-EFGH'), null)
  assert.equal(normalizeCode('0000-0000-0000-0000'), null)
  assert.equal(await codeId(code), await codeId(code.toLowerCase()))
  assert.notEqual(await codeId(code), await codeId(generateCode()))
  // The same fixed value as in the Swift tests: both platforms must agree on the key the server sees.
  assert.equal(await codeId('ABCD-EFGH-JKMN-PQRS'), '2ddf41b94a7dff048cf091f54aacea8e24057d790d2f22a9ac6ddfad75bc0801')
  assert.equal(displayCode('K7QM2XTR9HBD4WCN'), 'K7QM-2XTR-9HBD-4WCN')
})

test('merge brings two devices together', () => {
  const phone: Progress = {
    ...base(), modified: 2000, license: 'A', favorites: ['f1'], examDate: '2026-12-01',
    stats: { q1: { ok: 3, ko: 1, last: true }, q2: { ok: 1, ko: 0, last: true } },
    daily: { '2026-10-27': 5, '2026-10-28': 2 },
  }
  phone.journey = { ...emptyJourney(), lessons: { 'rules-1': { stars: 2, completions: 1 } }, xp: 100, xpByDay: { '2026-10-27': 100 }, review: { q1: { h: 4, last: '2026-10-27' } }, frozenDays: ['2026-10-20'], today: { ...emptyJourney().today, day: '2026-10-28' } }
  const mac: Progress = {
    ...base(), modified: 1000, license: 'B', favorites: ['f2'],
    stats: { q1: { ok: 1, ko: 1, last: false }, q3: { ok: 0, ko: 2, last: false } },
    daily: { '2026-10-27': 9, '2026-10-26': 1 },
  }
  mac.journey = { ...emptyJourney(), lessons: { 'rules-1': { stars: 3, completions: 1 }, 'rules-2': { stars: 1, completions: 1 } }, xp: 60, xpByDay: { '2026-10-26': 60 }, review: { q1: { h: 2, last: '2026-10-26' } }, frozenDays: ['2026-10-21'], today: { ...emptyJourney().today, day: '2026-10-26' } }

  const m = mergeProgress(phone, mac)
  assert.equal(m.license, 'A')
  assert.deepEqual(m.favorites, ['f1'])
  assert.equal(m.examDate, '2026-12-01')
  assert.deepEqual(m.stats.q1, { ok: 3, ko: 1, last: true })
  assert.deepEqual(Object.keys(m.stats).sort(), ['q1', 'q2', 'q3'])
  assert.deepEqual(m.daily, { '2026-10-26': 1, '2026-10-27': 9, '2026-10-28': 2 })
  assert.deepEqual(m.journey.lessons['rules-1'], { stars: 3, completions: 1 })
  assert.ok(m.journey.lessons['rules-2'])
  assert.equal(m.journey.xp, 160)
  assert.equal(m.journey.review.q1.h, 4)
  assert.deepEqual(m.journey.frozenDays, ['2026-10-20', '2026-10-21'])
  assert.equal(m.journey.today.day, '2026-10-28')
  assert.equal(m.modified, 2000)
  const back = mergeProgress(mac, phone)
  assert.deepEqual(back.stats, m.stats)
  assert.deepEqual(back.daily, m.daily)
  assert.equal(back.journey.xp, m.journey.xp)
  assert.equal(back.license, m.license)
  assert.deepEqual(mergeProgress(m, phone).stats, m.stats)
})

test('exams are kept once and the wire format round trips', () => {
  const when = 1_800_000_000_000
  const a: Progress = { ...base(), modified: 5, exams: [{ date: when, errors: 3, license: 'B', ids: ['1', '2'], answers: [0, null] }] }
  const b: Progress = { ...base(), modified: 4, exams: [{ date: when, errors: 3, license: 'B' }, { date: when + 60_000, errors: 7, license: 'B' }] }
  const m = mergeProgress(a, b)
  assert.equal(m.exams.length, 2)
  assert.deepEqual(m.exams[0].ids, ['1', '2'])

  const p: Progress = { ...base(), modified: 1_800_000_123_000, examDate: '2026-12-01', stats: { q: { ok: 2, ko: 1, last: false } }, exams: m.exams }
  p.journey.review.q = { h: 8, last: '2026-10-28' }
  const wire = JSON.parse(JSON.stringify(toWire(p)))
  assert.equal(wire.journey.review.q.halfLife, 8, 'the apps call it halfLife')
  const back = fromWire(wire, base())
  assert.equal(back.modified, p.modified)
  assert.equal(back.journey.review.q.h, 8)
  assert.deepEqual(back.exams, p.exams)
  assert.equal(back.examDate, '2026-12-01')
})
