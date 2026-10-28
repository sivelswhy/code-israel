import XCTest
@testable import CodeIsraelKit

final class JourneyTests: XCTestCase {
    private var pool: [Question] { ParityTests.library.pool(for: .B) }

    func testPathCoversEveryQuestionOnceInLessonsOfTheRightSize() {
        let path = LearningPath(pool: pool)
        XCTAssertEqual(path.units.map(\.category), Category.allCases)
        var seen = Set<String>()
        for unit in path.units {
            for lesson in unit.lessons {
                XCTAssertGreaterThanOrEqual(lesson.questionIDs.count, JourneyRules.minimumLessonSize, lesson.id)
                XCTAssertLessThan(lesson.questionIDs.count, JourneyRules.lessonSize + JourneyRules.minimumLessonSize, lesson.id)
                for id in lesson.questionIDs { XCTAssertTrue(seen.insert(id).inserted, "\(id) is in two lessons") }
            }
            XCTAssertEqual(unit.lessons.map(\.number), Array(1...unit.lessons.count))
        }
        XCTAssertEqual(seen, Set(pool.map(\.id)))
        // The same pool always gives the same path.
        XCTAssertEqual(LearningPath(pool: pool).units.map { $0.lessons.map(\.questionIDs) }, path.units.map { $0.lessons.map(\.questionIDs) })
    }

    func testWrongQuestionsComeBackUntilRight() {
        var s = LessonSession(questionIDs: ["a", "b", "c"])
        XCTAssertEqual(s.current, "a")
        XCTAssertTrue(s.isFirstAttempt)
        s.submit(correct: false)            // a wrong: goes to the end
        XCTAssertEqual(s.queue, ["b", "c", "a"])
        XCTAssertEqual(s.progress, 0)
        s.submit(correct: true)             // b
        s.submit(correct: true)             // c
        XCTAssertEqual(s.current, "a")
        XCTAssertFalse(s.isFirstAttempt, "a was already answered once")
        s.submit(correct: false)            // a wrong again
        XCTAssertFalse(s.isFinished)
        s.submit(correct: true)             // a right at last
        XCTAssertTrue(s.isFinished)
        XCTAssertEqual(s.progress, 1)
        let o = s.outcome()
        XCTAssertEqual(o.mistakes, 2)
        XCTAssertEqual(o.firstTry, 2)
        XCTAssertFalse(o.perfect)
        XCTAssertEqual(o.firstTryByQuestion, ["a": false, "b": true, "c": true])
        // 2 right at once, 1 after a retry, plus the lesson bonus.
        XCTAssertEqual(o.xp, 2 * JourneyRules.xpFirstTry + JourneyRules.xpRetry + JourneyRules.xpLessonBonus)
        XCTAssertEqual(o.stars, 1, "67 % at the first try")
    }

    func testPerfectLessonAndStars() {
        var s = LessonSession(questionIDs: (1...8).map(String.init))
        while !s.isFinished { s.submit(correct: true) }
        let o = s.outcome()
        XCTAssertTrue(o.perfect)
        XCTAssertEqual(o.stars, 3)
        XCTAssertEqual(o.xp, 8 * JourneyRules.xpFirstTry + JourneyRules.xpLessonBonus + JourneyRules.xpPerfectBonus)
        XCTAssertEqual(s.outcome(bonus: false).xp, 8 * JourneyRules.xpFirstTry, "a review has no completion bonus")

        var two = LessonSession(questionIDs: (1...8).map(String.init))
        for i in 0..<8 { two.submit(correct: i != 0 && i != 1) }   // 2 wrong of 8: 75 %
        while !two.isFinished { two.submit(correct: true) }
        XCTAssertEqual(two.outcome().stars, 2)
    }

