// The rules of the sync server, kept apart from Vercel so that they can be tested: where each learner's progress is kept
// (under the SHA-256 of their sync code) and who may have a code e-mailed. `kv` is any store with async get(key) → string|null
// and set(key, string).
export const MAX_BYTES = 300_000
const HOUR = 3_600_000

export const validId = (id) => typeof id === 'string' && /^[0-9a-f]{64}$/.test(id)

/** Reads, writes or asks to e-mail the progress saved under `id`. Returns the HTTP status and the body to send. */
export async function handleSync(kv, { method, id, action, body, env = {}, now = Date.now() }) {
  if (!validId(id)) return { status: 404, body: 'Not found' }

  if (action === 'mail') {
    if (method !== 'POST') return { status: 405, body: 'Method not allowed' }
    return { status: await mailPermission(kv, id, env, now) }
  }

  if (method === 'GET') {
    const saved = await kv.get(`p/${id}.json`)
    return saved === null ? { status: 404, json: '{}' } : { status: 200, json: saved }
  }

  if (method === 'PUT') {
    const text = typeof body === 'string' ? body : JSON.stringify(body ?? null)
    if (text.length > MAX_BYTES) return { status: 413, body: 'Too large' }
    let data
    try {
      data = JSON.parse(text)
    } catch {
      return { status: 400, body: 'Invalid JSON' }
    }
    if (!data || typeof data !== 'object' || data.v !== 1) return { status: 400, body: 'Unknown format' }
    await kv.set(`p/${id}.json`, text)
    return { status: 204 }
  }

  return { status: 405, body: 'Method not allowed' }
}

/** Permission to e-mail a code: only a code in use, once an hour, and a limited number a day for everyone. */
export async function mailPermission(kv, id, env = {}, now = Date.now()) {
  if ((await kv.get(`p/${id}.json`)) === null) return 404
  const last = Number(await kv.get(`mail/${id}.json`))
  if (last && now - last < HOUR) return 429
  const day = `mailday/${new Date(now).toISOString().slice(0, 10)}.json`
  const sent = Number((await kv.get(day)) ?? 0)
  if (sent >= Number(env.DAILY_MAIL_LIMIT ?? 100)) return 429
  await kv.set(`mail/${id}.json`, String(now))
  await kv.set(day, String(sent + 1))
  return 200
}
