import { get, put } from '@vercel/blob'

/** The store of the sync server: a private Vercel Blob store (free), reached with the project's own credentials. */
export const blobKv = {
  async get(key) {
    const result = await get(key, { access: 'private', useCache: false })
    if (!result || result.statusCode !== 200 || !result.stream) return null
    return new Response(result.stream).text()
  },
  async set(key, value) {
    await put(key, value, { access: 'private', allowOverwrite: true, addRandomSuffix: false, contentType: 'application/json' })
  },
}
