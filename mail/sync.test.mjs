// Run with: node --test mail/sync.test.mjs   (from the repository root, after `cd mail && npm install`)
import assert from 'node:assert/strict'
import { test } from 'node:test'
import { createHandler } from './api/p.js'

function memory() {
  const m = new Map()
  return { map: m, get: async (k) => m.get(k) ?? null, set: async (k, v) => void m.set(k, v) }
}
const id = 'a'.repeat(64)

function run(handler, { method = 'GET', id: key = id, action, body } = {}) {
  const out = { status: 200, headers: {}, body: undefined }
  const res = {
    setHeader(k, v) { out.headers[k.toLowerCase()] = v },
    status(s) { out.status = s; return res },
    send(b) { out.body = b; return res },
    end() { return res },
  }
  return handler({ method, query: { id: key, action }, body }, res).then(() => out)
}

test('keeps and returns the progress of one code', async () => {
  const h = createHandler({ kv: memory() })
  assert.equal((await run(h)).status, 404)
  assert.equal((await run(h, { method: 'PUT', body: JSON.stringify({ v: 1, modified: 1 }) })).status, 204)
  const got = await run(h)
  assert.equal(got.status, 200)
  assert.deepEqual(JSON.parse(got.body), { v: 1, modified: 1 })
  assert.equal(got.headers['access-control-allow-origin'], '*')
  assert.equal(got.headers['cache-control'], 'no-store', 'never a stale copy')
  // Vercel hands over an already parsed JSON body.
  assert.equal((await run(h, { method: 'PUT', body: { v: 1, modified: 2 } })).status, 204)
  assert.equal(JSON.parse((await run(h)).body).modified, 2)
})

test('refuses what it should', async () => {
  const h = createHandler({ kv: memory() })
  assert.equal((await run(h, { id: 'not-a-hash' })).status, 404)
  assert.equal((await run(h, { method: 'PUT', body: 'nope' })).status, 400)
  assert.equal((await run(h, { method: 'PUT', body: '{"v":2}' })).status, 400)
  assert.equal((await run(h, { method: 'PUT', body: JSON.stringify({ v: 1, pad: 'x'.repeat(300_001) }) })).status, 413)
  assert.equal((await run(h, { method: 'DELETE' })).status, 405)
  assert.equal((await run(h, { method: 'OPTIONS' })).status, 204)
})

test('different codes never see each other', async () => {
  const h = createHandler({ kv: memory() })
  await run(h, { method: 'PUT', id: 'b'.repeat(64), body: JSON.stringify({ v: 1, who: 'other' }) })
  assert.equal((await run(h)).status, 404)
})

test('allows one e-mail an hour for a code in use, and a daily limit', async () => {
  const kv = memory()
  const h = createHandler({ kv, env: { DAILY_MAIL_LIMIT: '2' } })
  assert.equal((await run(h, { method: 'POST', action: 'mail' })).status, 404, 'unknown code')
  assert.equal((await run(h, { action: 'mail' })).status, 405)
  await run(h, { method: 'PUT', body: JSON.stringify({ v: 1 }) })
  assert.equal((await run(h, { method: 'POST', action: 'mail' })).status, 200)
  assert.equal((await run(h, { method: 'POST', action: 'mail' })).status, 429, 'once an hour')
  for (const other of ['c', 'd']) await run(h, { method: 'PUT', id: other.repeat(64), body: JSON.stringify({ v: 1 }) })
  assert.equal((await run(h, { method: 'POST', id: 'c'.repeat(64), action: 'mail' })).status, 200)
  assert.equal((await run(h, { method: 'POST', id: 'd'.repeat(64), action: 'mail' })).status, 429, 'daily limit reached')
})
