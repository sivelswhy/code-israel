import Foundation

/// Answers given to one question.
public struct Stat: Codable, Hashable, Sendable {
    public var ok: Int
    public var ko: Int
    /// Whether the last attempt was correct.
    public var last: Bool
}

public struct ExamRecord: Codable, Hashable, Sendable {
    public var date: Date
    public var errors: Int
    public var license: License
    /// Questions drawn, in order. Only kept for the latest exams, so older ones cannot be reviewed.
    public var ids: [String]?
    /// Index chosen in each question's answers (nil = unanswered), parallel to `ids`.
    public var answers: [Int?]?

    public init(date: Date, errors: Int, license: License, ids: [String]? = nil, answers: [Int?]? = nil) {
        self.date = date
        self.errors = errors
        self.license = license
        self.ids = ids
        self.answers = answers
    }

    public var passed: Bool { errors <= ExamRules.maxErrors }
    public var canReview: Bool { ids != nil && ids?.count == answers?.count }
}

/// Everything the learner has done, saved on the device only.
public struct Progress: Codable, Sendable {
    public var license: License = .B
    public var stats: [String: Stat] = [:]
    public var exams: [ExamRecord] = []
    /// Ids of the questions the learner starred.
    public var favorites: [String] = []
    /// The Parcours mode: lessons done, XP and questions to review.
    public var journey = JourneyProgress()
    /// Questions answered per local date (yyyy-MM-dd).
    public var daily: [String: Int] = [:]
    /// The date of the learner's exam (yyyy-MM-dd), to plan the revision.
    public var examDate: String?

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let saved = (try? c.decode(License.self, forKey: .license)) ?? .B
        // A license that is on hold falls back to the default one.
        license = License.active.contains(saved) ? saved : .B
        stats = (try? c.decode([String: Stat].self, forKey: .stats)) ?? [:]
        exams = (try? c.decode([ExamRecord].self, forKey: .exams)) ?? []
        favorites = (try? c.decode([String].self, forKey: .favorites)) ?? []
        journey = (try? c.decode(JourneyProgress.self, forKey: .journey)) ?? JourneyProgress()
        daily = (try? c.decode([String: Int].self, forKey: .daily)) ?? [:]
        examDate = try? c.decode(String.self, forKey: .examDate)
    }

    /// Exams whose questions and answers are kept for review.
    public static let reviewableExams = 20

    public mutating func toggleFavorite(_ id: String) {
        if let i = favorites.firstIndex(of: id) { favorites.remove(at: i) } else { favorites.append(id) }
    }

    public mutating func addExam(_ exam: ExamRecord) {
        exams.append(exam)
        // Older exams keep their score only, so the saved progress stays small.
        for i in exams.indices where i < exams.count - Self.reviewableExams {
            exams[i].ids = nil
            exams[i].answers = nil
        }
    }

    public mutating func record(_ id: String, ok: Bool, on date: Date = .now, calendar: Calendar = .current) {
        var s = stats[id] ?? Stat(ok: 0, ko: 0, last: ok)
        if ok { s.ok += 1 } else { s.ko += 1 }
        s.last = ok
        stats[id] = s
        daily[Self.day(date, calendar: calendar), default: 0] += 1
    }

    public func answeredToday(_ date: Date = .now, calendar: Calendar = .current) -> Int {
        daily[Self.day(date, calendar: calendar)] ?? 0
    }

    /// Consecutive days of practice ending today (or yesterday, so the streak survives until tonight). A day saved by a
    /// streak freeze keeps the streak going without adding to it.
    public func streak(_ date: Date = .now, calendar: Calendar = .current) -> Int {
        let frozen = Set(journey.frozenDays)
        func covered(_ d: Date) -> Bool { JourneyProgress.covered(Self.day(d, calendar: calendar), daily: daily, frozen: frozen) }
        var d = date
        if !covered(d) { d = calendar.date(byAdding: .day, value: -1, to: d)! }
        var n = 0
        while covered(d) {
            if daily[Self.day(d, calendar: calendar)] != nil { n += 1 }
            d = calendar.date(byAdding: .day, value: -1, to: d)!
        }
        return n
    }

    /// Spends streak freezes on the days missed since the last practice, but only when there are enough of them to keep
    /// the streak alive (at most three days). Returns how many were used.
    @discardableResult
    public mutating func applyStreakFreezes(_ date: Date = .now, calendar: Calendar = .current) -> Int {
        guard journey.freezes > 0 else { return 0 }
        let frozen = Set(journey.frozenDays)
        func covered(_ d: Date) -> Bool { JourneyProgress.covered(Self.day(d, calendar: calendar), daily: daily, frozen: frozen) }
        guard !covered(date) else { return 0 }
        var missed: [String] = []
        var d = calendar.date(byAdding: .day, value: -1, to: date)!
        while !covered(d), missed.count < 3 {
            missed.append(Self.day(d, calendar: calendar))
            d = calendar.date(byAdding: .day, value: -1, to: d)!
        }
        guard covered(d), !missed.isEmpty, missed.count <= journey.freezes else { return 0 }
        journey.freezes -= missed.count
        journey.frozenDays += missed
        return missed.count
    }

    public static func day(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

/// Where a pool of questions stands for the learner.
public struct Mastery: Sendable {
    public let total: Int
    public let mastered: Int
    public let seen: Int
    public let mistakes: [Question]
    public let unseen: [Question]

    public init(pool: [Question], stats: [String: Stat]) {
        total = pool.count
        mistakes = pool.filter { stats[$0.id].map { !$0.last } ?? false }
        unseen = pool.filter { stats[$0.id] == nil }
        seen = total - unseen.count
        mastered = total - unseen.count - mistakes.count
    }
}
