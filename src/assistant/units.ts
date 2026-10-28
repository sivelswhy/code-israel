type Dimension = 'speed' | 'length' | 'mass' | 'volume'

interface UnitDef {
  symbol: string
  dimension: Dimension
  /** Value of one unit in the base unit of its dimension (m/s, m, kg, L). */
  factor: number
  /** How the unit is written in French text. */
  spellings: string[]
}

// Order matters: "mètres par seconde" must be tried before "mètres", "miles par heure" before "miles".
const UNITS: UnitDef[] = [
  { symbol: 'km/h', dimension: 'speed', factor: 1 / 3.6, spellings: ['kilomètres par heure', 'kilomètre par heure', 'km par heure', 'km/h', 'kmh'] },
  { symbol: 'mph', dimension: 'speed', factor: 0.44704, spellings: ['miles par heure', 'mile par heure', 'miles/h', 'mi/h', 'mph'] },
  { symbol: 'm/s', dimension: 'speed', factor: 1, spellings: ['mètres par seconde', 'mètre par seconde', 'm/s'] },
  { symbol: 'km', dimension: 'length', factor: 1000, spellings: ['kilomètres', 'kilomètre', 'km'] },
  { symbol: 'mi', dimension: 'length', factor: 1609.344, spellings: ['miles', 'mile'] },
  { symbol: 'm', dimension: 'length', factor: 1, spellings: ['mètres', 'mètre', 'm'] },
  { symbol: 'cm', dimension: 'length', factor: 0.01, spellings: ['centimètres', 'centimètre', 'cm'] },
  { symbol: 'ft', dimension: 'length', factor: 0.3048, spellings: ['pieds', 'pied', 'ft'] },
  { symbol: 'yd', dimension: 'length', factor: 0.9144, spellings: ['yards', 'yard', 'yd'] },
  { symbol: 'in', dimension: 'length', factor: 0.0254, spellings: ['pouces', 'pouce'] },
  { symbol: 'kg', dimension: 'mass', factor: 1, spellings: ['kilogrammes', 'kilogramme', 'kilos', 'kilo', 'kg'] },
  { symbol: 'g', dimension: 'mass', factor: 0.001, spellings: ['grammes', 'gramme', 'g'] },
  { symbol: 't', dimension: 'mass', factor: 1000, spellings: ['tonnes', 'tonne', 't'] },
  { symbol: 'lb', dimension: 'mass', factor: 0.45359237, spellings: ['livres', 'livre', 'lbs', 'lb'] },
  { symbol: 'oz', dimension: 'mass', factor: 0.028349523, spellings: ['onces', 'once', 'oz'] },
  { symbol: 'L', dimension: 'volume', factor: 1, spellings: ['litres', 'litre', 'l'] },
  { symbol: 'mL', dimension: 'volume', factor: 0.001, spellings: ['millilitres', 'millilitre', 'ml'] },
  { symbol: 'gal', dimension: 'volume', factor: 3.785411784, spellings: ['gallons', 'gallon', 'gal'] },
]

const alternation = UNITS.flatMap((u) => u.spellings)
  .map((s) => s.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&'))
  .join('|')
const INTENT = /combien|convert|équival|conversion|exprim|(?:ça|cela) (?:fait|ferait|donne|donnerait|vaut|vaudrait)|en\s+\S+(?:\s+par\s+\S+)?\s*\?\s*$/iu
const TARGET = new RegExp(`(?<!\\p{L})en\\s+(${alternation})(?![\\p{L}'’/])`, 'iu')
const QUANTITY = new RegExp(`(\\d+(?:[.,]\\d+)?)\\s*(${alternation})(?![\\p{L}/])`, 'giu')

const unitOf = (text: string) => UNITS.find((u) => u.spellings.includes(text.toLowerCase()))

function format(x: number): string {
  const digits = Math.abs(x) >= 100 ? 0 : Math.abs(x) >= 1 ? 1 : 2
  let s = x.toFixed(digits).replace('.', ',')
  if (s.includes(',')) s = s.replace(/0+$/, '').replace(/,$/, '')
  return s
}

/**
 * Converts the values of the previous answer (or of the message) into the unit the learner asks for
 * ("et ça fait combien en miles par heure ?"). The arithmetic is done here, exactly: a model would have
 * to write numbers that are in no source, which the answer guard rightly refuses.
 */
export function convertUnits(message: string, previousAnswer?: string | null): string | null {
  if (!INTENT.test(message)) return null
  const targetText = TARGET.exec(message)?.[1]
  const target = targetText ? unitOf(targetText) : undefined
  if (!target) return null
  const found: { value: number; unit: UnitDef }[] = []
  for (const text of [message, previousAnswer ?? '']) {
    for (const [, n, u] of text.matchAll(QUANTITY)) {
      const unit = unitOf(u)
      const value = Number(n.replace(',', '.'))
      if (!unit || unit.dimension !== target.dimension || unit.symbol === target.symbol || Number.isNaN(value)) continue
      if (!found.some((f) => f.value === value && f.unit.symbol === unit.symbol)) found.push({ value, unit })
    }
    if (found.length) break
  }
  if (!found.length) return null
  const lines = found.slice(0, 4).map((f) => `• ${format(f.value)} ${f.unit.symbol} ≈ ${format((f.value * f.unit.factor) / target.factor)} ${target.symbol}`)
  const first = found[0].unit
  const ratio = Number((first.factor / target.factor).toPrecision(4)).toString().replace('.', ',')
  return `${lines.join('\n')}\nConversion calculée par l’application (1 ${first.symbol} ≈ ${ratio} ${target.symbol}), à titre indicatif : les textes officiels israéliens emploient le système métrique.`
}
