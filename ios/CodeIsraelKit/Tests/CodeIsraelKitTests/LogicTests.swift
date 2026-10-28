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

    func testPersonalNoteUsesTheLearnersResults() {
        let library = ParityTests.library
        let pool = library.pool(for: .B)
        let q = pool[0]
        let topic = AssistantTopic(question: q)

        // Nothing known yet: no remark.
        XCTAssertNil(personalNote(topic: topic, hits: [], learner: LearnerContext(stats: [:], pool: pool)))

        // A question missed again and again.
        let missed = LearnerContext(stats: [q.id: Stat(ok: 1, ko: 3, last: false)], pool: pool)
        XCTAssertEqual(personalNote(topic: topic, hits: [], learner: missed)?.contains("3 fois"), true)

        // A question always right.
        let easy = LearnerContext(stats: [q.id: Stat(ok: 3, ko: 0, last: true)], pool: pool)
        XCTAssertEqual(personalNote(topic: topic, hits: [], learner: easy)?.contains("consolider"), true)

        // A weak theme is named only when there are enough answers and the rate is under 60 %.
        let sameTheme = pool.filter { $0.cat == q.cat }
        var stats: [String: Stat] = [:]
        for other in sameTheme.prefix(5) { stats[other.id] = Stat(ok: 1, ko: 1, last: false) }
        let weak = personalNote(topic: nil, hits: [q], learner: LearnerContext(stats: stats, pool: pool))
        XCTAssertEqual(weak?.contains(q.cat.label), true)
        XCTAssertEqual(weak?.contains("50 %"), true)
        // Too few answers, or a good rate: nothing to say.
        XCTAssertNil(personalNote(topic: nil, hits: [q], learner: LearnerContext(stats: [sameTheme[0].id: Stat(ok: 0, ko: 3, last: false)], pool: pool)))
        for other in sameTheme.prefix(5) { stats[other.id] = Stat(ok: 4, ko: 1, last: true) }
        XCTAssertNil(personalNote(topic: nil, hits: [q], learner: LearnerContext(stats: stats, pool: pool)))

        // Through the assistant: the note reaches the turn, and the composed answer is untouched.
        let brain = AssistantBrain(pool: pool, law: library.law, signs: library.signs)
        let withNote = brain.turn(for: "Pourquoi ?", previous: nil, topic: topic, learner: missed)
        let without = brain.turn(for: "Pourquoi ?", previous: nil, topic: topic)
        XCTAssertNotNil(withNote.note)
        XCTAssertNil(without.note)
        XCTAssertEqual(withNote.direct, without.direct)
    }

    func testQuestionKindsAndTidyAnswer() {
        XCTAssertEqual(questionKind("Pourquoi on ne dépasse pas par la droite ?"), .why)
        XCTAssertEqual(questionKind("C'est quoi la vitesse max en ville ?"), .figure, "a figure, not a definition")
        XCTAssertEqual(questionKind("Je peux téléphoner en conduisant ?"), .permission)
        XCTAssertEqual(questionKind("Donne-moi un moyen simple de retenir cette règle."), .remember)
        XCTAssertEqual(questionKind("Qui doit céder le passage ?"), .who)
        XCTAssertEqual(questionKind("Bonjour"), .other)

        let quote = "Règlement de la circulation, art. 54 : (a) " + String(repeating: "Nul ne conduira un véhicule. ", count: 8)
        let tidy = tidyAnswer("La vitesse maximale en ville est de 50 km/h.\n" + quote)
        XCTAssertEqual(tidy, "La vitesse maximale en ville est de 50 km/h.\nRéférence : Règlement de la circulation, art. 54.")
        // A short reference line and a plain sentence are left alone.
        let short = "Règlement de la circulation, art. 54(a) : 50 km/h."
        XCTAssertEqual(tidyAnswer(short), short)
    }

    func testUnitConversionIsExact() {
        let previous = "La vitesse maximale en ville est de 50 km/h ; hors agglomération, 80 km/h."
        let mph = convertUnits(message: "Et ça fait combien en miles par heure ?", previousAnswer: previous)
        XCTAssertEqual(mph?.contains("• 50 km/h ≈ 31,1 mph"), true, mph ?? "nil")
        XCTAssertEqual(mph?.contains("• 80 km/h ≈ 49,7 mph"), true)
        XCTAssertEqual(convertUnits(message: "ça ferait combien en m/s ?", previousAnswer: "50 km/h")?.contains("13,9 m/s"), true)
        XCTAssertEqual(convertUnits(message: "combien ça fait en livres ?", previousAnswer: "Le poids maximal est de 3,5 tonnes.")?.contains("• 3,5 t ≈ 7716 lb"), true)
        XCTAssertEqual(convertUnits(message: "combien en pieds ?", previousAnswer: "à 2 m du passage piéton")?.contains("• 2 m ≈ 6,6 ft"), true)
        // The value can be in the message itself.
        XCTAssertEqual(convertUnits(message: "100 km/h ça fait combien en mph ?", previousAnswer: nil)?.contains("• 100 km/h ≈ 62,1 mph"), true)
        // Not a conversion, or nothing to convert: left to the assistant.
        XCTAssertNil(convertUnits(message: "Quelle est la vitesse maximale en ville ?", previousAnswer: previous))
        XCTAssertNil(convertUnits(message: "ça fait combien en miles ?", previousAnswer: "Il faut un permis valide."))
        XCTAssertNil(convertUnits(message: "combien en mètres ?", previousAnswer: "50 km/h"), "a speed is not a length")
    }

    func testFollowUpKeepsThePreviousSources() {
        let library = ParityTests.library
        let pool = library.pool(for: .B)
        let brain = AssistantBrain(pool: pool, law: library.law, signs: library.signs)
        let first = brain.turn(for: "Quelle est la vitesse maximale en ville ?", previous: nil, topic: nil)
        XCTAssertTrue(first.canUseModel)
        let carry = AssistantCarry(sourceText: first.sourceText, hits: first.hits, answer: first.direct)

        // A unit conversion is answered by the app, with no model, from the previous answer.
        let converted = brain.turn(for: "Et ça fait combien en miles par heure ?", previous: "Quelle est la vitesse maximale en ville ?", topic: nil, carry: carry)
        XCTAssertTrue(converted.exact)
        XCTAssertFalse(converted.canUseModel)
        XCTAssertTrue(converted.direct.contains("mph"))

        // A request to rephrase has nothing to search for: it reuses the previous sources and answer.
        let again = brain.turn(for: "Explique-moi ça plus simplement", previous: "Quelle est la vitesse maximale en ville ?", topic: nil, carry: carry)
        XCTAssertTrue(again.canUseModel)
        XCTAssertEqual(again.sourceText.hasPrefix(first.sourceText), true)
        XCTAssertEqual(again.previousAnswer, first.direct)
        XCTAssertTrue(AssistantPrompt.user(question: again.prompt, sources: again.sourceText, previousAnswer: again.previousAnswer).contains("TA RÉPONSE PRÉCÉDENTE"))
        // Without a previous answer the same message finds nothing, as before.
        XCTAssertFalse(brain.turn(for: "Explique-moi ça plus simplement", previous: nil, topic: nil).canUseModel)
        // A new subject is searched normally even if it contains "ça".
        let fresh = brain.turn(for: "ça veut dire quoi le panneau stop ?", previous: "Quelle est la vitesse maximale en ville ?", topic: nil, carry: carry)
        XCTAssertFalse(fresh.exact)
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
