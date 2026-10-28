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

test('different codes never see each other', async () => {
  const other = 'b'.repeat(64)
  await call(`/p/${other}`, { method: 'PUT', body: JSON.stringify({ v: 1, who: 'other' }) })
  assert.equal((await (await call(`/p/${id}`)).json()).who, undefined)
})
