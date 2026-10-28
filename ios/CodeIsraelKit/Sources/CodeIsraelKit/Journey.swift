import Foundation

/// Rules of the "Parcours" mode: a path of short lessons with XP, stars and spaced repetition.
public enum JourneyRules {
    /// Questions in a lesson.
    public static let lessonSize = 8
    /// A last lesson shorter than this is merged into the one before it.
    public static let minimumLessonSize = 4
    /// Questions in a daily review.
    public static let reviewSize = 10
    public static let xpFirstTry = 10
    public static let xpRetry = 4
    public static let xpLessonBonus = 10
    public static let xpPerfectBonus = 5
    public static let xpPerLevel = 100
    /// XP to earn in a day to complete the daily goal (about one lesson).
    public static let dailyXP = 50
    /// Extra XP for a fast lesson: first answers averaging under `speedSeconds` with at least 70 % right.
    public static let xpSpeedBonus = 5
    public static let speedSeconds = 12.0
    /// Memory model (half-life regression): a question starts with a half-life of one day, which doubles every
    /// time it is answered right at the first try and falls back to one day after a mistake.
    public static let startHalfLife = 1.0
    public static let maxHalfLife = 180.0
    /// A question is due for review once the chance to remember it falls to this value or below.
    public static let dueRecall = 0.6
    /// Adaptive training: the questions are picked so that the learner succeeds about this often.
    public static let targetSuccess = 0.8
    public static let adaptiveSize = 8
    public static let questXP = 10
    public static let chestXP = 20
    /// Every this many chests, one also holds a streak freeze.
    public static let chestFreezeEvery = 3
    public static let maxFreezes = 2
    /// Pairs in a round of the sign matching game and its XP.
    public static let matchPairs = 5
    public static let xpMatch = 15
}

/// A short series of questions of one theme.
public struct Lesson: Identifiable, Hashable, Sendable {
    /// For example `rules-3`.
    public let id: String
    public let category: Category
    /// Position in its unit, from 1.
    public let number: Int
    public let questionIDs: [String]
}

/// The lessons of one theme.
public struct JourneyUnit: Identifiable, Sendable {
    public var id: String { category.rawValue }
    public let category: Category
    public let lessons: [Lesson]
}

/// The path: each theme is a unit of lessons, in the order of the official question bank.
public struct LearningPath: Sendable {
    public let units: [JourneyUnit]

    public init(pool: [Question]) {
        units = Category.allCases.compactMap { cat in
            let ids = pool.filter { $0.cat == cat }.map(\.id).sorted()
            guard !ids.isEmpty else { return nil }
            var chunks = stride(from: 0, to: ids.count, by: JourneyRules.lessonSize).map { Array(ids[$0..<min($0 + JourneyRules.lessonSize, ids.count)]) }
            if chunks.count > 1, chunks.last!.count < JourneyRules.minimumLessonSize {
                chunks[chunks.count - 2] += chunks.removeLast()
            }
            return JourneyUnit(category: cat, lessons: chunks.enumerated().map { Lesson(id: "\(cat.rawValue)-\($0.offset + 1)", category: cat, number: $0.offset + 1, questionIDs: $0.element) })
        }
    }

    public func unit(_ category: Category) -> JourneyUnit? { units.first { $0.category == category } }
    public var lessonCount: Int { units.reduce(0) { $0 + $1.lessons.count } }
}

/// What a finished lesson earned.
public struct SessionOutcome: Sendable, Equatable {
    public let xp: Int
    public let stars: Int
    /// Questions answered right the first time.
    public let firstTry: Int
    public let total: Int
    /// Answers that were wrong (a question can be wrong more than once).
    public let mistakes: Int
    public let perfect: Bool
    /// Per question: right at the first attempt?
    public let firstTryByQuestion: [String: Bool]
    /// True when the lesson earned the speed bonus.
    public let speedBonus: Bool
    public let bestRun: Int

    public var accuracy: Double { total == 0 ? 0 : Double(firstTry) / Double(total) }
}

