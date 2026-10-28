import Foundation

// What the assistant may say: the sources given to the model, the guards applied to its answer and the
// answer composed without any model. Same rules as the web app (src/assistant/search.ts).

private let signNumber = Pattern(#"(?<![\d,.])(\d{3})(?![\d,.]|\s?(?:cm|km|kg|kw|ch\b|m\b|mètres|%|chevaux))"#)
private let mentionsSign = Pattern("panneau")

/// Sign numbers mentioned by a sign-related question, e.g. "432". A 3-digit number followed by a unit
/// (125 cm³, 120 km/h, 750 kg…) is a quantity, not a sign.
func citedSignNumbers(_ q: Question, signs: [String: Sign]) -> [String] {
    guard q.cat == .signs || mentionsSign.test(q.q) else { return [] }
    return signNumber.matches(in: ([q.q] + q.a).joined(separator: " "), group: 1).uniqued().filter { signs[$0] != nil }
}

/// True when the user names a kind of vehicle (motorcycle, tractor, bus…) that the best sources never
/// mention: they then describe another vehicle's rule, which must not be passed off as the answer.
public func vehicleMismatch(query: String, best: Question?, bestLaw: LawHit?) -> Bool {
    if best == nil && bestLaw == nil { return false }
    let text = "\(best?.q ?? "") \(best?.correct ?? "") \(best?.e ?? "") \(bestLaw?.excerpt.f ?? "")"
    return vehicleKinds.contains { $0.test(query) && !$0.test(text) }
}

private let anyNumber = Pattern(#"\d+(?:[.,]\d+)?"#)
private let citedArticle = Pattern(#"\bart(?:icle|\.)?\s*(\d+[A-Za-z]?)"#)
private let notFound = Pattern("je n['’]ai pas trouvé")
private let sentenceBreak = Pattern(#"(?<=[.!?])\s+|\n+"#)

/// True when a model answer cites a number, a sign or a law article that is in neither the sources nor
/// the question, or makes a claim whose words are not in the sources: a small model sometimes invents
/// them, and the answer must then not be shown.
public func unsupported(answer: String, sourceText: String, query: String) -> Bool {
    let known = "\(sourceText) \(query)"
    let numbers = anyNumber.matches(in: answer).contains { n in
        !Pattern(#"(?<![\d.,])"# + NSRegularExpression.escapedPattern(for: n) + #"(?!\d)"#).test(known)
    }
    let articles = citedArticle.matches(in: answer, group: 1).contains { n in
        !Pattern(#"art(?:icle|\.)?\s*"# + NSRegularExpression.escapedPattern(for: n) + #"(?![\dA-Za-z])"#).test(sourceText)
    }
    // Every sentence must rest on words of the sources: a claim made of other words was not read from them.
    let allowed = Set(tokens(known))
    let ungrounded = !notFound.test(answer) && sentenceBreak
        .replacing(in: answer, with: "\u{0}")
        .split(separator: "\u{0}")
        .map { tokens(String($0)) }
        .contains { t in t.count >= 4 && Double(t.filter(allowed.contains).count) / Double(t.count) < 0.6 }
    return numbers || articles || ungrounded
}

/// The label a model must put before an invented example, so the learner can tell it from the official texts.
public let exampleMarker = "Exemple imaginé"
private let inventedReference = Pattern(#"(?:art(?:icle|\.)?|panneau)\s*\d"#)
/// The label as a model may write it ("Exemple imaginé", sometimes "Example inventé"…).
let exampleLabel = Pattern(#"(?:exemple|example)\s+(?:imaginé|imaginée|imaginaire|inventé|inventée)\s*:?"#)

/// Like `unsupported`, for an answer that may contain an invented example (the learner asked for one, or
/// for an explanation "like to a child"). The rule before the label is held to the sources as usual. The
/// example after it is invented on purpose and may use figures of its own, but may not cite an article or a
/// sign number: that would pass for the law. Without the label, the whole answer is held to the sources.
public func unsupportedIllustrated(answer: String, sourceText: String, query: String) -> Bool {
    guard let label = exampleLabel.firstMatchRange(in: answer) else {
        return unsupported(answer: answer, sourceText: sourceText, query: query)
    }
    let rule = String(answer[..<label.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    // The rule comes first: an answer that opens with the example is not trusted.
    if rule.isEmpty { return unsupported(answer: answer, sourceText: sourceText, query: query) }
    if unsupported(answer: rule, sourceText: sourceText, query: query) { return true }
    return inventedReference.test(String(answer[label.upperBound...]))
}

/// Shortens a legal passage to `max` characters, keeping the lines that best match the query (a long
/// article lists many rules: the model should see the one that was asked about, not just the start).
func focusClip(_ text: String, query: String, max: Int) -> String {
    if text.count <= max { return text }
    let own = Set(tokens(query))
    let asked = own.union(own.flatMap { groups[$0] ?? [] })
    let lines = text.components(separatedBy: "\n")
    let figure = asksFigure.test(query)
    // A line about trucks, buses or tractors is not the answer for a question that names none of them.
    func otherKind(_ l: String) -> Bool { otherVehicles.test(l) && !otherVehicles.test(query) }
    // Distinct matching words, those typed by the user counting double; when the question asks for a
    // figure, lines stating one come first.
    func score(_ l: String) -> Int {
        Set(tokens(l)).reduce(0) { $0 + (own.contains($1) ? 2 : asked.contains($1) ? 1 : 0) }
            + (figure && hasFigure.test(l) ? 2 : 0) - (otherKind(l) ? 4 : 0)
    }
    // The first line introduces the list: keep it short so the matching items fit.
    let head = lines[0].count > 140 ? Pattern(#"\s+\S*$"#).replacing(in: String(lines[0].prefix(140)), with: "") + "…" : lines[0]
    var keep: [Int: String] = [0: head]
    var size = head.count
    let scores = lines.map(score)
    let ranked = lines.indices.filter { $0 > 0 && scores[$0] > 0 }.sorted { scores[$0] != scores[$1] ? scores[$0] > scores[$1] : $0 < $1 }
    for (n, i) in ranked.enumerated() {
        // The two best-matching lines are always kept, even if long; the others only while there is room.
        if n > 1 && size + lines[i].count + 1 > max { continue }
        keep[i] = lines[i]
        size += lines[i].count + 1
    }
    return keep.sorted { $0.key < $1.key }.map(\.value).joined(separator: "\n")
}

/// The grounding block given to the model: only official facts, our explanations and the law.
public func sources(hits: [Question], law: [String: LawExcerpt], focus: Question? = nil, signs: [String: Sign] = [:], lawHits: [LawHit] = [], query: String = "") -> String {
    func block(_ q: Question, detailed: Bool) -> String {
        var lines = ["[Question officielle n° \(q.id)] \(q.q)"]
        if detailed {
            lines.append("Réponses proposées : " + q.a.enumerated().map { "\(["A", "B", "C", "D"][$0.offset])) \($0.element)" }.joined(separator: " | "))
        }
        lines.append("Bonne réponse : \(q.correct)")
        if let e = q.e { lines.append("Explication : \(e)") }
        for n in detailed ? citedSignNumbers(q, signs: signs) : [] { lines.append("Panneau \(n) : \(signs[n]!.fr)") }
        for r in q.r ?? [] {
            guard let ex = law[r] else { continue }
            // A short French excerpt keeps the small context window of on-device models free.
            if detailed, let f = ex.f, !f.isEmpty {
                lines.append("\(ex.l) : \(focusClip(f, query: query.isEmpty ? q.q : query, max: 450))")
            } else {
                lines.append("Référence : \(ex.l)")
            }
        }
        return lines.joined(separator: "\n")
    }
    let rest = hits.filter { $0.id != focus?.id }.prefix(focus != nil ? 2 : 3)
    let cited = Set(hits.flatMap { $0.r ?? [] })
    let passages = lawHits.filter { !cited.contains($0.ref) }.map { "[Texte de loi] \($0.excerpt.l) : \(focusClip($0.excerpt.f ?? "", query: query, max: 450))" }
    return ((focus.map { [block($0, detailed: true)] } ?? []) + rest.map { block($0, detailed: focus == nil) } + passages).joined(separator: "\n\n")
}

/// Answer written without any language model about one question: the verified correct answer, our
/// explanation and the cited article.
public func compose(_ q: Question, law: [String: LawExcerpt], chosen: Int? = nil, kind: QuestionKind = .other) -> String {
    let right = trimEnd(q.correct)
    let lead: String
    if let chosen, chosen != q.c {
        lead = "Votre réponse « \(trimEnd(q.a[chosen])) » est fausse. La bonne réponse est « \(right) »."
    } else if kind == .remember {
        lead = "À retenir : « \(right) »."
    } else if kind == .why {
        lead = "La bonne réponse est « \(right) ». Voici pourquoi."
    } else {
        lead = "La bonne réponse est « \(right) »."
    }
    let label = (q.r ?? []).lazy.compactMap { law[$0]?.l }.first
    return [lead, q.e.map(sentence), label.map { "Référence : \($0)." }].compactMap { $0 }.joined(separator: " ")
}

private let leadingLabel = Pattern(#"^[^:]*:"#)

/// Answer to a free question without any language model: the best-matching official question presented
/// as a source (not as if the student had asked it), its explanation, the law, the meaning of cited
/// signs and the next best matches. With a focus question, explains that one.
public func reply(hits: [Question], law: [String: LawExcerpt], signs: [String: Sign], focus: Question? = nil, chosen: Int? = nil, lawHits: [LawHit] = [], query: String = "", message: String? = nil) -> String {
    guard let best = hits.first else { return "" }
    // `message` is what the learner typed, without the question in focus or the previous message.
    let kind = questionKind(message ?? (focus == nil ? query : ""))
    let others = hits.dropFirst()
    func label(_ q: Question) -> String? { (q.r ?? []).lazy.compactMap { law[$0]?.l }.first }
    func signLines(_ q: Question) -> [String] {
        citedSignNumbers(q, signs: signs).prefix(3).map { "Panneau \($0) : \(trimEnd(signs[$0]!.fr))." }
    }

    let head = focus != nil
        ? compose(best, law: law, chosen: chosen, kind: kind)
        : ["D'après la question officielle n° \(best.id) (« \(trimEnd(best.q)) ») : \(trimEnd(best.correct)).", best.e.map(sentence), label(best).map { "Référence : \($0)." }]
            .compactMap { $0 }.joined(separator: " ")
    var parts = [head] + signLines(best)

    let figure = asksFigure.test(query)
    func states(_ e: LawExcerpt?) -> Bool { hasFigure.test(e?.f ?? "") }
    // The wording of the law itself. A question asking for a figure is answered by the passage that
    // states it, which then comes first, unless the best question already gives the figure itself.
    var found = lawHits.prefix(2).map(\.excerpt)
    if figure { found = found.stableSorted(byDescending: { states($0) ? 1 : 0 }) }
    let figureFirst = figure && states(found.first) && best.correct.rangeOfCharacter(from: .decimalDigits) == nil
    let own = (best.r ?? []).lazy.compactMap { law[$0] }.first { !($0.f ?? "").isEmpty }
    let sameArticle = found.isEmpty || lawHits.contains { h in (best.r ?? []).contains { article($0) == article(h.ref) } }
    // Law passages about another article than the best question's are probably noise: trust the question's own.
    let useOwn = !sameArticle && own != nil
    let passages = useOwn ? [own!] : !found.isEmpty ? found : own.map { [$0] } ?? []
    let agrees = sameArticle || useOwn
    var lawLines = passages.map { "Texte de loi — \($0.l) : \(focusClip($0.f ?? "", query: query, max: 360))" }
    // What is actually displayed decides the order: the visible passage that states the figure comes first.
    if figure { lawLines = lawLines.stableSorted(byDescending: { hasFigure.test(leadingLabel.replacing(in: $0, with: "")) ? 1 : 0 }) }
    if agrees && !(figureFirst && !useOwn) { parts += lawLines } else { parts = lawLines + parts }

    let more = others.prefix(2)
    if !more.isEmpty {
        parts.append("À voir aussi :")
        for q in more { parts.append("• n° \(q.id) — \(trimEnd(q.q)) → \(trimEnd(q.correct)).\(label(q).map { " (\($0))" } ?? "")") }
    }
    return parts.joined(separator: "\n")
}
