// Keeps each learner's progress under the SHA-256 of their sync code: GET/PUT /p/<id>, POST /p/<id>/mail (see vercel.json).
// It never sees the code, an e-mail address or a name.
import { handleSync } from '../lib/sync.js'
import { blobKv } from '../lib/blob-kv.js'

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, PUT, POST, OPTIONS',
  'access-control-allow-headers': 'content-type',
  'access-control-max-age': '86400',
}

export function createHandler({ kv = blobKv, env = process.env } = {}) {
  return async function handler(req, res) {
    for (const [k, v] of Object.entries(CORS)) res.setHeader(k, v)
    if (req.method === 'OPTIONS') return res.status(204).end()
    let result
    try {
      result = await handleSync(kv, { method: req.method, id: req.query?.id, action: req.query?.action, body: req.body, env })
    } catch {
      return res.status(503).send('Storage unavailable')
    }
    if (result.json !== undefined) {
      res.setHeader('content-type', 'application/json')
      res.setHeader('cache-control', 'no-store')
      return res.status(result.status).send(result.json)
    }
    return result.body === undefined ? res.status(result.status).end() : res.status(result.status).send(result.body)
  }
}

export default createHandler()