/// One lesson being played. A wrong question goes to the end of the queue and comes back until it is answered
/// right: nothing is lost, the lesson just lasts longer.
public struct LessonSession: Sendable {
    public private(set) var queue: [String]
    public let total: Int
    private var firstTry: [String: Bool] = [:]
    private var solved = Set<String>()
    public private(set) var mistakes = 0
    /// The longest run of right answers in a row.
    public private(set) var bestRun = 0
    private var run = 0
    private var firstSeconds = 0.0
    private var timed = 0

    public init(questionIDs: [String]) {
        queue = questionIDs
        total = questionIDs.count
    }

    public var current: String? { queue.first }
    public var isFinished: Bool { queue.isEmpty }
    /// 0...1, for the progress bar.
    public var progress: Double { total == 0 ? 1 : Double(solved.count) / Double(total) }

    /// True the first time the current question is answered (its result counts for the learner's statistics).
    public var isFirstAttempt: Bool { current.map { firstTry[$0] == nil } ?? false }

    /// Records the answer to the current question.
    /// `seconds` is the time taken to answer, used for the speed bonus (first attempts only).
    public mutating func submit(correct: Bool, seconds: Double? = nil) {
        guard let id = queue.first else { return }
        if firstTry[id] == nil {
            firstTry[id] = correct
            if let seconds { firstSeconds += seconds; timed += 1 }
        }
        queue.removeFirst()
        if correct {
            solved.insert(id)
            run += 1
            bestRun = max(bestRun, run)
        } else {
            mistakes += 1
            queue.append(id)
            run = 0
        }
    }

    /// What the lesson earned. `bonus` is false for a review, which has no completion bonus.
    public func outcome(bonus: Bool = true) -> SessionOutcome {
        let right = firstTry.values.filter { $0 }.count
        let retried = firstTry.values.filter { !$0 }.count
        let perfect = mistakes == 0 && total > 0
        let accuracy = total == 0 ? 0 : Double(right) / Double(total)
        let stars = accuracy >= 0.9 ? 3 : accuracy >= 0.7 ? 2 : 1
        let fast = bonus && timed == total && total > 0 && accuracy >= 0.7 && firstSeconds / Double(total) <= JourneyRules.speedSeconds
        let xp = right * JourneyRules.xpFirstTry + retried * JourneyRules.xpRetry
            + (bonus ? JourneyRules.xpLessonBonus + (perfect ? JourneyRules.xpPerfectBonus : 0) : 0)
            + (fast ? JourneyRules.xpSpeedBonus : 0)
        return SessionOutcome(xp: xp, stars: stars, firstTry: right, total: total, mistakes: mistakes, perfect: perfect, firstTryByQuestion: firstTry, speedBonus: fast, bestRun: bestRun)
    }
}

public struct LessonResult: Codable, Hashable, Sendable {
    public var stars: Int
    public var completions: Int

    /// A lesson turns gold once it has been played perfectly (3 stars).
    public var isGold: Bool { stars >= 3 }
}

/// How well a question is remembered: a half-life in days and the day it was last answered.
public struct ReviewState: Codable, Hashable, Sendable {
    public var halfLife: Double
    /// yyyy-MM-dd
    public var last: String

    public init(halfLife: Double, last: String) {
        self.halfLife = halfLife
        self.last = last
    }

    private enum CodingKeys: String, CodingKey { case halfLife, last, due }

    /// Saves made before the half-life model only know a due day: the question is simply reviewed from then on.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let h = try? c.decode(Double.self, forKey: .halfLife), let l = try? c.decode(String.self, forKey: .last) {
            halfLife = h; last = l
        } else {
            halfLife = JourneyRules.startHalfLife
            last = (try? c.decode(String.self, forKey: .due)) ?? ""
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(halfLife, forKey: .halfLife)
        try c.encode(last, forKey: .last)
    }

    /// Chance to remember the question `days` days after the last answer: 2^(-days / halfLife).
    public func recall(afterDays days: Int) -> Double { pow(2, -Double(max(0, days)) / halfLife) }
}

