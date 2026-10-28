import XCTest
@testable import CodeIsraelKit

final class LogicTests: XCTestCase {
    func testExamKeepsCategorySharesAndSize() {
        let pool = ParityTests.library.pool(for: .B)
        var rng = SplitMix(seed: 42)
        let exam = drawExam(pool, using: &rng)
        XCTAssertEqual(exam.count, ExamRules.size)
        XCTAssertEqual(Set(exam.map(\.id)).count, ExamRules.size, "no question twice")
        for cat in Category.allCases {
            let expected = Double(pool.filter { $0.cat == cat }.count) / Double(pool.count) * Double(ExamRules.size)
            XCTAssertLessThanOrEqual(abs(Double(exam.filter { $0.cat == cat }.count) - expected), 1, cat.rawValue)
        }
    }

    func testProgressRecordsAndStreak() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        let today = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 10))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        var p = Progress()
        p.record("0001", ok: false, on: yesterday, calendar: calendar)
        p.record("0001", ok: true, on: today, calendar: calendar)
        p.record("0002", ok: false, on: today, calendar: calendar)
        XCTAssertEqual(p.stats["0001"], Stat(ok: 1, ko: 1, last: true))
        XCTAssertEqual(p.answeredToday(today, calendar: calendar), 2)
        XCTAssertEqual(p.streak(today, calendar: calendar), 2)
        // Nothing yet today: yesterday's streak still counts until tonight.
        XCTAssertEqual(p.streak(calendar.date(byAdding: .day, value: 1, to: today)!, calendar: calendar), 2)
        XCTAssertEqual(p.streak(calendar.date(byAdding: .day, value: 2, to: today)!, calendar: calendar), 0)
    }

    func testFavoritesAndExamReview() throws {
        var p = Progress()
        p.toggleFavorite("0007")
        p.toggleFavorite("0009")
        p.toggleFavorite("0007")
        XCTAssertEqual(p.favorites, ["0009"])

        for n in 0..<(Progress.reviewableExams + 2) {
            p.addExam(ExamRecord(date: Date(timeIntervalSince1970: Double(n)), errors: n, license: .B, ids: ["0001", "0002"], answers: [0, nil]))
        }
        XCTAssertEqual(p.exams.count, Progress.reviewableExams + 2)
        XCTAssertFalse(p.exams[0].canReview, "oldest exams keep their score only")
        XCTAssertTrue(p.exams.last!.canReview)

        // Saved data round-trips, unanswered questions included, and an old save without the new fields still loads.
        let back = try JSONDecoder().decode(Progress.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back.exams.last?.answers?.count, 2)
        XCTAssertNil(back.exams.last?.answers?[1] ?? nil)
        XCTAssertEqual(back.favorites, ["0009"])
        let old = #"{"license":"B","stats":{},"exams":[{"date":0,"errors":2,"license":"B"}],"daily":{}}"#
        let loaded = try JSONDecoder().decode(Progress.self, from: Data(old.utf8))
        XCTAssertEqual(loaded.exams.count, 1)
        XCTAssertFalse(loaded.exams[0].canReview)
    }

    func testAskingAboutAQuestionNeedsNoPreviousMessage() {
        let library = ParityTests.library
        let pool = library.pool(for: .B)
        let brain = AssistantBrain(pool: pool, law: library.law, signs: library.signs)
        let q = pool[0]
        // The assistant opened from a question: first message, so nothing came before it.
        for chosen in [nil, q.c, (q.c + 1) % q.a.count] {
            let turn = brain.turn(for: "Pourquoi ?", previous: nil, topic: AssistantTopic(question: q, chosen: chosen))
            XCTAssertEqual(turn.prompt.hasPrefix("Pourquoi ?"), true)
            XCTAssertFalse(turn.prompt.contains("(suite)"))
        }
        // With a question in focus, an earlier message is not glued to the prompt either.
        let again = brain.turn(for: "Et alors ?", previous: "Pourquoi ?", topic: AssistantTopic(question: q))
        XCTAssertFalse(again.prompt.contains("(suite)"))
        // A follow-up without a question in focus still carries the previous question.
        let followUp = brain.turn(for: "et pour 90 ?", previous: "Quelle est la vitesse maximale ?", topic: nil)
        XCTAssertTrue(followUp.prompt.contains("(suite)"))
    }

    func testOnHoldLicenseFallsBack() throws {
        let saved = #"{"license":"C","stats":{},"exams":[],"daily":{}}"#
        XCTAssertEqual(try JSONDecoder().decode(Progress.self, from: Data(saved.utf8)).license, .B)
    }

    func testThinkingBlocksAreHidden() {
        XCTAssertEqual(visibleAnswer("<think>\n\n</think>\n\nLa vitesse est de 50 km/h."), "La vitesse est de 50 km/h.")
        XCTAssertEqual(visibleAnswer("<think>je réfléchis"), "")
        XCTAssertEqual(visibleAnswer("La vitesse <thi"), "La vitesse ")
        XCTAssertEqual(visibleAnswer("Moins de 3 < 5 ans"), "Moins de 3 < 5 ans")
    }

    func testFollowUpUsesPreviousQuestion() {
        let library = ParityTests.library
        let brain = AssistantBrain(pool: library.pool(for: .B), law: library.law, signs: library.signs)
        XCTAssertEqual(brain.turn(for: "et pour une moto ?", previous: "vitesse max en ville", topic: nil).query, "vitesse max en ville et pour une moto ?")
        XCTAssertEqual(brain.turn(for: "c'est quoi l'équipement obligatoire", previous: "vitesse max en ville", topic: nil).query, "c'est quoi l'équipement obligatoire")
        let none = brain.turn(for: "la capitale de la France", previous: nil, topic: nil)
        XCTAssertFalse(none.canUseModel)
        XCTAssertEqual(none.direct, "")
    }

    func testSignAnswers() {
        let library = ParityTests.library
        let signs = Dictionary(library.signs.map { ($0.n, $0) }, uniquingKeysWith: { a, _ in a })
        let q = Question(id: "x", q: "Que signifie ce panneau ?", a: ["432", "125 km", "302.", "abc"], c: 0, lic: ["B"], cat: .signs)
        XCTAssertEqual(q.a.map { q.sign(inAnswer: $0, signs: signs) }, ["432", nil, "302", nil])
    }
}

/// Deterministic generator for tests.
struct SplitMix: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
