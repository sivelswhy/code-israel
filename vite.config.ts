import { createHash } from 'node:crypto'
import { readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs'
import { join, relative, resolve } from 'node:path'
import react from '@vitejs/plugin-react'
import { defineConfig, type Plugin } from 'vite'

/** Files above this size (the AI engine) are cached when first used instead of at install. */
const PRECACHE_LIMIT = 3_000_000

/** Lists the built files in dist/sw.js so the app can be opened offline after the first visit. */
function offlineCache(): Plugin {
  let out = 'dist'
  return {
    name: 'offline-cache',
    apply: 'build',
    configResolved: (config) => {
      out = resolve(config.root, config.build.outDir)
    },
    closeBundle() {
      const files: string[] = []
      const walk = (dir: string) => {
        for (const name of readdirSync(dir)) {
          const path = join(dir, name)
          if (statSync(path).isDirectory()) walk(path)
          else files.push(path)
        }
      }
      walk(out)
      const urls = files
        .filter((f) => f !== join(out, 'sw.js') && !f.split('/').pop()!.startsWith('.') && statSync(f).size <= PRECACHE_LIMIT)
        .map((f) => relative(out, f).split('\\').join('/'))
        .sort()
      const hash = createHash('sha256')
      for (const f of files.filter((f) => f !== join(out, 'sw.js')).sort()) hash.update(f).update(readFileSync(f))
      const sw = join(out, 'sw.js')
      writeFileSync(sw, readFileSync(sw, 'utf8').replace('__BUILD__', hash.digest('hex').slice(0, 12)).replace('__PRECACHE__', JSON.stringify(['', ...urls])))
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  // GitHub Pages serves the site from /<repository>/, set by the deploy workflow.
  base: process.env.BASE_PATH ?? '/',
  plugins: [react(), offlineCache()],
})
