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
        XCTAssertEqual(j.review["right"]?.halfLife, 2)
        XCTAssertEqual(j.review["wrong"]?.halfLife, 1)
        XCTAssertEqual(j.dueQuestionIDs(day0, calendar: calendar), [], "nothing is due the day it was learned")
        XCTAssertEqual(j.dueQuestionIDs(later(1), calendar: calendar), ["wrong"], "a mistake comes back the next day")
        XCTAssertEqual(j.dueQuestionIDs(later(2), calendar: calendar), ["wrong", "right"], "the other after two days, the most overdue first")

        // Right again at the first try: its half-life doubles and it waits longer.
        var again = LessonSession(questionIDs: ["right"])
        again.submit(correct: true)
        j.finish(lesson: nil, outcome: again.outcome(bonus: false), on: later(2), calendar: calendar)
        XCTAssertEqual(j.review["right"]?.halfLife, 4)
        XCTAssertFalse(j.dueQuestionIDs(later(4), calendar: calendar).contains("right"))
        XCTAssertTrue(j.dueQuestionIDs(later(5), calendar: calendar).contains("right"))
    }

    func testJourneyIsSavedWithProgressAndOldSavesStillLoad() throws {
        var p = Progress()
        p.journey.finish(lesson: nil, outcome: { var s = LessonSession(questionIDs: ["x"]); s.submit(correct: true); return s.outcome() }())
        let back = try JSONDecoder().decode(Progress.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back.journey.xp, p.journey.xp)
        XCTAssertEqual(back.journey.review["x"]?.halfLife, 2)
        let old = #"{"license":"B","stats":{},"exams":[],"daily":{}}"#
        let loaded = try JSONDecoder().decode(Progress.self, from: Data(old.utf8))
        XCTAssertEqual(loaded.journey.xp, 0)
        XCTAssertEqual(JourneyProgress().level, 1)
        var rich = JourneyProgress(); rich.xp = 250
        XCTAssertEqual(rich.level, 3)
        XCTAssertEqual(rich.xpInLevel, 50)
    }

    private var jerusalem: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        return c
    }

    private func at(_ d: Int, hour: Int = 12) -> Date {
        jerusalem.date(from: DateComponents(year: 2026, month: 10, day: d, hour: hour))!
    }

    func testRecallFollowsTheHalfLife() {
        let s = ReviewState(halfLife: 4, last: "2026-10-01")
        XCTAssertEqual(s.recall(afterDays: 0), 1, accuracy: 1e-9)
        XCTAssertEqual(s.recall(afterDays: 4), 0.5, accuracy: 1e-9)
        XCTAssertEqual(s.recall(afterDays: 8), 0.25, accuracy: 1e-9)
        var j = JourneyProgress()
        j.review["q"] = s
        XCTAssertEqual(j.recall("q", on: at(5), calendar: jerusalem)!, 0.5, accuracy: 1e-9)
        XCTAssertEqual(j.memoryStrength(on: at(5), calendar: jerusalem)!, 0.5, accuracy: 1e-9)
        // An old save (box and due day) still loads and is reviewed from its due day.
        let old = try! JSONDecoder().decode(ReviewState.self, from: Data(#"{"box":2,"due":"2026-10-03"}"#.utf8))
        XCTAssertEqual(old.last, "2026-10-03")
    }

    func testSpeedBonusNeedsFastAndAccurateAnswers() {
        var fast = LessonSession(questionIDs: ["a", "b", "c", "d"])
        while !fast.isFinished { fast.submit(correct: true, seconds: 5) }
        XCTAssertTrue(fast.outcome().speedBonus)
        XCTAssertEqual(fast.outcome().xp, 4 * JourneyRules.xpFirstTry + JourneyRules.xpLessonBonus + JourneyRules.xpPerfectBonus + JourneyRules.xpSpeedBonus)
        var slow = LessonSession(questionIDs: ["a", "b", "c", "d"])
        while !slow.isFinished { slow.submit(correct: true, seconds: 30) }
        XCTAssertFalse(slow.outcome().speedBonus)
        var untimed = LessonSession(questionIDs: ["a"])
        untimed.submit(correct: true)
        XCTAssertFalse(untimed.outcome().speedBonus)
        XCTAssertFalse(fast.outcome(bonus: false).speedBonus, "a review has no bonus")
    }

    func testBestRunAndGold() {
        var s = LessonSession(questionIDs: ["a", "b", "c", "d"])
        s.submit(correct: true); s.submit(correct: true); s.submit(correct: false); s.submit(correct: true)
        XCTAssertEqual(s.bestRun, 2)
        XCTAssertTrue(LessonResult(stars: 3, completions: 1).isGold)
        XCTAssertFalse(LessonResult(stars: 2, completions: 5).isGold)
    }

    func testStreakFreezeSavesAMissedDay() {
        var p = Progress()
        for d in [24, 25, 26] { p.daily[Progress.day(at(d), calendar: jerusalem)] = 3 }
        p.journey.freezes = 1
        XCTAssertEqual(p.streak(at(27), calendar: jerusalem), 3, "yesterday still counts")
        // On the 28th the 27th was missed: the freeze covers it.
        XCTAssertEqual(p.streak(at(28), calendar: jerusalem), 0)
        XCTAssertEqual(p.applyStreakFreezes(at(28), calendar: jerusalem), 1)
        XCTAssertEqual(p.journey.freezes, 0)
        XCTAssertEqual(p.streak(at(28), calendar: jerusalem), 3, "the frozen day keeps the streak without adding to it")
        p.daily[Progress.day(at(28), calendar: jerusalem)] = 2
        XCTAssertEqual(p.streak(at(28), calendar: jerusalem), 4)
        XCTAssertEqual(p.applyStreakFreezes(at(28), calendar: jerusalem), 0, "nothing more to save")

        // Two missed days with a single freeze: the streak is lost anyway, so the freeze is kept.
        var q = Progress()
        q.daily[Progress.day(at(20), calendar: jerusalem)] = 3
        q.journey.freezes = 1
        XCTAssertEqual(q.applyStreakFreezes(at(23), calendar: jerusalem), 0)
        XCTAssertEqual(q.journey.freezes, 1)
        // No past practice: nothing to protect.
        var empty = Progress(); empty.journey.freezes = 2
        XCTAssertEqual(empty.applyStreakFreezes(at(23), calendar: jerusalem), 0)
    }

    func testQuestsChestAndFreezeReward() {
        var j = JourneyProgress()
        let day = at(28)
        let quests = j.quests(on: day, calendar: jerusalem)
        XCTAssertEqual(quests.count, 3)
        XCTAssertEqual(Set(quests).count, 3)
        XCTAssertEqual(quests, j.quests(on: day, calendar: jerusalem), "the same quests all day")
        XCTAssertFalse(j.claim(quests[0], on: day, calendar: jerusalem), "not done yet")
        XCTAssertFalse(j.canOpenChest(on: day, calendar: jerusalem))

        // A perfect lesson of 8, fast, then a review: enough for every kind of quest except the XP one maybe.
        var lesson = LessonSession(questionIDs: (1...8).map(String.init))
        while !lesson.isFinished { lesson.submit(correct: true, seconds: 3) }
        let unit = LearningPath(pool: pool).unit(.rules)!
        j.finish(lesson: unit.lessons[0], outcome: lesson.outcome(), on: day, calendar: jerusalem)
        j.finish(lesson: unit.lessons[1], outcome: lesson.outcome(), on: day, calendar: jerusalem)
        var review = LessonSession(questionIDs: ["a"]); review.submit(correct: true)
        j.finish(lesson: nil, outcome: review.outcome(bonus: false), on: day, calendar: jerusalem)
        for kind in quests {
            XCTAssertTrue(j.isDone(kind, on: day, calendar: jerusalem), "\(kind)")
        }
        let before = j.xp
        for kind in quests { XCTAssertTrue(j.claim(kind, on: day, calendar: jerusalem)) }
        XCTAssertFalse(j.claim(quests[0], on: day, calendar: jerusalem), "only once")
        XCTAssertEqual(j.xp, before + 3 * JourneyRules.questXP)
        XCTAssertEqual(j.xpToday(day, calendar: jerusalem), j.xp)

        XCTAssertTrue(j.canOpenChest(on: day, calendar: jerusalem))
        XCTAssertEqual(j.openChest(on: day, calendar: jerusalem), ChestReward(xp: JourneyRules.chestXP, freeze: false))
        XCTAssertNil(j.openChest(on: day, calendar: jerusalem), "one chest a day")
        // The third chest also holds a streak freeze.
        j.chestsOpened = 2
        let next = at(29)
        var counters = DayCounters(day: Progress.day(next, calendar: jerusalem))
        counters.claimed = j.quests(on: next, calendar: jerusalem).map(\.rawValue)
        j.today = counters
        XCTAssertEqual(j.openChest(on: next, calendar: jerusalem), ChestReward(xp: JourneyRules.chestXP, freeze: true))
        XCTAssertEqual(j.freezes, 1)
        // Counters start again on a new day.
        XCTAssertEqual(j.questProgress(.lessons, on: at(30), calendar: jerusalem), 0)
    }

    func testAdaptiveTrainingAimsAtTheTargetSuccessRate() {
        var j = JourneyProgress()
        XCTAssertEqual(j.successChance("x"), 0.5, accuracy: 1e-9)
        j.ability = 1400
        j.difficulty = ["easy": 600, "ok": 1000, "hard": 1800]
        XCTAssertGreaterThan(j.successChance("easy"), 0.95)
        XCTAssertLessThan(j.successChance("hard"), 0.1)
        // About 91 % for "ok": the closest to 80 % of the three.
        XCTAssertEqual(j.adaptivePick(from: ["hard", "easy", "ok"], count: 1), ["ok"])
        XCTAssertEqual(j.adaptivePick(from: ["hard", "easy", "ok"], count: 3).count, 3)

        // A right answer raises the ability and lowers the difficulty; a mistake does the opposite.
        var s = LessonSession(questionIDs: ["a", "b"])
        s.submit(correct: true); s.submit(correct: false)
        var k = JourneyProgress()
        k.finish(lesson: nil, outcome: s.outcome(bonus: false))
        XCTAssertLessThan(k.difficulty["a"]!, 1000, "a right answer makes the question easier")
        XCTAssertGreaterThan(k.difficulty["b"]!, 1000, "a mistake makes it harder")
        XCTAssertNotEqual(k.ability, 1000)
    }

    func testRemindersAtTheUsualHour() {
        XCTAssertEqual(ReminderPlan.habitualHour([:]), ReminderPlan.defaultHour)
        XCTAssertEqual(ReminderPlan.habitualHour(["8": 2, "21": 5, "19": 5]), 19, "the earliest on a tie")
        let cal = jerusalem
        let morning = at(28, hour: 9)
        XCTAssertEqual(cal.component(.hour, from: ReminderPlan.streakAlert(now: morning, practicedToday: false, calendar: cal)), 20)
        XCTAssertEqual(cal.component(.day, from: ReminderPlan.streakAlert(now: morning, practicedToday: false, calendar: cal)), 28)
        XCTAssertEqual(cal.component(.day, from: ReminderPlan.streakAlert(now: morning, practicedToday: true, calendar: cal)), 29, "already practiced: warn tomorrow")
        XCTAssertEqual(cal.component(.day, from: ReminderPlan.streakAlert(now: at(28, hour: 22), practicedToday: false, calendar: cal)), 29, "too late for tonight")
    }

    func testExercisePlanner() {
        XCTAssertEqual((0..<4).map { ExercisePlanner.kind(position: $0, firstAttempt: true, hasHebrew: true) }, [.choice, .trueFalse, .listening, .hebrew])
        XCTAssertEqual(ExercisePlanner.kind(position: 3, firstAttempt: true, hasHebrew: false), .choice)
        XCTAssertEqual(ExercisePlanner.kind(position: 1, firstAttempt: false, hasHebrew: true), .choice, "a retry is the plain question")
        for q in pool.prefix(200) {
            let st = ExercisePlanner.statement(for: q)
            XCTAssertEqual(st.isTrue, st.answerIndex == q.c)
            XCTAssertEqual(st.answerIndex, ExercisePlanner.statement(for: q).answerIndex)
            let t = ExercisePlanner.translations(for: q, in: pool)
            XCTAssertEqual(t.options[t.correct], q.q)
            XCTAssertEqual(Set(t.options).count, t.options.count)
            XCTAssertEqual(t.options, ExercisePlanner.translations(for: q, in: pool).options)
        }
        let trues = pool.filter { ExercisePlanner.statement(for: $0).isTrue }.count
        XCTAssertGreaterThan(trues, pool.count / 3)
        XCTAssertLessThan(trues, pool.count * 2 / 3)
    }
}
