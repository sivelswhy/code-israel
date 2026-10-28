// Run with: node --test mail/send-code.test.mjs   (nodemailer must be installed: cd mail && npm install)
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { test } from 'node:test'
import { createHandler } from './api/send-code.js'

const code = 'ABCD-EFGH-JKMN-PQRS'
const id = createHash('sha256').update('code-israel:ABCDEFGHJKMNPQRS').digest('hex')
const env = { ALLOWED_RECIPIENTS: 'moi@exemple.fr', SMTP_USER: 'robot@exemple.fr' }

function run(handler, { method = 'POST', body, headers = {} } = {}) {
  const out = { status: 200, headers: {}, json: null }
  const res = {
    status(s) { out.status = s; return res },
    setHeader(k, v) { out.headers[k] = v },
    json(j) { out.json = j; return res },
    end() { return res },
  }
  return handler({ method, body, headers }, res).then(() => out)
}

// The store of the sync server: it knows one code.
const memory = () => {
  const m = new Map([[`p/${id}.json`, '{"v":1}']])
  return { get: async (k) => m.get(k) ?? null, set: async (k, v) => void m.set(k, v) }
}
test('mails a code that exists, to an allowed address, once', async () => {
  const sent = []
  const handler = createHandler({ env, kv: memory(), transport: { sendMail: async (m) => sent.push(m) } })
  const r = await run(handler, { body: { email: 'Moi@exemple.fr', code } })
  assert.equal(r.status, 200)
  assert.equal(sent.length, 1)
  assert.equal(sent[0].to, 'Moi@exemple.fr')
  assert.equal(sent[0].from, 'robot@exemple.fr')
  assert.ok(sent[0].text.includes(code))
  assert.equal((await run(handler, { body: { email: 'moi@exemple.fr', code } })).status, 429, 'a second e-mail within the hour is refused')
  assert.equal(sent.length, 1)
})

test('anyone may receive their own code when the function is open', async () => {
  const sent = []
  const open = createHandler({ env: { ...env, ALLOWED_RECIPIENTS: '*' }, kv: memory(), transport: { sendMail: async (m) => sent.push(m) } })
  assert.equal((await run(open, { body: { email: 'quelquun@autre.org', code } })).status, 200)
  assert.equal(sent[0].to, 'quelquun@autre.org')
})

test('refuses what it should', async () => {
  const sent = []
  const handler = createHandler({ env, kv: memory(), transport: { sendMail: async (m) => sent.push(m) } })
  assert.equal((await run(handler, { body: { email: 'autre@exemple.fr', code } })).status, 403, 'address not allowed')
  assert.equal((await run(handler, { body: { email: 'moi@exemple.fr', code: 'ZZZZ-ZZZZ-ZZZZ-ZZZZ' } })).status, 404, 'unknown code')
  assert.equal((await run(handler, { body: { email: 'moi@exemple.fr', code: 'nope' } })).status, 400)
  assert.equal((await run(handler, { body: { email: 'moi@exemple.fr\nBcc: x@y.z', code } })).status, 400, 'no header injection')
  assert.equal((await run(handler, { method: 'GET' })).status, 405)
  assert.equal((await run(handler, { body: { email: 'moi@exemple.fr', code }, headers: { origin: 'https://evil.example' } })).status, 403)
  assert.equal((await run(createHandler({ env: { ...env, ALLOWED_RECIPIENTS: '' }, kv: memory(), transport: { sendMail: async () => {} } }), { body: { email: 'moi@exemple.fr', code } })).status, 503, 'not configured')
  assert.equal(sent.length, 0, 'nothing was sent')
})

test('the site may call it, and a failing mail account is reported', async () => {
  const ok = createHandler({ env, kv: memory(), transport: { sendMail: async () => {} } })
  const r = await run(ok, { body: { email: 'moi@exemple.fr', code }, headers: { origin: 'https://sivelswhy.github.io' } })
  assert.equal(r.status, 200)
  assert.equal(r.headers['access-control-allow-origin'], 'https://sivelswhy.github.io')
  const broken = createHandler({ env, kv: memory(), transport: { sendMail: async () => { throw new Error('auth') } } })
  assert.equal((await run(broken, { body: { email: 'moi@exemple.fr', code } })).status, 502)
})