/// A daily quest.
public enum QuestKind: String, Codable, CaseIterable, Sendable {
    case xp, lessons, perfect, run, review

    public var target: Int {
        switch self {
        case .xp: 40
        case .lessons: 2
        case .perfect: 1
        case .run: 5
        case .review: 1
        }
    }

    public var title: String {
        switch self {
        case .xp: "Gagner \(target) XP"
        case .lessons: "Terminer \(target) leçons"
        case .perfect: "Réussir une leçon parfaite"
        case .run: "Enchaîner \(target) bonnes réponses"
        case .review: "Faire la révision du jour"
        }
    }

    public var icon: String {
        switch self {
        case .xp: "bolt.fill"
        case .lessons: "flag.checkered"
        case .perfect: "star.fill"
        case .run: "flame.fill"
        case .review: "arrow.triangle.2.circlepath"
        }
    }
}

/// What was done today, for the daily quests. Starts again each day.
public struct DayCounters: Codable, Hashable, Sendable {
    public var day = ""
    public var lessons = 0
    public var perfect = 0
    public var reviews = 0
    public var bestRun = 0
    public var claimed: [String] = []
    public var chestOpened = false

    public init(day: String = "") { self.day = day }
}

/// What a chest holds.
public struct ChestReward: Equatable, Sendable {
    public let xp: Int
    public let freeze: Bool
}

