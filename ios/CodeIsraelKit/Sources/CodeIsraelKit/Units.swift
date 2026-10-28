import Foundation

private enum Dimension { case speed, length, mass, volume }

private struct UnitDef {
    let symbol: String
    let dimension: Dimension
    /// Value of one unit in the base unit of its dimension (m/s, m, kg, L).
    let factor: Double
    /// How the unit is written in French text.
    let spellings: [String]
}

// Order matters: "mètres par seconde" must be tried before "mètres", "miles par heure" before "miles".
private let unitDefs: [UnitDef] = [
    UnitDef(symbol: "km/h", dimension: .speed, factor: 1 / 3.6, spellings: ["kilomètres par heure", "kilomètre par heure", "km par heure", "km/h", "kmh"]),
    UnitDef(symbol: "mph", dimension: .speed, factor: 0.44704, spellings: ["miles par heure", "mile par heure", "miles/h", "mi/h", "mph"]),
    UnitDef(symbol: "m/s", dimension: .speed, factor: 1, spellings: ["mètres par seconde", "mètre par seconde", "m/s"]),
    UnitDef(symbol: "km", dimension: .length, factor: 1000, spellings: ["kilomètres", "kilomètre", "km"]),
    UnitDef(symbol: "mi", dimension: .length, factor: 1609.344, spellings: ["miles", "mile"]),
    UnitDef(symbol: "m", dimension: .length, factor: 1, spellings: ["mètres", "mètre", "m"]),
    UnitDef(symbol: "cm", dimension: .length, factor: 0.01, spellings: ["centimètres", "centimètre", "cm"]),
    UnitDef(symbol: "ft", dimension: .length, factor: 0.3048, spellings: ["pieds", "pied", "ft"]),
    UnitDef(symbol: "yd", dimension: .length, factor: 0.9144, spellings: ["yards", "yard", "yd"]),
    UnitDef(symbol: "in", dimension: .length, factor: 0.0254, spellings: ["pouces", "pouce"]),
    UnitDef(symbol: "kg", dimension: .mass, factor: 1, spellings: ["kilogrammes", "kilogramme", "kilos", "kilo", "kg"]),
    UnitDef(symbol: "g", dimension: .mass, factor: 0.001, spellings: ["grammes", "gramme", "g"]),
    UnitDef(symbol: "t", dimension: .mass, factor: 1000, spellings: ["tonnes", "tonne", "t"]),
    UnitDef(symbol: "lb", dimension: .mass, factor: 0.45359237, spellings: ["livres", "livre", "lbs", "lb"]),
    UnitDef(symbol: "oz", dimension: .mass, factor: 0.028349523, spellings: ["onces", "once", "oz"]),
    UnitDef(symbol: "L", dimension: .volume, factor: 1, spellings: ["litres", "litre", "l"]),
    UnitDef(symbol: "mL", dimension: .volume, factor: 0.001, spellings: ["millilitres", "millilitre", "ml"]),
    UnitDef(symbol: "gal", dimension: .volume, factor: 3.785411784, spellings: ["gallons", "gallon", "gal"]),
]

private let unitAlternation = unitDefs.flatMap(\.spellings).map { NSRegularExpression.escapedPattern(for: $0) }.joined(separator: "|")
private let conversionIntent = Pattern(#"combien|convert|équival|conversion|exprim|(?:ça|cela) (?:fait|ferait|donne|donnerait|vaut|vaudrait)|en\s+\S+(?:\s+par\s+\S+)?\s*\?\s*$"#)
private let targetUnit = Pattern(#"(?<!\p{L})en\s+("# + unitAlternation + #")(?![\p{L}'’/])"#)
private let quantity = Pattern(#"(\d+(?:[.,]\d+)?)\s*("# + unitAlternation + #")(?![\p{L}/])"#)

private func unitDef(_ text: String) -> UnitDef? {
    let t = text.lowercased()
    return unitDefs.first { $0.spellings.contains(t) }
}

private func format(_ x: Double) -> String {
    let digits = abs(x) >= 100 ? 0 : abs(x) >= 1 ? 1 : 2
    var s = String(format: "%.\(digits)f", x).replacingOccurrences(of: ".", with: ",")
    if s.contains(",") { while s.hasSuffix("0") { s.removeLast() }; if s.hasSuffix(",") { s.removeLast() } }
    return s
}

/// Converts the values of the previous answer (or of the message) into the unit the learner asks for
/// ("et ça fait combien en miles par heure ?"). The arithmetic is done here, exactly: a model would have
/// to write numbers that are in no source, which the answer guard rightly refuses.
public func convertUnits(message: String, previousAnswer: String?) -> String? {
    guard conversionIntent.test(message),
          let targetText = targetUnit.matches(in: message, group: 1).first,
          let target = unitDef(targetText) else { return nil }
    var found: [(value: Double, unit: UnitDef)] = []
    for text in [message, previousAnswer ?? ""] {
        let numbers = quantity.matches(in: text, group: 1)
        let units = quantity.matches(in: text, group: 2)
        for (n, u) in zip(numbers, units) {
            guard let unit = unitDef(u), unit.dimension == target.dimension, unit.symbol != target.symbol,
                  let value = Double(n.replacingOccurrences(of: ",", with: ".")) else { continue }
            if !found.contains(where: { $0.value == value && $0.unit.symbol == unit.symbol }) { found.append((value, unit)) }
        }
        if !found.isEmpty { break }
    }
    guard !found.isEmpty else { return nil }
    let lines = found.prefix(4).map { "• \(format($0.value)) \($0.unit.symbol) ≈ \(format($0.value * $0.unit.factor / target.factor)) \(target.symbol)" }
    let first = found[0].unit
    let ratio = String(format: "%.4g", first.factor / target.factor).replacingOccurrences(of: ".", with: ",")
    return lines.joined(separator: "\n") + "\nConversion calculée par l’application (1 \(first.symbol) ≈ \(ratio) \(target.symbol)), à titre indicatif : les textes officiels israéliens emploient le système métrique."
}
