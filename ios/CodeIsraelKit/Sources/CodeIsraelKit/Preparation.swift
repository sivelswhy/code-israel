import Foundation

/// How ready the learner is for the exam, estimated from their answers. An estimate, never a promise.
public struct ThemeReadiness: Sendable, Equatable {
    public let category: Category
    /// Average chance of answering a question of this theme right, 0...1.
    public let chance: Double
    public let seen: Int
    public let total: Int
}

public struct Readiness: Sendable, Equatable {
    /// Chance of passing a mock exam (at most `ExamRules.maxErrors` mistakes), 0...1.
    public let passChance: Double
    /// Share of the question bank answered at least once, 0...1.
    public let coverage: Double
    public let themes: [ThemeReadiness]
    /// False while too little of the bank has been answered for the estimate to mean much.
    public let enoughData: Bool

    /// The themes where the learner is the weakest, weakest first.
    public var weakest: [ThemeReadiness] { themes.sorted { ($0.chance, $0.category.rawValue) < ($1.chance, $1.category.rawValue) } }
}

/// What to do each day until the exam.
public struct ExamPlan: Sendable, Equatable {
    public let daysLeft: Int
    /// Questions never seen, plus those answered with a low chance of success.
    public let toLearn: Int
    /// Questions to work on each day, keeping the last day for a final review.
    public let perDay: Int
    public var isPast: Bool { daysLeft < 0 }
}

public enum Preparation {
    /// A question never answered: unknown, assumed hard to be on the safe side.
    public static let unseenChance = 0.35
    /// Enough of the bank has been seen for the estimate to be meaningful.
    public static let minimumCoverage = 0.25
    /// Below this chance, a question still has to be learned.
    public static let learnedChance = 0.7

    /// Chance of answering this question right: the answers so far (lightly smoothed), pulled by the last attempt.
    public static func chance(_ stat: Stat?) -> Double {
        guard let stat else { return unseenChance }
        let base = (Double(stat.ok) + 0.5) / Double(stat.ok + stat.ko + 1)
        return 0.7 * base + 0.3 * (stat.last ? 0.95 : 0.3)
    }

    /// Probability of making at most `maxErrors` mistakes, each question having its own chance of being right.
    public static func passProbability(chances: [Double], maxErrors: Int = ExamRules.maxErrors) -> Double {
        // errors[k] = probability of exactly k mistakes so far (capped one above the limit).
        var errors = [Double](repeating: 0, count: maxErrors + 2)
        errors[0] = 1
        for p in chances {
            var next = [Double](repeating: 0, count: errors.count)
            for (k, prob) in errors.enumerated() where prob > 0 {
                next[k] += prob * p
                next[min(k + 1, errors.count - 1)] += prob * (1 - p)
            }
            errors = next
        }
        return errors.prefix(maxErrors + 1).reduce(0, +)
    }

    /// The exam draws each theme in proportion to the bank: how many questions of each, for `size` in all.
    static func examShares(pool: [Question], size: Int) -> [(Category, Int)] {
        let counts = Category.allCases.map { cat in (cat, pool.filter { $0.cat == cat }.count) }.filter { $0.1 > 0 }
        guard !pool.isEmpty else { return [] }
        var shares = counts.map { ($0.0, Int((Double($0.1) / Double(pool.count) * Double(size)).rounded())) }
        // Rounding may leave the total off by a few: the largest theme absorbs the difference.
        let diff = size - shares.reduce(0) { $0 + $1.1 }
        if diff != 0, let i = shares.indices.max(by: { counts[$0].1 < counts[$1].1 }) { shares[i].1 += diff }
        return shares
    }

    public static func readiness(pool: [Question], stats: [String: Stat]) -> Readiness {
        let themes = Category.allCases.compactMap { cat -> ThemeReadiness? in
            let qs = pool.filter { $0.cat == cat }
            guard !qs.isEmpty else { return nil }
            let avg = qs.reduce(0.0) { $0 + chance(stats[$1.id]) } / Double(qs.count)
            return ThemeReadiness(category: cat, chance: avg, seen: qs.filter { stats[$0.id] != nil }.count, total: qs.count)
        }
        let byCategory = Dictionary(uniqueKeysWithValues: themes.map { ($0.category, $0.chance) })
        let chances = examShares(pool: pool, size: ExamRules.size).flatMap { cat, n in Array(repeating: byCategory[cat] ?? unseenChance, count: n) }
        let seen = pool.filter { stats[$0.id] != nil }.count
        let coverage = pool.isEmpty ? 0 : Double(seen) / Double(pool.count)
        return Readiness(passChance: passProbability(chances: chances), coverage: coverage, themes: themes, enoughData: coverage >= minimumCoverage && seen >= ExamRules.size)
    }

    /// Questions the learner keeps getting wrong, the worst first: more mistakes than right answers, or at least two mistakes.
    public static func trapIDs(pool: [Question], stats: [String: Stat], limit: Int = 20) -> [String] {
        pool.compactMap { q -> (id: String, rate: Double, ko: Int)? in
            guard let s = stats[q.id], s.ko >= 2 || (s.ko >= 1 && s.ko > s.ok) else { return nil }
            return (q.id, Double(s.ko) / Double(s.ok + s.ko), s.ko)
        }
        .sorted { a, b in a.rate != b.rate ? a.rate > b.rate : a.ko != b.ko ? a.ko > b.ko : a.id < b.id }
        .prefix(limit).map(\.id)
    }

    /// Consecutive mock exams passed, counting back from the latest one (the advice is to pass a few in a row before the real exam).
    public static func passStreak(_ exams: [ExamRecord]) -> Int {
        exams.reversed().prefix { $0.passed }.count
    }

    /// The days left to the exam and the daily workload. Nil when no date is set or it cannot be read.
    public static func plan(examDate: String?, pool: [Question], stats: [String: Stat], now: Date = .now, calendar: Calendar = .current) -> ExamPlan? {
        guard let examDate else { return nil }
        let parts = examDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, let exam = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])) else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: exam).day ?? 0
        let toLearn = pool.filter { chance(stats[$0.id]) < learnedChance }.count
        // The last day is kept for a final review.
        return ExamPlan(daysLeft: days, toLearn: toLearn, perDay: days <= 1 ? toLearn : Int((Double(toLearn) / Double(days - 1)).rounded(.up)))
    }
}