/// What the learner has done in the Parcours mode, saved on the device.
public struct JourneyProgress: Codable, Sendable {
    public var lessons: [String: LessonResult] = [:]
    public var xp = 0
    public var xpByDay: [String: Int] = [:]
    public var review: [String: ReviewState] = [:]
    /// Streak freezes in stock, and the days they saved.
    public var freezes = 0
    public var frozenDays: [String] = []
    public var today = DayCounters()
    public var chestsOpened = 0
    /// Adaptive difficulty (an Elo rating): the learner's ability and each question's difficulty, both starting at 1000.
    public var ability = 1000.0
    public var difficulty: [String: Double] = [:]
    /// How many lessons were finished at each hour of the day ("19": 4), to remind at the usual time.
    public var hours: [String: Int] = [:]

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lessons = (try? c.decode([String: LessonResult].self, forKey: .lessons)) ?? [:]
        xp = (try? c.decode(Int.self, forKey: .xp)) ?? 0
        xpByDay = (try? c.decode([String: Int].self, forKey: .xpByDay)) ?? [:]
        review = (try? c.decode([String: ReviewState].self, forKey: .review)) ?? [:]
        freezes = (try? c.decode(Int.self, forKey: .freezes)) ?? 0
        frozenDays = (try? c.decode([String].self, forKey: .frozenDays)) ?? []
        today = (try? c.decode(DayCounters.self, forKey: .today)) ?? DayCounters()
        chestsOpened = (try? c.decode(Int.self, forKey: .chestsOpened)) ?? 0
        ability = (try? c.decode(Double.self, forKey: .ability)) ?? 1000
        difficulty = (try? c.decode([String: Double].self, forKey: .difficulty)) ?? [:]
        hours = (try? c.decode([String: Int].self, forKey: .hours)) ?? [:]
    }

    public var level: Int { xp / JourneyRules.xpPerLevel + 1 }
    public var xpInLevel: Int { xp % JourneyRules.xpPerLevel }

    public func xpToday(_ date: Date = .now, calendar: Calendar = .current) -> Int {
        xpByDay[Progress.day(date, calendar: calendar)] ?? 0
    }

    public func isComplete(_ lesson: Lesson) -> Bool { lessons[lesson.id] != nil }

    /// A lesson opens once the one before it in its unit is done.
    public func isUnlocked(_ lesson: Lesson, in unit: JourneyUnit) -> Bool {
        lesson.number == 1 || unit.lessons.first { $0.number == lesson.number - 1 }.map(isComplete) ?? false
    }

    /// The first lesson of the unit that is not done yet.
    public func currentLesson(in unit: JourneyUnit) -> Lesson? { unit.lessons.first { !isComplete($0) } }

    public func completedCount(in unit: JourneyUnit) -> Int { unit.lessons.filter(isComplete).count }

    /// Chance to remember a question today, if it has been reviewed before.
    public func recall(_ id: String, on date: Date = .now, calendar: Calendar = .current) -> Double? {
        review[id].map { $0.recall(afterDays: Self.days(from: $0.last, to: date, calendar: calendar)) }
    }

    /// Average chance to remember the questions reviewed so far, 0...1 (nil before the first review).
    public func memoryStrength(on date: Date = .now, calendar: Calendar = .current) -> Double? {
        let values = review.keys.compactMap { recall($0, on: date, calendar: calendar) }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// Questions to review today (the chance to remember them fell to `dueRecall`), the most forgotten first.
    public func dueQuestionIDs(_ date: Date = .now, calendar: Calendar = .current) -> [String] {
        review.compactMap { id, state -> (String, Double)? in
            let p = state.recall(afterDays: Self.days(from: state.last, to: date, calendar: calendar))
            return p <= JourneyRules.dueRecall ? (id, p) : nil
        }
        .sorted { ($0.1, $0.0) < ($1.1, $1.0) }
        .map(\.0)
    }

    static func days(from day: String, to date: Date, calendar: Calendar) -> Int {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let start = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return 0 }
        return calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: date)).day ?? 0
    }

    // MARK: Adaptive difficulty

    /// Chance that the learner answers this question right, from the Elo ratings.
    public func successChance(_ id: String) -> Double {
        1 / (1 + pow(10, ((difficulty[id] ?? 1000) - ability) / 400))
    }

    /// The questions whose chance of success is closest to the target, so that the training is neither too easy nor too hard.
    /// Questions never reviewed come first on a tie; the rest is shuffled by the day, not at random, to stay predictable.
    public func adaptivePick(from ids: [String], count: Int = JourneyRules.adaptiveSize, on date: Date = .now, calendar: Calendar = .current) -> [String] {
        let day = Progress.day(date, calendar: calendar)
        func salt(_ id: String) -> Int { (day + id).unicodeScalars.reduce(7) { ($0 &* 31 &+ Int($1.value)) % 9973 } }
        func score(_ id: String) -> Double { abs(successChance(id) - JourneyRules.targetSuccess) + (review[id] == nil ? 0 : 0.03) }
        return ids.sorted { (score($0), salt($0), $0) < (score($1), salt($1), $1) }.prefix(count).map { $0 }
    }

    // MARK: Streak freezes

    /// A day counts for the streak when something was practiced or a freeze saved it.
    public static func covered(_ day: String, daily: [String: Int], frozen: Set<String>) -> Bool { daily[day] != nil || frozen.contains(day) }

    // MARK: Daily quests

    /// Three quests a day, always the same for a given day.
    public func quests(on date: Date = .now, calendar: Calendar = .current) -> [QuestKind] {
        let day = Progress.day(date, calendar: calendar)
        let seed = day.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 100_003 }
        var kinds = QuestKind.allCases
        var picked: [QuestKind] = []
        var s = seed
        while picked.count < 3 {
            picked.append(kinds.remove(at: s % kinds.count))
            s = s / 3 + 1
        }
        return picked
    }

    private func counters(on date: Date, calendar: Calendar) -> DayCounters {
        let day = Progress.day(date, calendar: calendar)
        return today.day == day ? today : DayCounters(day: day)
    }

    public func questProgress(_ quest: QuestKind, on date: Date = .now, calendar: Calendar = .current) -> Int {
        let c = counters(on: date, calendar: calendar)
        switch quest {
        case .xp: return min(quest.target, xpToday(date, calendar: calendar))
        case .lessons: return min(quest.target, c.lessons)
        case .perfect: return min(quest.target, c.perfect)
        case .run: return min(quest.target, c.bestRun)
        case .review: return min(quest.target, c.reviews)
        }
    }

    public func isDone(_ quest: QuestKind, on date: Date = .now, calendar: Calendar = .current) -> Bool {
        questProgress(quest, on: date, calendar: calendar) >= quest.target
    }

    public func isClaimed(_ quest: QuestKind, on date: Date = .now, calendar: Calendar = .current) -> Bool {
        counters(on: date, calendar: calendar).claimed.contains(quest.rawValue)
    }

    /// Collects the XP of a finished quest. Returns false when it is not done or already collected.
    @discardableResult
    public mutating func claim(_ quest: QuestKind, on date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard quests(on: date, calendar: calendar).contains(quest), isDone(quest, on: date, calendar: calendar), !isClaimed(quest, on: date, calendar: calendar) else { return false }
        var c = counters(on: date, calendar: calendar)
        c.claimed.append(quest.rawValue)
        today = c
        add(xp: JourneyRules.questXP, on: date, calendar: calendar)
        return true
    }

    /// The chest opens once the three quests are collected, once a day.
    public func canOpenChest(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        let c = counters(on: date, calendar: calendar)
        return !c.chestOpened && quests(on: date, calendar: calendar).allSatisfy { c.claimed.contains($0.rawValue) }
    }

    @discardableResult
    public mutating func openChest(on date: Date = .now, calendar: Calendar = .current) -> ChestReward? {
        guard canOpenChest(on: date, calendar: calendar) else { return nil }
        var c = counters(on: date, calendar: calendar)
        c.chestOpened = true
        today = c
        chestsOpened += 1
        add(xp: JourneyRules.chestXP, on: date, calendar: calendar)
        let freeze = chestsOpened % JourneyRules.chestFreezeEvery == 0 && freezes < JourneyRules.maxFreezes
        if freeze { freezes += 1 }
        return ChestReward(xp: JourneyRules.chestXP, freeze: freeze)
    }

    // MARK: Recording

    /// Adds XP to the total and to the day.
    public mutating func add(xp amount: Int, on date: Date = .now, calendar: Calendar = .current) {
        xp += amount
        xpByDay[Progress.day(date, calendar: calendar), default: 0] += amount
    }

    /// Records a finished lesson (or review when `lesson` is nil): XP, stars, quests, memory and difficulty. `countsAsReview` is
    /// false for a free training, which belongs to no lesson but does not count as the daily review.
    public mutating func finish(lesson: Lesson?, outcome: SessionOutcome, countsAsReview: Bool = true, on date: Date = .now, calendar: Calendar = .current) {
        add(xp: outcome.xp, on: date, calendar: calendar)
        var c = counters(on: date, calendar: calendar)
        if let lesson {
            var result = lessons[lesson.id] ?? LessonResult(stars: 0, completions: 0)
            result.stars = max(result.stars, outcome.stars)
            result.completions += 1
            lessons[lesson.id] = result
            c.lessons += 1
            if outcome.perfect { c.perfect += 1 }
        } else if countsAsReview {
            c.reviews += 1
        }
        c.bestRun = max(c.bestRun, outcome.bestRun)
        today = c
        hours[String(calendar.component(.hour, from: date)), default: 0] += 1

        let day = Progress.day(date, calendar: calendar)
        for (id, right) in outcome.firstTryByQuestion {
            // Half-life regression, simplified: right at the first try doubles the half-life, a mistake resets it.
            let h = review[id]?.halfLife ?? JourneyRules.startHalfLife
            review[id] = ReviewState(halfLife: right ? min(h * 2, JourneyRules.maxHalfLife) : JourneyRules.startHalfLife, last: day)
            // Elo update: a surprise moves the ratings more than an expected result.
            let p = successChance(id)
            let delta = 24 * ((right ? 1 : 0) - p)
            ability += delta
            difficulty[id] = (difficulty[id] ?? 1000) - delta
        }
    }
}
