// Regenerates the iOS parity fixture from the web app's engine (src/assistant/search.ts):
// the Swift tests check that CodeIsraelKit returns exactly the same hits, law passages and answers.
// Usage: npx esbuild src/assistant/search.ts --bundle --format=esm --outfile=/tmp/search.mjs && node scripts/ios-parity-fixtures.mjs /tmp/search.mjs
import fs from 'fs'
import { pathToFileURL } from 'url'

const { QuestionIndex, LawIndex, sources, reply, retrieve, tokens, unsupported, vehicleMismatch } = await import(pathToFileURL(process.argv[2]).href)
const read = (p) => JSON.parse(fs.readFileSync(p, 'utf8'))
const qs = read('public/data/questions.fr.json')
const law = read('public/data/law.json')
const signs = read('public/data/signs.json')
const tests = 'ios/CodeIsraelKit/Tests/CodeIsraelKitTests'
const { queries, answers } = read(`${tests}/parity-inputs.json`)

const lawIndex = new LawIndex(law)
const cases = []
for (const lic of ['B', 'A']) {
  const index = new QuestionIndex(qs.filter((q) => q.lic.includes(lic)))
  for (const query of queries) {
    const { hits, lawHits } = retrieve(index, lawIndex, query)
    cases.push({
      lic, query, hits: hits.map((q) => q.id), law: lawHits.map((h) => h.ref),
      mismatch: vehicleMismatch(query, hits[0], lawHits[0]),
      reply: reply(hits, law, signs, undefined, undefined, lawHits, query),
      sources: sources(hits, law, undefined, signs, lawHits, query),
    })
  }
  // The assistant opened from a question, after a wrong answer.
  for (const id of ['0152', '0274', '0231', '1283']) {
    const focus = qs.find((q) => q.id === id)
    if (!focus.lic.includes(lic)) continue
    const query = `Pourquoi ma réponse est-elle fausse ? ${focus.q}`
    const { hits, lawHits } = retrieve(index, lawIndex, query)
    const shown = [focus, ...hits.filter((h) => h.id !== focus.id)].slice(0, 4)
    const chosen = (focus.c + 1) % focus.a.length
    cases.push({
      lic, query, focus: id, chosen, hits: shown.map((q) => q.id), law: lawHits.map((h) => h.ref),
      reply: reply(shown, law, signs, focus, chosen, lawHits, query),
      sources: sources(shown, law, focus, signs, lawHits, query),
    })
  }
}

const index = new QuestionIndex(qs.filter((q) => q.lic.includes('B')))
const guarded = answers.map(({ query, answer }) => {
  const { hits, lawHits } = retrieve(index, lawIndex, query)
  const sourceText = sources(hits, law, undefined, signs, lawHits, query)
  return { query, answer, sourceText, unsupported: unsupported(answer, sourceText, query) }
})
const samples = ['Dépassement', "C'est quoi la vitesse max en ville ?", 'stationnements interdits', 'l’alcoolémie des conducteurs', 'Ça déborde', 'œuvre façade naïve']
fs.writeFileSync(`${tests}/Fixtures/parity.json`, JSON.stringify({ cases, tokens: samples.map((text) => ({ text, tokens: tokens(text) })), unsupported: guarded }))
console.log(`${cases.length} cases, ${guarded.length} model answers`)
