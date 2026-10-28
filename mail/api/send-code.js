// Sends the sync code to the learner by e-mail. The SMTP credentials live only in the environment variables of the
// Vercel project; nothing secret is in this repository.
//
// Environment variables:
//   SMTP_HOST, SMTP_PORT (465 for SSL, 587 otherwise), SMTP_USER, SMTP_PASS   the mail account that sends
//   MAIL_FROM            the sender shown, e.g. "Code Israël <moi@exemple.fr>" (defaults to SMTP_USER)
//   ALLOWED_RECIPIENTS   comma-separated addresses that may receive a code, e.g. "moi@exemple.fr", or "*" for anyone
//   SYNC_URL             address of the sync server: it allows or refuses each e-mail (code in use, once an hour, daily limit)
//   ALLOWED_ORIGIN       the site allowed to call this function from a browser (default https://sivelswhy.github.io)
import { createHash } from 'node:crypto'
import nodemailer from 'nodemailer'

const ALPHABET = 'ABCDEFGHJKMNPQRSTVWXYZ23456789'
const SITE = 'https://sivelswhy.github.io/code-israel/'

const normalize = (text) => {
  const raw = String(text ?? '').toUpperCase().replace(/[^A-Z0-9]/g, '')
  return raw.length === 16 && [...raw].every((c) => ALPHABET.includes(c)) ? raw : null
}
const display = (raw) => raw.match(/.{4}/g).join('-')
const emailOk = (e) => typeof e === 'string' && e.length <= 254 && /^[^\s@<>,;"']+@[^\s@<>,;"']+\.[^\s@<>,;"']+$/.test(e)

export function createHandler({ env = process.env, transport, fetchImpl = fetch } = {}) {
  return async function handler(req, res) {
    const origin = req.headers?.origin
    const allowedOrigin = env.ALLOWED_ORIGIN || 'https://sivelswhy.github.io'
    // A browser may only call this from the site; the apps send no Origin header.
    if (origin && origin !== allowedOrigin) return res.status(403).json({ error: 'Origine refusée.' })
    if (origin) {
      res.setHeader('access-control-allow-origin', origin)
      res.setHeader('access-control-allow-headers', 'content-type')
      res.setHeader('access-control-allow-methods', 'POST, OPTIONS')
    }
    if (req.method === 'OPTIONS') return res.status(204).end()
    if (req.method !== 'POST') return res.status(405).json({ error: 'Méthode non autorisée.' })

    const { email, code } = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body ?? {}
    const raw = normalize(code)
    if (!emailOk(email)) return res.status(400).json({ error: 'Adresse e-mail invalide.' })
    if (!raw) return res.status(400).json({ error: 'Code invalide.' })

    const allowed = (env.ALLOWED_RECIPIENTS || '').split(',').map((a) => a.trim().toLowerCase()).filter(Boolean)
    if (!allowed.length) return res.status(503).json({ error: 'Envoi par e-mail non configuré.' })
    if (!allowed.includes('*') && !allowed.includes(email.toLowerCase())) return res.status(403).json({ error: 'Cette adresse n’est pas autorisée.' })

    // The sync server decides whether this code may be mailed: it must be in use (so nothing else can be sent to
    // anyone), at most once an hour, and within a daily limit for everyone.
    if (!env.SYNC_URL) return res.status(503).json({ error: 'Serveur de synchronisation non configuré.' })
    const id = createHash('sha256').update(`code-israel:${raw}`).digest('hex')
    const permission = await fetchImpl(`${env.SYNC_URL.replace(/\/$/, '')}/p/${id}/mail`, { method: 'POST' }).then((r) => r.status, () => 0)
    if (permission === 404) return res.status(404).json({ error: 'Ce code n’est pas encore synchronisé : touchez « Synchroniser maintenant » puis réessayez.' })
    if (permission === 429) return res.status(429).json({ error: 'Un e-mail a déjà été envoyé pour ce code il y a peu (ou la limite du jour est atteinte). Réessayez dans une heure.' })
    if (permission !== 200) return res.status(502).json({ error: 'Serveur de synchronisation injoignable.' })

    const mailer = transport ?? nodemailer.createTransport({
      host: env.SMTP_HOST,
      port: Number(env.SMTP_PORT || 465),
      secure: Number(env.SMTP_PORT || 465) === 465,
      auth: { user: env.SMTP_USER, pass: env.SMTP_PASS },
    })
    const shown = display(raw)
    try {
      await mailer.sendMail({
        from: env.MAIL_FROM || env.SMTP_USER,
        to: email,
        subject: 'Votre code de synchronisation Code Israël',
        text: `Votre code de synchronisation Code Israël :\n\n${shown}\n\nPour retrouver votre progression sur un autre appareil : ouvrez l’app ou le site (${SITE}), allez dans Guide, puis « Synchroniser mes appareils » ou « J’ai déjà un code », et saisissez ce code.\n\nGardez-le secret : celui qui le connaît peut lire et modifier votre progression.`,
      })
    } catch {
      return res.status(502).json({ error: 'L’e-mail n’a pas pu être envoyé. Réessayez plus tard.' })
    }
    return res.status(200).json({ ok: true })
  }
}

export default createHandler()
