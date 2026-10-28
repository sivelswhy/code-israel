// Code Israël: tiny free server that keeps each learner's progress under the SHA-256 of their sync code.
// It never sees the code, an e-mail address or a name; the data is kept one year after the last visit.
// Runs on Cloudflare Workers (free plan) with one KV namespace called PROGRESS.
const MAX_BYTES = 300_000
const YEAR = 60 * 60 * 24 * 365

const cors = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, PUT, OPTIONS',
  'access-control-allow-headers': 'content-type',
  'access-control-max-age': '86400',
}

const reply = (body, status = 200, extra = {}) => new Response(body, { status, headers: { ...cors, ...extra } })

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return reply(null, 204)
    const path = new URL(request.url).pathname

    // Permission to e-mail a code: only a code in use, once an hour, and a limited number a day for everyone.
    const mailMatch = path.match(/^\/p\/([0-9a-f]{64})\/mail$/)
    if (mailMatch) {
      if (request.method !== 'POST') return reply('Method not allowed', 405)
      const id = mailMatch[1]
      if ((await env.PROGRESS.get(id)) === null) return reply('Unknown code', 404)
      if ((await env.PROGRESS.get(`mail-${id}`)) !== null) return reply('Already sent', 429)
      const day = `mailday-${new Date().toISOString().slice(0, 10)}`
      const sent = Number((await env.PROGRESS.get(day)) ?? 0)
      if (sent >= Number(env.DAILY_MAIL_LIMIT ?? 100)) return reply('Daily limit reached', 429)
      await env.PROGRESS.put(`mail-${id}`, '1', { expirationTtl: 3600 })
      await env.PROGRESS.put(day, String(sent + 1), { expirationTtl: 2 * 24 * 3600 })
      return reply(null, 200)
    }

    const match = path.match(/^\/p\/([0-9a-f]{64})$/)
    if (!match) return reply('Not found', 404)
    const key = match[1]

    if (request.method === 'GET') {
      const saved = await env.PROGRESS.get(key)
      return saved === null ? reply('{}', 404, { 'content-type': 'application/json' }) : reply(saved, 200, { 'content-type': 'application/json' })
    }

    if (request.method === 'PUT') {
      const text = await request.text()
      if (text.length > MAX_BYTES) return reply('Too large', 413)
      let data
      try {
        data = JSON.parse(text)
      } catch {
        return reply('Invalid JSON', 400)
      }
      if (!data || typeof data !== 'object' || data.v !== 1) return reply('Unknown format', 400)
      await env.PROGRESS.put(key, text, { expirationTtl: YEAR })
      return reply(null, 204)
    }

    return reply('Method not allowed', 405)
  },
}
