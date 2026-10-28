import CryptoKit
import Foundation

/// The sync code: it is the learner's only key to the progress saved online. Nobody needs an account.
public enum SyncCode {
    /// No 0, 1, I, L, O or U: nothing to mix up when the code is read or typed.
    static let alphabet = Array("ABCDEFGHJKMNPQRSTVWXYZ23456789")
    public static let length = 16

    /// A new random code, e.g. `K7QM-2XTR-9HBD-4WCN`.
    public static func generate() -> String {
        var g = SystemRandomNumberGenerator()
        let raw = (0..<length).map { _ in alphabet.randomElement(using: &g)! }
        return display(String(raw))
    }

    /// The code in capitals, without spaces or dashes; nil when it cannot be a code.
    public static func normalize(_ text: String) -> String? {
        let raw = text.uppercased().filter { $0.isLetter || $0.isNumber }
        return raw.count == length && raw.allSatisfy(alphabet.contains) ? raw : nil
    }

    /// `K7QM2XTR9HBD4WCN` → `K7QM-2XTR-9HBD-4WCN`.
    public static func display(_ raw: String) -> String {
        stride(from: 0, to: raw.count, by: 4).map { i in String(raw.dropFirst(i).prefix(4)) }.joined(separator: "-")
    }

    /// What the server sees instead of the code: its SHA-256. The code itself never leaves the devices.
    public static func id(for code: String) -> String? {
        normalize(code).map { SHA256.hash(data: Data("code-israel:\($0)".utf8)).map { String(format: "%02x", $0) }.joined() }
    }
}

/// Brings the progress of two devices together. The result is the same whichever device is `a` or `b`.
public enum ProgressMerge {
    public static func merge(_ a: Progress, _ b: Progress) -> Progress {
        // The scalar settings follow the device that changed last; counters only ever grow, so the larger one wins.
        let (new, old) = a.modified >= b.modified ? (a, b) : (b, a)
        var r = Progress()
        r.modified = new.modified
        r.license = new.license
        r.examDate = new.examDate ?? old.examDate
        r.favorites = new.favorites
        let aNewer = a.modified >= b.modified
        r.stats = a.stats.merging(b.stats) { x, y in
            let (tx, ty) = (x.ok + x.ko, y.ok + y.ko)
            return tx != ty ? (tx > ty ? x : y) : (aNewer ? x : y)
        }
        r.daily = a.daily.merging(b.daily) { max($0, $1) }
        r.exams = mergeExams(a.exams, b.exams)
        r.journey = mergeJourney(a.journey, b.journey, newerIsA: a.modified >= b.modified)
        return r
    }

    private static func mergeExams(_ a: [ExamRecord], _ b: [ExamRecord]) -> [ExamRecord] {
        var byKey: [String: ExamRecord] = [:]
        for e in a + b {
            let key = "\(Int(e.date.timeIntervalSince1970))-\(e.license.rawValue)-\(e.errors)"
            // The copy that kept its answers is preferred.
            if let old = byKey[key], old.ids != nil || e.ids == nil { continue }
            byKey[key] = e
        }
        var exams = byKey.values.sorted { ($0.date, $0.errors) < ($1.date, $1.errors) }
        for i in exams.indices where i < exams.count - Progress.reviewableExams { exams[i].ids = nil; exams[i].answers = nil }
        return exams
    }

    static func mergeJourney(_ a: JourneyProgress, _ b: JourneyProgress, newerIsA: Bool) -> JourneyProgress {
        let (new, old) = newerIsA ? (a, b) : (b, a)
        var r = JourneyProgress()
        r.lessons = a.lessons.merging(b.lessons) { LessonResult(stars: max($0.stars, $1.stars), completions: max($0.completions, $1.completions)) }
        r.xpByDay = a.xpByDay.merging(b.xpByDay) { max($0, $1) }
        // The total is at least the XP of every day: two devices that earned XP on different days add up.
        r.xp = max(a.xp, b.xp, r.xpByDay.values.reduce(0, +))
        r.review = a.review.merging(b.review) { x, y in x.last != y.last ? (x.last > y.last ? x : y) : (x.halfLife >= y.halfLife ? x : y) }
        r.frozenDays = Array(Set(a.frozenDays).union(b.frozenDays)).sorted()
        r.freezes = new.freezes
        r.chestsOpened = max(a.chestsOpened, b.chestsOpened)
        r.hours = a.hours.merging(b.hours) { max($0, $1) }
        r.ability = new.ability
        r.difficulty = old.difficulty.merging(new.difficulty) { _, n in n }
        r.today = mergeDay(a.today, b.today)
        return r
    }

    private static func mergeDay(_ a: DayCounters, _ b: DayCounters) -> DayCounters {
        guard a.day == b.day else { return a.day > b.day ? a : b }
        var r = DayCounters(day: a.day)
        r.lessons = max(a.lessons, b.lessons)
        r.perfect = max(a.perfect, b.perfect)
        r.reviews = max(a.reviews, b.reviews)
        r.bestRun = max(a.bestRun, b.bestRun)
        r.claimed = Array(Set(a.claimed).union(b.claimed)).sorted()
        r.chestOpened = a.chestOpened || b.chestOpened
        return r
    }
}

/// The progress as it travels between devices: the same shape on the web, so that every device can read it.
public struct SyncPayload: Codable, Sendable {
    public var v = 1
    public var modified: Double
    public var license: String
    public var examDate: String?
    public var favorites: [String]
    public var stats: [String: Stat]
    public var exams: [WireExam]
    public var daily: [String: Int]
    public var journey: JourneyProgress

    public struct WireExam: Codable, Sendable {
        /// Milliseconds since 1970, like a JavaScript date.
        public var date: Double
        public var errors: Int
        public var license: String
        public var ids: [String]?
        public var answers: [Int?]?
    }

    public init(_ p: Progress) {
        modified = p.modified * 1000
        license = p.license.rawValue
        examDate = p.examDate
        favorites = p.favorites
        stats = p.stats
        exams = p.exams.map { WireExam(date: $0.date.timeIntervalSince1970 * 1000, errors: $0.errors, license: $0.license.rawValue, ids: $0.ids, answers: $0.answers) }
        daily = p.daily
        journey = p.journey
    }

    public func progress() -> Progress {
        var p = Progress()
        p.modified = modified / 1000
        p.license = License(rawValue: license).flatMap { License.active.contains($0) ? $0 : nil } ?? .B
        p.examDate = examDate
        p.favorites = favorites
        p.stats = stats
        p.exams = exams.compactMap { e in
            License(rawValue: e.license).map { ExamRecord(date: Date(timeIntervalSince1970: e.date / 1000), errors: e.errors, license: $0, ids: e.ids, answers: e.answers) }
        }
        p.daily = daily
        p.journey = journey
        return p
    }
}
