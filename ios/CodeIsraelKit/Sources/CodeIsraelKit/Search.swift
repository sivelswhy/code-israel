import Foundation

/// Okapi BM25 over any list of items, with synonym expansion and a bonus for covering every idea of the query.
struct Bm25<Item: Sendable>: Sendable {
    private struct Doc: Sendable {
        let item: Item
        let tf: [String: Int]
        let length: Int
    }

    private let docs: [Doc]
    private let df: [String: Int]
    private let average: Double
    private let boost: @Sendable (Item) -> Double

    init(_ items: [Item], text: (Item) -> String, boost: @escaping @Sendable (Item) -> Double = { _ in 1 }) {
        var df: [String: Int] = [:]
        docs = items.map { item in
            let words = tokens(text(item))
            var tf: [String: Int] = [:]
            for w in words { tf[w, default: 0] += 1 }
            for w in tf.keys { df[w, default: 0] += 1 }
            return Doc(item: item, tf: tf, length: words.count)
        }
        self.df = df
        average = Double(docs.reduce(0) { $0 + $1.length }) / Double(max(1, docs.count))
        self.boost = boost
    }

    /// `minCoverage`: share of the query's words (or their synonyms) a result must contain.
    func search(_ text: String, limit: Int, minCoverage: Double = 0) -> [(item: Item, score: Double)] {
        // Words typed by the user count fully; their synonyms count for a little less.
        let asked = tokens(text).uniqued()
        var terms: [(word: String, weight: Double)] = asked.map { ($0, 1) }
        var known = Set(asked)
        for t in asked {
            for x in groups[t] ?? [] where known.insert(x).inserted { terms.append((x, 0.5)) }
        }
        let n = Double(docs.count)
        var hits: [(item: Item, score: Double)] = []
        for d in docs {
            var score = 0.0
            for (t, weight) in terms {
                guard let f = d.tf[t].map(Double.init), let dft = df[t].map(Double.init) else { continue }
                let idf = log(1 + (n - dft + 0.5) / (dft + 0.5))
                score += (weight * (idf * f * 2.2)) / (f + 1.2 * (0.25 + 0.75 * (Double(d.length) / average)))
            }
            // A document covering every idea of the query (directly or through a synonym) beats one matching a single rare word.
            let coveredCount = asked.filter { t in d.tf[t] != nil || (groups[t] ?? []).contains { d.tf[$0] != nil } }.count
            let covered = Double(coveredCount) / Double(max(1, asked.count))
            if score > 0 && covered >= minCoverage {
                hits.append((d.item, score * (0.4 + covered) * boost(d.item)))
            }
        }
        return Array(hits.stableSorted(byDescending: \.score).prefix(limit))
    }
}

public struct QuestionHit: Sendable {
    public let question: Question
    public let score: Double
}

/// Search over the official questions: the question, its correct answer and the explanation describe
/// the rule (wrong answers would add noise); questions with a written explanation are preferred.
public struct QuestionIndex: Sendable {
    private let index: Bm25<Question>

    public init(_ questions: [Question]) {
        index = Bm25(questions, text: { "\($0.q) \($0.correct) \($0.e ?? "")" }, boost: { $0.e != nil ? 1.25 : 1 })
    }

    public func search(_ text: String, limit: Int = 4) -> [QuestionHit] {
        index.search(text, limit: limit).map { QuestionHit(question: $0.item, score: $0.score) }
    }
}

public struct LawHit: Sendable {
    public let excerpt: LawExcerpt
    public let score: Double
    public var ref: String { excerpt.ref }
}

/// Search over the French rendering of the traffic regulations, independent of the question bank.
public struct LawIndex: Sendable {
    private let index: Bm25<LawExcerpt>

    public init(_ law: [LawExcerpt]) {
        index = Bm25(law.filter { !($0.f ?? "").isEmpty }, text: { "\($0.l) \($0.f ?? "")" })
    }

    /// Only passages that cover most of the query words are returned, so unrelated articles stay out.
    public func search(_ text: String, limit: Int = 2) -> [LawHit] {
        // "How much / what limit / what age": the passage that actually states a figure answers it.
        let figure = asksFigure.test(text)
        let hits = index.search(text, limit: limit + 3, minCoverage: 0.6).map {
            LawHit(excerpt: $0.item, score: $0.score * (figure && hasFigure.test($0.item.f ?? "") ? 1.35 : 1))
        }
        return Array(hits.stableSorted(byDescending: \.score).prefix(limit))
    }
}

/// Article a reference belongs to: "T47(ה)(2)" and "T47(ב)" are both "T47".
func article(_ ref: String) -> String {
    String(ref.prefix { $0 != "(" && $0 != ":" })
}

/// Finds the best official questions and law passages for a query. A question whose legal reference is
/// in an article the law search also found is promoted, so the two sources agree on the same rule.
public func retrieve(_ questions: QuestionIndex, _ law: LawIndex, query: String, limit: Int = 4) -> (hits: [Question], lawHits: [LawHit]) {
    let lawHits = law.search(query)
    let articles = Set(lawHits.map { article($0.ref) })
    let hits = questions.search(query, limit: 12)
        .map { h in (h.question, h.score * ((h.question.r ?? []).contains { articles.contains(article($0)) } ? 1.6 : 1)) }
        .stableSorted(byDescending: \.1)
        .prefix(limit)
        .map(\.0)
    return (Array(hits), lawHits)
}