    func testLessonsUnlockOneAfterAnother() {
        let unit = LearningPath(pool: pool).unit(.rules)!
        var j = JourneyProgress()
        XCTAssertTrue(j.isUnlocked(unit.lessons[0], in: unit))
        XCTAssertFalse(j.isUnlocked(unit.lessons[1], in: unit))
        XCTAssertEqual(j.currentLesson(in: unit), unit.lessons[0])

        var s = LessonSession(questionIDs: unit.lessons[0].questionIDs)
        while !s.isFinished { s.submit(correct: true) }
        let when = Date(timeIntervalSince1970: 1_800_000_000)
        j.finish(lesson: unit.lessons[0], outcome: s.outcome(), on: when)
        XCTAssertTrue(j.isUnlocked(unit.lessons[1], in: unit))
        XCTAssertFalse(j.isUnlocked(unit.lessons[2], in: unit))
        XCTAssertEqual(j.currentLesson(in: unit), unit.lessons[1])
        XCTAssertEqual(j.completedCount(in: unit), 1)
        XCTAssertEqual(j.lessons[unit.lessons[0].id]?.stars, 3)
        XCTAssertEqual(j.xp, s.outcome().xp)
        XCTAssertEqual(j.xpToday(when), j.xp)
        // Playing it again keeps the best stars.
        var worse = LessonSession(questionIDs: unit.lessons[0].questionIDs)
        for _ in 0..<worse.total { worse.submit(correct: false) }
        while !worse.isFinished { worse.submit(correct: true) }
        j.finish(lesson: unit.lessons[0], outcome: worse.outcome(), on: when)
        XCTAssertEqual(j.lessons[unit.lessons[0].id]?.stars, 3)
        XCTAssertEqual(j.lessons[unit.lessons[0].id]?.completions, 2)
    }

    func testSpacedReviewBringsMistakesBackSooner() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        let day0 = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 12))!
        func later(_ d: Int) -> Date { calendar.date(byAdding: .day, value: d, to: day0)! }

        var j = JourneyProgress()
        var s = LessonSession(questionIDs: ["right", "wrong"])
        s.submit(correct: true)
        s.submit(correct: false)
        s.submit(correct: true)
        j.finish(lesson: nil, outcome: s.outcome(bonus: false), on: day0, calendar: calendar)
        XCTAssertEqual(j.review["right"]?.box, 1)
        XCTAssertEqual(j.review["wrong"]?.box, 0)
        XCTAssertEqual(j.dueQuestionIDs(day0, calendar: calendar), [], "nothing is due the day it was learned")
        XCTAssertEqual(j.dueQuestionIDs(later(1), calendar: calendar), ["wrong"], "a mistake comes back the next day")
        XCTAssertEqual(j.dueQuestionIDs(later(2), calendar: calendar), ["wrong", "right"], "the other after two days, the most overdue first")

        // Right again at the first try: it moves up a box and waits longer.
        var again = LessonSession(questionIDs: ["right"])
        again.submit(correct: true)
        j.finish(lesson: nil, outcome: again.outcome(bonus: false), on: later(2), calendar: calendar)
        XCTAssertEqual(j.review["right"]?.box, 2)
        XCTAssertFalse(j.dueQuestionIDs(later(5), calendar: calendar).contains("right"))
        XCTAssertTrue(j.dueQuestionIDs(later(6), calendar: calendar).contains("right"))
    }

    func testJourneyIsSavedWithProgressAndOldSavesStillLoad() throws {
        var p = Progress()
        p.journey.finish(lesson: nil, outcome: { var s = LessonSession(questionIDs: ["x"]); s.submit(correct: true); return s.outcome() }())
        let back = try JSONDecoder().decode(Progress.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back.journey.xp, p.journey.xp)
        XCTAssertEqual(back.journey.review["x"]?.box, 1)
        let old = #"{"license":"B","stats":{},"exams":[],"daily":{}}"#
        let loaded = try JSONDecoder().decode(Progress.self, from: Data(old.utf8))
        XCTAssertEqual(loaded.journey.xp, 0)
        XCTAssertEqual(JourneyProgress().level, 1)
        var rich = JourneyProgress(); rich.xp = 250
        XCTAssertEqual(rich.level, 3)
        XCTAssertEqual(rich.xpInLevel, 50)
    }
}
