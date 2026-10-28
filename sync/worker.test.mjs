// Run with: node --test sync/worker.test.mjs
import assert from 'node:assert/strict'
import { test } from 'node:test'
import worker from './worker.js'

const kv = new Map()
const ttl = []
const env = { PROGRESS: { get: async (k) => kv.get(k) ?? null, put: async (k, v, o) => (kv.set(k, v), ttl.push(o.expirationTtl)) } }
const id = 'a'.repeat(64)
const call = (path, init) => worker.fetch(new Request(`https://sync.test${path}`, init), env)

test('keeps and returns the progress of one code', async () => {
  assert.equal((await call(`/p/${id}`)).status, 404)
  const put = await call(`/p/${id}`, { method: 'PUT', body: JSON.stringify({ v: 1, modified: 1 }) })
  assert.equal(put.status, 204)
  const got = await call(`/p/${id}`)
  assert.equal(got.status, 200)
  assert.deepEqual(await got.json(), { v: 1, modified: 1 })
  assert.equal(got.headers.get('access-control-allow-origin'), '*')
  assert.equal(ttl[0], 31_536_000, 'data is kept one year after the last visit')
})

test('refuses what it should', async () => {
  assert.equal((await call('/p/not-a-hash')).status, 404)
  assert.equal((await call(`/p/${id}`, { method: 'PUT', body: 'nope' })).status, 400)
  assert.equal((await call(`/p/${id}`, { method: 'PUT', body: '{"v":2}' })).status, 400)
  assert.equal((await call(`/p/${id}`, { method: 'PUT', body: JSON.stringify({ v: 1, pad: 'x'.repeat(300_001) }) })).status, 413)
  assert.equal((await call(`/p/${id}`, { method: 'DELETE' })).status, 405)
  assert.equal((await call(`/p/${id}`, { method: 'OPTIONS' })).status, 204)
})

test('allows one e-mail an hour for a code in use, and a daily limit', async () => {
  const mailId = 'c'.repeat(64)
  assert.equal((await call(`/p/${mailId}/mail`, { method: 'POST' })).status, 404, 'unknown code')
  assert.equal((await call(`/p/${mailId}/mail`)).status, 405)
  await call(`/p/${mailId}`, { method: 'PUT', body: JSON.stringify({ v: 1 }) })
  assert.equal((await call(`/p/${mailId}/mail`, { method: 'POST' })).status, 200)
  assert.equal((await call(`/p/${mailId}/mail`, { method: 'POST' })).status, 429, 'once an hour')
  // The cooldown ends after an hour: the key is stored with that lifetime.
  assert.ok(ttl.includes(3600))
  const limited = { PROGRESS: env.PROGRESS, DAILY_MAIL_LIMIT: '1' }
  const other = 'd'.repeat(64)
  await worker.fetch(new Request(`https://sync.test/p/${other}`, { method: 'PUT', body: JSON.stringify({ v: 1 }) }), limited)
  assert.equal((await worker.fetch(new Request(`https://sync.test/p/${other}/mail`, { method: 'POST' }), limited)).status, 429, 'daily limit reached')
})

test('different codes never see each other', async () => {
  const other = 'b'.repeat(64)
  await call(`/p/${other}`, { method: 'PUT', body: JSON.stringify({ v: 1, who: 'other' }) })
  assert.equal((await (await call(`/p/${id}`)).json()).who, undefined)
})
