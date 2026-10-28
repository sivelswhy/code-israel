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
    /// Days before a question comes back, by box: a question answered right the first time moves up a box.
    public static let intervals = [1, 2, 4, 8, 16]
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
    public mutating func submit(correct: Bool) {
        guard let id = queue.first else { return }
        if firstTry[id] == nil { firstTry[id] = correct }
        queue.removeFirst()
        if correct {
            solved.insert(id)
        } else {
            mistakes += 1
            queue.append(id)
        }
    }

    /// What the lesson earned. `bonus` is false for a review, which has no completion bonus.
    public func outcome(bonus: Bool = true) -> SessionOutcome {
        let right = firstTry.values.filter { $0 }.count
        let retried = firstTry.values.filter { !$0 }.count
        let perfect = mistakes == 0 && total > 0
        let accuracy = total == 0 ? 0 : Double(right) / Double(total)
        let stars = accuracy >= 0.9 ? 3 : accuracy >= 0.7 ? 2 : 1
        let xp = right * JourneyRules.xpFirstTry + retried * JourneyRules.xpRetry
            + (bonus ? JourneyRules.xpLessonBonus + (perfect ? JourneyRules.xpPerfectBonus : 0) : 0)
        return SessionOutcome(xp: xp, stars: stars, firstTry: right, total: total, mistakes: mistakes, perfect: perfect, firstTryByQuestion: firstTry)
    }
}

public struct LessonResult: Codable, Hashable, Sendable {
    public var stars: Int
    public var completions: Int
}

/// When a question comes back for review.
public struct ReviewState: Codable, Hashable, Sendable {
    public var box: Int
    /// yyyy-MM-dd
    public var due: String
}

/// What the learner has done in the Parcours mode, saved on the device.
public struct JourneyProgress: Codable, Sendable {
    public var lessons: [String: LessonResult] = [:]
    public var xp = 0
    public var xpByDay: [String: Int] = [:]
    public var review: [String: ReviewState] = [:]

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lessons = (try? c.decode([String: LessonResult].self, forKey: .lessons)) ?? [:]
        xp = (try? c.decode(Int.self, forKey: .xp)) ?? 0
        xpByDay = (try? c.decode([String: Int].self, forKey: .xpByDay)) ?? [:]
        review = (try? c.decode([String: ReviewState].self, forKey: .review)) ?? [:]
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

    /// Questions to review today, the most overdue first.
    public func dueQuestionIDs(_ date: Date = .now, calendar: Calendar = .current) -> [String] {
        let today = Progress.day(date, calendar: calendar)
        return review.filter { $0.value.due <= today }.sorted { ($0.value.due, $0.key) < ($1.value.due, $1.key) }.map(\.key)
    }

    /// Records a finished lesson (or review when `lesson` is nil): XP, stars, and when each question comes back.
    public mutating func finish(lesson: Lesson?, outcome: SessionOutcome, on date: Date = .now, calendar: Calendar = .current) {
        xp += outcome.xp
        xpByDay[Progress.day(date, calendar: calendar), default: 0] += outcome.xp
        if let lesson {
            var result = lessons[lesson.id] ?? LessonResult(stars: 0, completions: 0)
            result.stars = max(result.stars, outcome.stars)
            result.completions += 1
            lessons[lesson.id] = result
        }
        for (id, right) in outcome.firstTryByQuestion {
            // A new question starts in box 0: right the first time moves it up, a mistake sends it back.
            let box = right ? min((review[id]?.box ?? 0) + 1, JourneyRules.intervals.count - 1) : 0
            let due = calendar.date(byAdding: .day, value: JourneyRules.intervals[box], to: date) ?? date
            review[id] = ReviewState(box: box, due: Progress.day(due, calendar: calendar))
        }
    }
}
