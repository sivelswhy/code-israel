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
        XCTAssertEqual((0..<4).map { ExercisePlanner.kind(position: $0, firstAttempt: true, hasHebrew: true) }, [.choice, .trueFalse, .choice, .hebrew])
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

    func testPassProbabilityIsExact() {
        // 30 questions, each right with chance 1: always passes; each right with chance 0: never.
        XCTAssertEqual(Preparation.passProbability(chances: Array(repeating: 1, count: 30)), 1, accuracy: 1e-12)
        XCTAssertEqual(Preparation.passProbability(chances: Array(repeating: 0, count: 30)), 0, accuracy: 1e-12)
        // 3 coin flips, at most 1 mistake: P(0 or 1 mistakes) = 4/8.
        XCTAssertEqual(Preparation.passProbability(chances: [0.5, 0.5, 0.5], maxErrors: 1), 0.5, accuracy: 1e-12)
        // A better learner passes more often than a weaker one.
        let strong = Preparation.passProbability(chances: Array(repeating: 0.95, count: 30))
        let weak = Preparation.passProbability(chances: Array(repeating: 0.8, count: 30))
        XCTAssertGreaterThan(strong, 0.9)
        XCTAssertLessThan(weak, 0.5)
    }

    func testReadinessGrowsWithGoodAnswers() {
        let fresh = Preparation.readiness(pool: pool, stats: [:])
        XCTAssertFalse(fresh.enoughData)
        XCTAssertEqual(fresh.coverage, 0)
        XCTAssertLessThan(fresh.passChance, 0.01, "nothing seen: unlikely to pass")
        XCTAssertEqual(Set(fresh.themes.map(\.category)), Set(pool.map(\.cat)))
        var good: [String: Stat] = [:]
        for q in pool { good[q.id] = Stat(ok: 4, ko: 0, last: true) }
        let ready = Preparation.readiness(pool: pool, stats: good)
        XCTAssertTrue(ready.enoughData)
        XCTAssertEqual(ready.coverage, 1)
        XCTAssertGreaterThan(ready.passChance, 0.8, "four right answers each, no mistake")
        var bad: [String: Stat] = [:]
        for q in pool { bad[q.id] = Stat(ok: 0, ko: 3, last: false) }
        XCTAssertLessThan(Preparation.readiness(pool: pool, stats: bad).passChance, 0.01)
        // The weakest theme comes first.
        var mixed = good
        for q in pool where q.cat == .signs { mixed[q.id] = Stat(ok: 0, ko: 3, last: false) }
        XCTAssertEqual(Preparation.readiness(pool: pool, stats: mixed).weakest.first?.category, .signs)
    }

    func testTrapQuestionsAndExamPlan() {
        let ids = pool.prefix(5).map(\.id)
        let stats = [
            ids[0]: Stat(ok: 1, ko: 3, last: false),   // 75 % wrong
            ids[1]: Stat(ok: 5, ko: 2, last: true),    // 2 mistakes
            ids[2]: Stat(ok: 0, ko: 1, last: false),   // one mistake, none right: a trap
            ids[3]: Stat(ok: 3, ko: 1, last: false),   // one mistake only, more right: not a trap
            ids[4]: Stat(ok: 9, ko: 0, last: true),
        ]
        XCTAssertEqual(Preparation.trapIDs(pool: pool, stats: stats), [ids[2], ids[0], ids[1]])
        XCTAssertEqual(Preparation.trapIDs(pool: pool, stats: stats, limit: 1), [ids[2]])

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9))!
        XCTAssertNil(Preparation.plan(examDate: nil, pool: pool, stats: [:], now: now, calendar: calendar))
        XCTAssertNil(Preparation.plan(examDate: "bientôt", pool: pool, stats: [:], now: now, calendar: calendar))
        let plan = Preparation.plan(examDate: "2026-11-07", pool: pool, stats: [:], now: now, calendar: calendar)!
        XCTAssertEqual(plan.daysLeft, 10)
        XCTAssertEqual(plan.toLearn, pool.count, "nothing is known yet")
        XCTAssertEqual(plan.perDay, Int((Double(pool.count) / 9).rounded(.up)), "the last day is kept for a review")
        XCTAssertTrue(Preparation.plan(examDate: "2026-10-20", pool: pool, stats: [:], now: now, calendar: calendar)!.isPast)
        XCTAssertEqual(Preparation.plan(examDate: "2026-10-29", pool: pool, stats: [:], now: now, calendar: calendar)!.perDay, pool.count)
    }

    func testPassStreakAndExamDateSaved() throws {
        func exam(_ errors: Int) -> ExamRecord { ExamRecord(date: .now, errors: errors, license: .B) }
        XCTAssertEqual(Preparation.passStreak([]), 0)
        XCTAssertEqual(Preparation.passStreak([exam(9), exam(2), exam(4)]), 2)
        XCTAssertEqual(Preparation.passStreak([exam(2), exam(5)]), 0)
        var p = Progress()
        p.examDate = "2026-12-01"
        let back = try JSONDecoder().decode(Progress.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back.examDate, "2026-12-01")
        XCTAssertNil(try JSONDecoder().decode(Progress.self, from: Data(#"{"license":"B"}"#.utf8)).examDate)
    }

    // MARK: Sync

    func testSyncCode() {
        let code = SyncCode.generate()
        XCTAssertEqual(code.count, 19, "four groups of four, with dashes")
        XCTAssertNotNil(SyncCode.normalize(code))
        XCTAssertEqual(SyncCode.normalize(code.lowercased().replacingOccurrences(of: "-", with: " ")), SyncCode.normalize(code), "case, spaces and dashes do not matter")
        XCTAssertNil(SyncCode.normalize("ABCD-EFGH"))
        XCTAssertNil(SyncCode.normalize("0000-0000-0000-0000"), "no zero in a code")
        XCTAssertEqual(SyncCode.id(for: code), SyncCode.id(for: code.lowercased()))
        XCTAssertEqual(SyncCode.id(for: code)?.count, 64)
        XCTAssertNotEqual(SyncCode.id(for: code), SyncCode.id(for: SyncCode.generate()))
        // Fixed value, shared with the web: SHA-256 of "code-israel:ABCDEFGHJKMNPQRS".
        XCTAssertEqual(SyncCode.id(for: "ABCD-EFGH-JKMN-PQRS"), "2ddf41b94a7dff048cf091f54aacea8e24057d790d2f22a9ac6ddfad75bc0801")
        for _ in 0..<50 { XCTAssertEqual(SyncCode.generate().filter { $0 == "-" }.count, 3) }
    }

    func testMergeBringsTwoDevicesTogether() {
        var phone = Progress()
        phone.modified = 2000
        phone.license = .A
        phone.favorites = ["f1"]
        phone.stats = ["q1": Stat(ok: 3, ko: 1, last: true), "q2": Stat(ok: 1, ko: 0, last: true)]
        phone.daily = ["2026-10-27": 5, "2026-10-28": 2]
        phone.examDate = "2026-12-01"
        phone.journey.lessons["rules-1"] = LessonResult(stars: 2, completions: 1)
        phone.journey.xpByDay = ["2026-10-27": 100]
        phone.journey.xp = 100
        phone.journey.review["q1"] = ReviewState(halfLife: 4, last: "2026-10-27")
        phone.journey.frozenDays = ["2026-10-20"]
        phone.journey.today = DayCounters(day: "2026-10-28")

        var mac = Progress()
        mac.modified = 1000
        mac.license = .B
        mac.favorites = ["f2"]
        mac.stats = ["q1": Stat(ok: 1, ko: 1, last: false), "q3": Stat(ok: 0, ko: 2, last: false)]
        mac.daily = ["2026-10-27": 9, "2026-10-26": 1]
        mac.journey.lessons["rules-1"] = LessonResult(stars: 3, completions: 1)
        mac.journey.lessons["rules-2"] = LessonResult(stars: 1, completions: 1)
        mac.journey.xpByDay = ["2026-10-26": 60]
        mac.journey.xp = 60
        mac.journey.review["q1"] = ReviewState(halfLife: 2, last: "2026-10-26")
        mac.journey.frozenDays = ["2026-10-21"]
        mac.journey.today = DayCounters(day: "2026-10-26")

        let m = ProgressMerge.merge(phone, mac)
        XCTAssertEqual(m.license, .A, "the most recently used device decides the settings")
        XCTAssertEqual(m.favorites, ["f1"])
        XCTAssertEqual(m.examDate, "2026-12-01")
        XCTAssertEqual(m.stats["q1"], Stat(ok: 3, ko: 1, last: true), "the one with more answers")
        XCTAssertEqual(Set(m.stats.keys), ["q1", "q2", "q3"])
        XCTAssertEqual(m.daily, ["2026-10-26": 1, "2026-10-27": 9, "2026-10-28": 2])
        XCTAssertEqual(m.journey.lessons["rules-1"], LessonResult(stars: 3, completions: 1))
        XCTAssertNotNil(m.journey.lessons["rules-2"])
        XCTAssertEqual(m.journey.xp, 160, "the XP of different days adds up")
        XCTAssertEqual(m.journey.review["q1"]?.halfLife, 4, "the later review")
        XCTAssertEqual(m.journey.frozenDays, ["2026-10-20", "2026-10-21"])
        XCTAssertEqual(m.journey.today.day, "2026-10-28")
        XCTAssertEqual(m.modified, 2000)

        // Same result from the other side, and nothing changes when the same data is merged again.
        let back = ProgressMerge.merge(mac, phone)
        XCTAssertEqual(back.stats, m.stats)
        XCTAssertEqual(back.daily, m.daily)
        XCTAssertEqual(back.journey.xp, m.journey.xp)
        XCTAssertEqual(back.license, m.license)
        let again = ProgressMerge.merge(m, phone)
        XCTAssertEqual(again.stats, m.stats)
        XCTAssertEqual(again.journey.xp, m.journey.xp)
        XCTAssertEqual(again.daily, m.daily)
    }

    func testMergeKeepsExamsOnceAndPayloadRoundTrips() throws {
        let when = Date(timeIntervalSince1970: 1_800_000_000)
        var a = Progress(); a.modified = 5
        a.exams = [ExamRecord(date: when, errors: 3, license: .B, ids: ["1", "2"], answers: [0, nil])]
        var b = Progress(); b.modified = 4
        b.exams = [ExamRecord(date: when, errors: 3, license: .B), ExamRecord(date: when.addingTimeInterval(60), errors: 7, license: .B)]
        let m = ProgressMerge.merge(a, b)
        XCTAssertEqual(m.exams.count, 2)
        XCTAssertEqual(m.exams[0].ids, ["1", "2"], "the copy with its answers is kept")

        var p = Progress()
        p.modified = 1_800_000_123
        p.examDate = "2026-12-01"
        p.stats["q"] = Stat(ok: 2, ko: 1, last: false)
        p.exams = m.exams
        p.journey.review["q"] = ReviewState(halfLife: 8, last: "2026-10-28")
        let data = try JSONEncoder().encode(SyncPayload(p))
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(json["modified"] as? Double, 1_800_000_123_000, "milliseconds, like the web")
        XCTAssertEqual((json["exams"] as! [[String: Any]])[0]["date"] as? Double, 1_800_000_000_000)
        let back = try JSONDecoder().decode(SyncPayload.self, from: data).progress()
        XCTAssertEqual(back.modified, p.modified)
        XCTAssertEqual(back.examDate, "2026-12-01")
        XCTAssertEqual(back.stats["q"], p.stats["q"])
        XCTAssertEqual(back.exams, p.exams)
        XCTAssertEqual(back.journey.review["q"]?.halfLife, 8)
    }

    /// The JSON below was produced by the web app (`toWire` in src/sync.ts): the apps must read it as is.
    func testReadsWhatTheWebSends() throws {
        let web = #"{"v":1,"modified":1800000123000,"license":"A","examDate":"2026-12-01","favorites":["9"],"stats":{"q1":{"ok":2,"ko":1,"last":false}},"exams":[{"date":1800000000000,"errors":3,"license":"B","ids":["1","2"],"answers":[0,null]},{"date":1800000060000,"errors":6,"license":"B"}],"daily":{"2026-10-28":4},"journey":{"lessons":{"rules-1":{"stars":3,"completions":2}},"xp":120,"xpByDay":{"2026-10-28":120},"review":{"q1":{"halfLife":4,"last":"2026-10-28"}},"freezes":1,"frozenDays":["2026-10-20"],"today":{"day":"2026-10-28","lessons":1,"perfect":1,"reviews":0,"bestRun":6,"claimed":["xp","run"],"chestOpened":false},"chestsOpened":2,"ability":1012.5,"difficulty":{"q1":990},"hours":{"19":3}}}"#
        let p = try JSONDecoder().decode(SyncPayload.self, from: Data(web.utf8)).progress()
        XCTAssertEqual(p.license, .A)
        XCTAssertEqual(p.modified, 1_800_000_123)
        XCTAssertEqual(p.examDate, "2026-12-01")
        XCTAssertEqual(p.favorites, ["9"])
        XCTAssertEqual(p.stats["q1"], Stat(ok: 2, ko: 1, last: false))
        XCTAssertEqual(p.daily["2026-10-28"], 4)
        XCTAssertEqual(p.exams.count, 2)
        XCTAssertEqual(p.exams[0].answers, [0, nil])
        XCTAssertEqual(p.exams[0].date, Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertNil(p.exams[1].ids)
        XCTAssertEqual(p.journey.lessons["rules-1"], LessonResult(stars: 3, completions: 2))
        XCTAssertEqual(p.journey.xp, 120)
        XCTAssertEqual(p.journey.review["q1"], ReviewState(halfLife: 4, last: "2026-10-28"))
        XCTAssertEqual(p.journey.frozenDays, ["2026-10-20"])
        XCTAssertEqual(p.journey.freezes, 1)
        XCTAssertEqual(p.journey.ability, 1012.5)
        XCTAssertEqual(p.journey.difficulty["q1"], 990)
        XCTAssertEqual(p.journey.hours["19"], 3)
        XCTAssertEqual(p.journey.today.claimed, ["xp", "run"])
        XCTAssertEqual(p.journey.today.bestRun, 6)
    }
}
