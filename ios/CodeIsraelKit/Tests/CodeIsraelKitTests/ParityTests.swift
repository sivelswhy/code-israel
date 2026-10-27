import XCTest
@testable import CodeIsraelKit

/// The Swift engine must answer exactly like the web app: `Fixtures/parity.json` holds the web app's
/// results (src/assistant/search.ts) for real learner questions, regenerated whenever the engine changes.
final class ParityTests: XCTestCase {
    struct Fixture: Decodable {
        struct Case: Decodable {
            let lic: String
            let query: String
            let focus: String?
            let chosen: Int?
            let hits: [String]
            let law: [String]
            let mismatch: Bool?
            let reply: String
            let sources: String
        }
        struct Tokens: Decodable {
            let text: String
            let tokens: [String]
        }
        struct Unsupported: Decodable {
            let query: String
            let answer: String
            let sourceText: String
            let unsupported: Bool
        }
        let cases: [Case]
        let tokens: [Tokens]
        let unsupported: [Unsupported]
    }

    static let data = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../../../App/Resources/Data").standardized
    static let library = try! Library(directory: data)
    static let fixture: Fixture = {
        let url = Bundle.module.url(forResource: "parity", withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }()

    func testTokens() {
        for t in Self.fixture.tokens {
            XCTAssertEqual(tokens(t.text), t.tokens, t.text)
        }
    }

    func testRetrievalAndAnswers() {
        let library = Self.library
        let law = Dictionary(library.law.map { ($0.ref, $0) }, uniquingKeysWith: { a, _ in a })
        let signs = Dictionary(library.signs.map { ($0.n, $0) }, uniquingKeysWith: { a, _ in a })
        let byId = Dictionary(library.questions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let lawIndex = LawIndex(library.law)
        var indexes: [String: QuestionIndex] = [:]
        for c in Self.fixture.cases {
            let index = indexes[c.lic] ?? QuestionIndex(library.pool(for: License(rawValue: c.lic)!))
            indexes[c.lic] = index
            let found = retrieve(index, lawIndex, query: c.query)
            XCTAssertEqual(found.lawHits.map(\.ref), c.law, "law: \(c.lic) \(c.query)")
            if let id = c.focus {
                let focus = byId[id]!
                let shown = Array(([focus] + found.hits.filter { $0.id != id }).prefix(4))
                XCTAssertEqual(shown.map(\.id), c.hits, "hits: \(c.lic) \(c.query)")
                XCTAssertEqual(reply(hits: shown, law: law, signs: signs, focus: focus, chosen: c.chosen, lawHits: found.lawHits, query: c.query), c.reply)
                XCTAssertEqual(sources(hits: shown, law: law, focus: focus, signs: signs, lawHits: found.lawHits, query: c.query), c.sources)
            } else {
                XCTAssertEqual(found.hits.map(\.id), c.hits, "hits: \(c.lic) \(c.query)")
                XCTAssertEqual(vehicleMismatch(query: c.query, best: found.hits.first, bestLaw: found.lawHits.first), c.mismatch, c.query)
                XCTAssertEqual(reply(hits: found.hits, law: law, signs: signs, lawHits: found.lawHits, query: c.query), c.reply, "reply: \(c.lic) \(c.query)")
                XCTAssertEqual(sources(hits: found.hits, law: law, signs: signs, lawHits: found.lawHits, query: c.query), c.sources, "sources: \(c.lic) \(c.query)")
            }
        }
    }

    func testAnswerGuards() {
        for u in Self.fixture.unsupported {
            XCTAssertEqual(unsupported(answer: u.answer, sourceText: u.sourceText, query: u.query), u.unsupported, "\(u.query) → \(u.answer)")
        }
    }
}
