import { CATEGORIES, type Category, type LawExcerpt, type Question } from '../data'

/** Local BM25 search over the French question bank and its explanations — no network, no AI. */

const STOP = new Set(
  `le la les un une des de du d l au aux et ou en a à est sont il elle on je tu vous nous ce cet cette ces que qui quoi
  quel quelle quels quelles dans sur sous pour par avec sans ne pas plus moins se sa son ses leur leurs y si mais
  comme quand comment pourquoi peux veux puis qu elles ils ont mon ma mes ton ta tes notre votre entre vers chez lors dont ainsi afin est-ce faut peut doit dois puis-je ai as avez être avoir fait faire très tout tous`.split(/\s+/),
)

export function tokens(text: string): string[] {
  return text
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[’']/g, ' ')
    .split(/[^a-z0-9]+/)
    .filter((t) => t.length > 1 && !STOP.has(t))
    .map((t) => (t.length > 4 ? t.replace(/[sx]$/, '') : t))
    // "dépassement" and "dépasser" (or "stationnement" / "stationner") are the same idea.
    .map((t) => (t.length > 8 ? t.replace(/ement$/, 'er') : t))
}

/** Words a learner may use for the same idea; a query word also looks for the others in its group. */
const SYNONYMS = [
  'vitesse limitation limite maximale km/h',
  'ville agglomération urbain urbaine localité village',
  'alcool alcoolémie alcoolisé boisson ivresse ivre',
  'priorité céder cédez passage',
  'stop arrêt arrêter immobilisation',
  'stationnement stationner garer garé parking',
  'feu feux sémaphore rouge vert orange clignotant',
  'piéton trottoir',
  'ceinture attaché bouclé',
  'téléphone portable mobile smartphone',
  'permis licence conducteur novice jeune nouveau',
  'accident collision blessé',
  'dépasser dépassement doubler',
  'carrefour intersection croisement rond-point giratoire',
  'panneau signal signalisation',
  'moto motocycle scooter motard casque',
  'vélo bicyclette cycliste',
  'camion poids lourd',
  'amende sanction contravention points pénalité infraction',
  'distance sécurité espacement écart intervalle suivre derrière',
  'voiture véhicule automobile auto',
  'nuit éclairage phare croisement lumière',
  'frein freinage',
  'autoroute voie rapide',
  'enfant mineur siège gosse gosses gamin môme mioche bébé petit',
  'conduire conduit conduis conduisez conduira conduisant conduite rouler roule roules roulez roulant circuler circule piloter',
  'conducteur chauffeur automobiliste',
  'bus autobus car',
  'mettre poser placer installer disposer',
  'triangle signalisation',
  'phare feux route croisement éblouir éblouissement code',
  'griller brûler franchir ignorer passer feu',
  'ambulance pompier pompiers police policier gyrophare sirène urgence prioritaire secours',
  'papiers documents identité attestation passeport',
  'prêter prête prêtes prêtent prêté laisser laisse autoriser autorise autorisé permettre permet confier emprunter',
  'âge ans année',
  'taux concentration seuil limite maximum niveau mesure',
  'verre bière vin whisky alcool boire boit bois bu boisson ivresse ivre alcoolémie souffler éthylotest',
  'tel téléphoner téléphone portable mobile appel appeler sms message répondre',
  'pote potes copain copains ami amis passager passagers',
  'perdre perd perte retirer retire retrait retiré déchéance déchu suspendre suspendu suspension annuler',
  'coller colle collé talonner serrer proche distance',
  'accotement bas-côté bande urgence',
  'devant avant',
  'pneu pneus lisse lisses usé usure profondeur rainure sculpture',
  'côte pente montée descente colline',
  'risque risquer passe sanction peine puni punit punir prison amende encourt grave',
]
const GROUPS = new Map<string, string[]>()
for (const line of SYNONYMS) {
  const group = [...new Set(tokens(line))]
  // A word in several groups gets all of them ("feux" is both a traffic light and a headlight).
  for (const t of group) GROUPS.set(t, [...new Set([...(GROUPS.get(t) ?? []), ...group])])
}

export interface Hit {
  question: Question
  score: number
}

/** Words of a question whose answer is a figure (a rate, a limit, an age, a duration…). */
/** A number with its unit (240 microgrammes, 50 km/h, 3 ans…), unlike the list numbers "(3a)". */
const HAS_FIGURE = /\d+(?:[.,]\d+)?\s*(?:km|kg|m\b|mètres?|heures?|minutes?|secondes?|ans?\b|jours?|mois|%|cm|mm|microgrammes?|milligrammes?|livres|passagers|points)/i

// (JavaScript's \b ignores accented letters, so "âge" is delimited by explicit letter lookarounds.)
const ASKS_FIGURE = /combien|taux|seuil|limite|maxim|minim|(?<!\p{L})âge(?!\p{L})|dur[ée]e|distance|vitesse|poids/iu

const OTHER_VEHICLES = /commercial|autobus|tracteur|\blent|travail|excursion|machine mobile|quad|camion|\bmoto|taxi/i

const VEHICLES = [/\bmoto|scooter|motocycl/i, /\bquad|tout-terrain/i, /tracteur/i, /camion|poids lourd/i, /\bbus\b|autobus|\bcar\b/i, /v[ée]lo|bicyclette|cycliste/i, /taxi/i, /ambulance|pompier/i]

/**
 * True when the user names a kind of vehicle (motorcycle, tractor, bus…) that the best sources never
 * mention: they then describe another vehicle's rule, which must not be passed off as the answer.
 */
export function vehicleMismatch(query: string, best: Question | undefined, bestLaw: LawHit | undefined) {
  if (!best && !bestLaw) return false
  const text = `${best?.q ?? ''} ${best?.a[best.c] ?? ''} ${best?.e ?? ''} ${bestLaw?.excerpt.f ?? ''}`
  return VEHICLES.some((v) => v.test(query) && !v.test(text))
}

/**
 * True when a model answer cites a number, a sign or a law article that is in neither the sources nor
 * the question: a small model sometimes invents them, and the answer must then not be shown.
 */
export function unsupported(answer: string, sourceText: string, query: string) {
  const known = `${sourceText} ${query}`
  const numbers = (answer.match(/\d+(?:[.,]\d+)?/g) ?? []).some((n) => !new RegExp(`(?<![\\d.,])${n}(?![\\d])`).test(known))
  const articles = [...answer.matchAll(/\bart(?:icle|\.)?\s*(\d+[A-Za-z]?)/gi)].some((m) => !new RegExp(`art(?:icle|\\.)?\\s*${m[1]}(?![\\dA-Za-z])`, 'i').test(sourceText))
  // Every sentence must rest on words of the sources: a claim made of other words was not read from them.
  const allowed = new Set(tokens(known))
  const ungrounded =
    !/je n['’]ai pas trouvé/i.test(answer) &&
    answer
      .split(/(?<=[.!?])\s+|\n+/)
      .map(tokens)
      .some((t) => t.length >= 4 && t.filter((w) => allowed.has(w)).length / t.length < 0.6)
  return numbers || articles || ungrounded
}

/** Okapi BM25 over any list of items, with synonym expansion and a bonus for covering every idea of the query. */
class Bm25<T> {
  private docs: { item: T; tf: Map<string, number>; len: number }[]
  private df = new Map<string, number>()
  private avg: number
  private boost: (item: T) => number

  constructor(items: T[], textOf: (item: T) => string, boost: (item: T) => number = () => 1) {
    this.boost = boost
    this.docs = items.map((item) => {
      const tk = tokens(textOf(item))
      const tf = new Map<string, number>()
      for (const t of tk) tf.set(t, (tf.get(t) ?? 0) + 1)
      for (const t of tf.keys()) this.df.set(t, (this.df.get(t) ?? 0) + 1)
      return { item, tf, len: tk.length }
    })
    this.avg = this.docs.reduce((s, d) => s + d.len, 0) / Math.max(1, this.docs.length)
  }

  /** `minCoverage`: share of the query's words (or their synonyms) a result must contain. */
  search(text: string, limit: number, minCoverage = 0): { item: T; score: number }[] {
    // Words typed by the user count fully; their synonyms count for a little less.
    const terms = new Map<string, number>()
    const asked = [...new Set(tokens(text))]
    for (const t of asked) terms.set(t, 1)
    for (const t of [...terms.keys()]) for (const x of GROUPS.get(t) ?? []) if (!terms.has(x)) terms.set(x, 0.5)
    const n = this.docs.length
    const hits: { item: T; score: number }[] = []
    for (const d of this.docs) {
      let score = 0
      for (const [t, weight] of terms) {
        const f = d.tf.get(t)
        if (!f) continue
        const idf = Math.log(1 + (n - this.df.get(t)! + 0.5) / (this.df.get(t)! + 0.5))
        score += (weight * (idf * f * 2.2)) / (f + 1.2 * (0.25 + 0.75 * (d.len / this.avg)))
      }
      // A document covering every idea of the query (directly or through a synonym) beats one matching a single rare word.
      const covered = asked.filter((t) => d.tf.has(t) || (GROUPS.get(t) ?? []).some((x) => d.tf.has(x))).length / Math.max(1, asked.length)
      if (score > 0 && covered >= minCoverage) hits.push({ item: d.item, score: score * (0.4 + covered) * this.boost(d.item) })
    }
    return hits.sort((a, b) => b.score - a.score).slice(0, limit)
  }
}

export class QuestionIndex {
  // The question, its correct answer and the explanation describe the rule; wrong answers would add noise.
  // Prefer questions that come with a written explanation and legal references.
  private index: Bm25<Question>

  constructor(questions: Question[]) {
    this.index = new Bm25(questions, (q) => `${q.q} ${q.a[q.c]} ${q.e ?? ''}`, (q) => (q.e ? 1.25 : 1))
  }

  search(text: string, limit = 4): Hit[] {
    return this.index.search(text, limit).map(({ item, score }) => ({ question: item, score }))
  }
}

export interface LawHit {
  ref: string
  excerpt: LawExcerpt
  score: number
}

/** Search over the French rendering of the traffic regulations, independent of the question bank. */
export class LawIndex {
  private index: Bm25<[string, LawExcerpt]>

  constructor(law: Record<string, LawExcerpt>) {
    this.index = new Bm25(
      Object.entries(law).filter(([, e]) => e.f),
      ([, e]) => `${e.l} ${e.f}`,
    )
  }

  /** Only passages that cover most of the query words are returned, so unrelated articles stay out. */
  search(text: string, limit = 2): LawHit[] {
    // "How much / what limit / what age": the passage that actually states a figure answers it.
    const asksFigure = ASKS_FIGURE.test(text)
    return this.index
      .search(text, limit + 3, 0.6)
      .map(({ item: [ref, excerpt], score }) => ({ ref, excerpt, score: score * (asksFigure && HAS_FIGURE.test(excerpt.f ?? '') ? 1.35 : 1) }))
      .sort((a, b) => b.score - a.score)
      .slice(0, limit)
  }
}

/** Article a reference belongs to: "T47(ה)(2)" and "T47(ב)" are both "T47". */
const article = (ref: string) => ref.replace(/[(:].*$/, '')

/**
 * Finds the best official questions and law passages for a query. A question whose legal reference is
 * in an article the law search also found is promoted, so the two sources agree on the same rule.
 */
export function retrieve(questions: QuestionIndex, law: LawIndex, query: string, limit = 4) {
  const lawHits = law.search(query)
  const articles = new Set(lawHits.map((h) => article(h.ref)))
  const hits = questions
    .search(query, 12)
    .map((h) => ({ ...h, score: h.score * ((h.question.r ?? []).some((r) => articles.has(article(r))) ? 1.6 : 1) }))
    .sort((a, b) => b.score - a.score)
    .slice(0, limit)
    .map((h) => h.question)
  return { hits, lawHits }
}

/** Sign numbers mentioned by a sign-related question, e.g. "432". */
function citedSignNumbers(q: Question, signs: Record<string, { fr: string }>) {
  if (q.cat !== 'signs' && !/panneau/i.test(q.q)) return []
  // A 3-digit number followed by a unit (125 cm³, 120 km/h, 750 kg…) is a quantity, not a sign.
  const found = [...[q.q, ...q.a].join(' ').matchAll(/(?<![\d,.])(\d{3})(?![\d,.]|\s?(?:cm|km|kg|kw|ch\b|m\b|mètres|%|chevaux))/gi)].map((m) => m[1])
  return [...new Set(found)].filter((n) => signs[n])
}

/** Builds the grounding block given to the model: only official facts, our explanations and cited law. */
export function sources(hits: Question[], law: Record<string, LawExcerpt>, focus?: Question, signs: Record<string, { fr: string }> = {}, lawHits: LawHit[] = [], query = ''): string {
  const block = (q: Question, detailed: boolean) => {
    const lines = [`[Question officielle n° ${q.id}] ${q.q}`]
    if (detailed) lines.push(`Réponses proposées : ${q.a.map((a, i) => `${'ABCD'[i]}) ${a}`).join(' | ')}`)
    lines.push(`Bonne réponse : ${q.a[q.c]}`)
    if (q.e) lines.push(`Explication : ${q.e}`)
    const cited = detailed ? citedSignNumbers(q, signs) : []
    for (const n of cited) lines.push(`Panneau ${n} : ${signs[n].fr}`)
    for (const r of q.r ?? []) {
      const ex = law[r]
      if (!ex) continue
      // A short French excerpt keeps the 4k-token context of small models free.
      lines.push(detailed && ex.f ? `${ex.l} : ${focusClip(ex.f, query || q.q, 450)}` : `Référence : ${ex.l}`)
    }
    return lines.join('\n')
  }
  const rest = hits.filter((h) => h.id !== focus?.id).slice(0, focus ? 2 : 3)
  const cited = new Set(hits.flatMap((q) => q.r ?? []))
  const law_ = lawHits.filter((h) => !cited.has(h.ref)).map((h) => `[Texte de loi] ${h.excerpt.l} : ${focusClip(h.excerpt.f ?? '', query, 450)}`)
  return [...(focus ? [block(focus, true)] : []), ...rest.map((q) => block(q, !focus)), ...law_].join('\n\n')
}

/**
 * Shortens a legal passage to `max` characters, keeping the lines that best match the query (a long
 * article lists many rules: the model should see the one that was asked about, not just the start).
 */
function focusClip(text: string, query: string, max: number) {
  if (text.length <= max) return text
  const own = new Set(tokens(query))
  const asked = new Set([...own].flatMap((t) => [t, ...(GROUPS.get(t) ?? [])]))
  const lines = text.split('\n')
  // Distinct matching words, those typed by the user counting double (repeats inside a line don't help).
  const figure = ASKS_FIGURE.test(query)
  // When the question asks for a figure, lines stating one come first.
  // A line about trucks, buses or tractors is not the answer for a question that names none of them.
  const otherKind = (l: string) => OTHER_VEHICLES.test(l) && !OTHER_VEHICLES.test(query)
  const score = (l: string) =>
    [...new Set(tokens(l))].reduce((n, t) => n + (own.has(t) ? 2 : asked.has(t) ? 1 : 0), 0) + (figure && HAS_FIGURE.test(l) ? 2 : 0) - (otherKind(l) ? 4 : 0)
  // The first line introduces the list: keep it short so the matching items fit.
  const head = lines[0].length > 140 ? `${lines[0].slice(0, 140).replace(/\s+\S*$/, '')}…` : lines[0]
  const keep = new Map<number, string>([[0, head]])
  let size = head.length
  const ranked = lines.map((_, i) => i).filter((i) => i > 0 && score(lines[i]) > 0).sort((a, b) => score(lines[b]) - score(lines[a]) || a - b)
  for (const [n, i] of ranked.entries()) {
    // The two best-matching lines are always kept, even if long; the others only while there is room.
    if (n > 1 && size + lines[i].length + 1 > max) continue
    keep.set(i, lines[i])
    size += lines[i].length + 1
  }
  return [...keep.entries()].sort((a, b) => a[0] - b[0]).map(([, l]) => l).join('\n')
}

const sentence = (t: string) => (/[.!?…]$/.test(t.trim()) ? t.trim() : `${t.trim()}.`)

/** What the learner is asking for, which decides how the answer opens. */
export type QuestionKind = 'why' | 'remember' | 'figure' | 'definition' | 'permission' | 'who' | 'when' | 'how' | 'other'

const KINDS: [QuestionKind, RegExp][] = [
  ['why', /(?<!\p{L})pourquoi(?!\p{L})|pour quelle raison/iu],
  ['remember', /retenir|mémoriser|astuce|moyen (?:simple )?de/iu],
  // Before "definition": "c'est quoi la vitesse max" asks for a figure.
  ['figure', ASKS_FIGURE],
  ['definition', /c['’]est quoi|qu['’]est[- ]ce (?:que|qu['’])|que (?:signifie|veut dire)|définition/iu],
  ['permission', /(?<!\p{L})(?:peut[- ]on|peut[- ]il|puis[- ]je|ai[- ]je le droit|a[- ]t[- ]on le droit|faut[- ]il|dois[- ]je|doit[- ]on|est[- ]il (?:permis|autorisé|interdit)|est[- ]ce (?:que|permis|autorisé|interdit)|je peux|on peut|j['’]ai le droit|c['’]est (?:permis|autorisé|interdit|légal))(?!\p{L})/iu],
  ['who', /^\s*(?:et )?qui(?!\p{L})/iu],
  ['when', /(?<!\p{L})quand(?!\p{L})|à partir de quand|dans quel cas/iu],
  ['how', /^\s*comment(?!\p{L})/iu],
]

export function questionKind(text: string): QuestionKind {
  return KINDS.find(([, re]) => re.test(text))?.[0] ?? 'other'
}

/**
 * Answer written without any language model: the verified correct answer, our explanation and the
 * cited article, assembled from the best-matching official question.
 */
export function compose(q: Question, law: Record<string, LawExcerpt>, chosen?: number | null, kind: QuestionKind = 'other'): string {
  const right = q.a[q.c].replace(/[.\s]+$/, '')
  const wrong = chosen != null && chosen !== q.c
  const lead = wrong
    ? `Votre réponse « ${q.a[chosen].replace(/[.\s]+$/, '')} » est fausse. La bonne réponse est « ${right} ».`
    : kind === 'remember'
      ? `À retenir : « ${right} ».`
      : kind === 'why'
        ? `La bonne réponse est « ${right} ». Voici pourquoi.`
        : `La bonne réponse est « ${right} ».`
  const label = (q.r ?? []).map((r) => law[r]?.l).find(Boolean)
  return [lead, q.e && sentence(q.e), label && `Référence : ${label}.`].filter(Boolean).join(' ')
}

const trim = (t: string) => t.replace(/[.\s]+$/, '')

/**
 * Answer to a free question without any language model: the best-matching official question
 * presented as a source (not as if the student had asked it), its explanation, the cited article,
 * the meaning of cited signs, and the next best matches. With a focus question, explains that one.
 */
export function reply(
  hits: Question[],
  law: Record<string, LawExcerpt>,
  signs: Record<string, { fr: string }>,
  focus?: Question,
  chosen?: number | null,
  lawHits: LawHit[] = [],
  query = '',
  /** What the learner typed, without the question in focus or the previous message; decides how the answer opens. */
  message?: string,
): string {
  const [best, ...others] = hits
  if (!best) return ''
  const kind = questionKind(message ?? (focus ? '' : query))
  const label = (q: Question) => (q.r ?? []).map((r) => law[r]?.l).find(Boolean)
  const signLines = (q: Question) => citedSignNumbers(q, signs).slice(0, 3).map((n) => `Panneau ${n} : ${trim(signs[n].fr)}.`)

  // Free question: the matching official question is shown as a source, not as if it answered exactly what
  // was typed (the match may be approximate). Only a question in focus gets an opening that follows the request.
  const head = focus
    ? compose(best, law, chosen, kind)
    : [`D'après la question officielle n° ${best.id} (« ${trim(best.q)} ») : ${trim(best.a[best.c])}.`, best.e && sentence(best.e), label(best) && `Référence : ${label(best)}.`]
        .filter(Boolean)
        .join(' ')
  const parts = [head, ...signLines(best)]
  // The wording of the law itself. When the best question is about another article than the best law
  // passages, the law comes first: it answers the query, the question only illustrates a nearby rule.
  const found = lawHits.slice(0, 2).map((h) => h.excerpt)
  // A question asking for a figure is answered by the passage that states it, which then comes first.
  if (ASKS_FIGURE.test(query)) found.sort((a, b) => Number(HAS_FIGURE.test(b.f ?? '')) - Number(HAS_FIGURE.test(a.f ?? '')))
  // ...unless the best question already gives the figure itself.
  const figureFirst = ASKS_FIGURE.test(query) && HAS_FIGURE.test(found[0]?.f ?? '') && !/\d/.test(best.a[best.c])
  const own = (best.r ?? []).map((r) => law[r]).find((e) => e?.f)
  const sameArticle = !found.length || lawHits.some((h) => (best.r ?? []).some((r) => article(r) === article(h.ref)))
  // Law passages about another article than the best question's are probably noise: trust the question's own.
  const useOwn = !sameArticle && !!own
  const passages = useOwn ? [own] : found.length ? found : own ? [own] : []
  const agrees = sameArticle || useOwn
  const lawLines = passages.map((p) => `Texte de loi — ${p.l} : ${focusClip(p.f ?? '', query, 360)}`)
  // What is actually displayed decides the order: the visible passage that states the figure comes first.
  if (ASKS_FIGURE.test(query)) lawLines.sort((a, b) => Number(HAS_FIGURE.test(b.replace(/^[^:]*:/, ''))) - Number(HAS_FIGURE.test(a.replace(/^[^:]*:/, ''))))
  if (agrees && !(figureFirst && !useOwn)) parts.push(...lawLines)
  else parts.unshift(...lawLines)
  const more = others.slice(0, 2)
  if (more.length) {
    parts.push('À voir aussi :')
    for (const q of more) parts.push(`• n° ${q.id} — ${trim(q.q)} → ${trim(q.a[q.c])}.${label(q) ? ` (${label(q)})` : ''}`)
  }
  return parts.join('\n')
}

/** What a model is told about the kind of answer expected, so it answers the question as it was asked. */
export function kindHint(kind: QuestionKind): string {
  const hints: Partial<Record<QuestionKind, string>> = {
    why: "l'élève demande la raison : commence par la raison, avec les mots des sources.",
    remember: "l'élève veut retenir la règle : résume-la en une seule phrase courte et facile à mémoriser, commençant par « À retenir : », sans rien ajouter aux sources.",
    figure: "l'élève veut une valeur : commence par ce chiffre, tel qu'il est dans les sources.",
    definition: "l'élève veut une définition : donne-la en une phrase, avec les mots des sources.",
    permission: "l'élève demande si c'est permis : énonce la règle des sources qui répond, sans conclure au-delà de ce qu'elles disent.",
    who: "l'élève demande « qui » : commence par la personne ou l'autorité désignée dans les sources.",
    when: "l'élève demande « quand » : commence par la condition ou le moment indiqué dans les sources.",
    how: "l'élève demande « comment » : commence par la manière indiquée dans les sources.",
  }
  return hints[kind] ?? ''
}

export interface Stat {
  ok: number
  ko: number
  last: boolean
}

/** The category where the learner does worst, if there are enough answers to say and it is below 60 %. */
function weakestCategory(stats: Record<string, Stat>, pool: Question[]): { cat: Category; percent: number } | null {
  let weakest: { cat: Category; percent: number } | null = null
  for (const cat of Object.keys(CATEGORIES) as Category[]) {
    let ok = 0
    let ko = 0
    for (const q of pool) {
      if (q.cat !== cat) continue
      ok += stats[q.id]?.ok ?? 0
      ko += stats[q.id]?.ko ?? 0
    }
    if (ok + ko < 8) continue
    const percent = Math.round((ok / (ok + ko)) * 100)
    if (percent < 60 && (!weakest || percent < weakest.percent)) weakest = { cat, percent }
  }
  return weakest
}

/**
 * A short remark about the learner's own results, shown above an answer. Composed from the saved results,
 * never written by a model, so it cannot invent a figure.
 */
export function personalNote(topic: { question: Question } | undefined, hits: Question[], stats: Record<string, Stat>, pool: Question[]): string | null {
  const q = topic?.question ?? hits[0]
  if (!q) return null
  const lines: string[] = []
  const s = topic && stats[q.id]
  if (s) {
    if (s.ko >= 2) lines.push(`Cette question vous a déjà fait trébucher ${s.ko} fois : prenez le temps de bien retenir la règle.`)
    else if (s.ko === 1 && s.ok === 0) lines.push('Vous avez déjà raté cette question une fois.')
    else if (s.ok >= 2 && s.ko === 0) lines.push('Vous réussissez habituellement cette question : cette explication sert à la consolider.')
  }
  const weak = weakestCategory(stats, pool)
  if (weak && weak.cat === q.cat) {
    lines.push(`Le thème « ${CATEGORIES[q.cat].label} » est votre point faible pour l’instant (${weak.percent} % de réussite) : une série d’entraînement dessus vous aiderait.`)
  }
  return lines.length ? lines.join(' ') : null
}

const LAW_QUOTE = /^\s*\[?((?:Règlement|Ordonnance) de la circulation, art\. [^:\]\n]+?)\]?\s*:\s*.{120,}$/u

/**
 * A model sometimes pastes a whole article after its answer. A long quotation is replaced by the
 * reference alone: the text of the law stays available through the sources.
 */
export function tidyAnswer(text: string): string {
  // The invented example starts its own paragraph, so it cannot be mistaken for the rule above it.
  const labelled = text.replace(new RegExp(EXAMPLE_LABEL.source, 'giu'), 'Exemple imaginé :').replace(/\s*Exemple imaginé :/g, '\n\nExemple imaginé :').replace(/^\n+/, '')
  return labelled
    .split('\n')
    .map((line) => {
      const ref = LAW_QUOTE.exec(line)?.[1]
      return ref ? `Référence : ${ref.trim()}.` : line
    })
    .join('\n')
}

/** The message points back at the previous answer rather than asking about a new subject. */
export const REFERS_TO_PREVIOUS = /(?<!\p{L})(?:ça|cela|ceci|ce chiffre|cette valeur|cette règle|cette réponse|cette limite|ta réponse|ton explication|tu viens de (?:dire|préciser)|tu as dit|plus simplement|plus simple|autrement|reformule|résume|exemple|concret|développe|détaille|précise)(?!\p{L})/iu

/** Given to the model when the learner builds on the last answer: reword it or illustrate it, nothing more. */
export const FOLLOW_UP_HINT =
  "\nTYPE DE DEMANDE : l'élève s'appuie sur ta réponse précédente. Fais ce qu'il demande à partir d'elle et des sources : reformule avec des mots plus simples, ou illustre par une courte situation de conduite. N'écris aucun chiffre ni règle qui ne soit dans les sources, et ne répète pas ta réponse mot pour mot."

const ILLUSTRATION_REQUEST = /(?<!\p{L})(?:exemples?|concret|imaginons|imagine|analogie|métaphore|scénario|mise en situation|vulgaris\p{L}*|explication imagée|eli5|comme (?:un|une|à un|à une) (?:enfant|gamin|bébé|débutant|petit)|(?:pour|à) un enfant|comme si j['’]avais \d+ ans)(?!\p{L})/giu

/**
 * The learner wants an example or an image ("donne-moi un exemple", "explique-moi comme à un enfant"):
 * the answer may then contain a clearly labelled invented example.
 */
export const asksForIllustration = (text: string) => new RegExp(ILLUSTRATION_REQUEST.source, 'iu').test(text)

/** The message without the words that only ask for an example, so "comme si j'avais 5 ans" is not searched for. */
export const withoutIllustrationWords = (text: string) => text.replace(ILLUSTRATION_REQUEST, ' ').split(/\s+/).filter(Boolean).join(' ')

/** Asked of the model when the learner wants an example or an image. */
export const ILLUSTRATION_HINT =
  "\nTYPE DE DEMANDE : l'élève veut un exemple ou une explication imagée (peut-être « comme à un enfant »). Écris d'abord la règle en une phrase simple, exactement comme dans les sources. Puis écris « Exemple imaginé : » suivi d'une courte situation inventée de conduite ou d'une comparaison simple, avec des mots d'enfant si on te le demande. L'exemple peut utiliser des prénoms et des valeurs d'illustration, mais il doit appliquer la règle des sources sans la changer, sans la compléter et sans citer d'article ni de numéro de panneau."

/** The label as a model may write it ("Exemple imaginé", sometimes "Example inventé"…). */
const EXAMPLE_LABEL = /(?:exemple|example)\s+(?:imaginé|imaginée|imaginaire|inventé|inventée)\s*:?/iu
const INVENTED_REFERENCE = /(?:art(?:icle|\.)?|panneau)\s*\d/iu

/**
 * Like `unsupported`, for an answer that may contain an invented example. The rule before the label is held
 * to the sources as usual. The example after it is invented on purpose and may use figures of its own, but may
 * not cite an article or a sign number: that would pass for the law. Without the label, the whole answer is
 * held to the sources.
 */
export function unsupportedIllustrated(answer: string, sourceText: string, query: string): boolean {
  const label = EXAMPLE_LABEL.exec(answer)
  if (!label) return unsupported(answer, sourceText, query)
  const rule = answer.slice(0, label.index).trim()
  // The rule comes first: an answer that opens with the example is not trusted.
  if (!rule) return unsupported(answer, sourceText, query)
  if (unsupported(rule, sourceText, query)) return true
  return INVENTED_REFERENCE.test(answer.slice(label.index + label[0].length))
}
