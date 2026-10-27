import Foundation

/// Official computerized test format: 30 questions, 40 minutes, at most 4 mistakes.
public enum ExamRules {
    public static let size = 30
    public static let minutes = 40
    public static let maxErrors = 4
    /// Questions in a practice series.
    public static let practiceSize = 20
    /// Questions a day to complete the daily ring.
    public static let dailyGoal = 20
}

/// Draws an exam that keeps each category's share of the pool for this license.
public func drawExam<R: RandomNumberGenerator>(_ pool: [Question], using rng: inout R) -> [Question] {
    var picked: [Question] = []
    var seen = Set<String>()
    // Categories in order of first appearance, like the web app.
    let categories = pool.map(\.cat).uniqued()
    for cat in categories {
        let qs = pool.filter { $0.cat == cat }
        let share = Int((Double(qs.count) / Double(pool.count) * Double(ExamRules.size)).rounded(.toNearestOrAwayFromZero))
        for q in qs.shuffled(using: &rng).prefix(share) {
            picked.append(q)
            seen.insert(q.id)
        }
    }
    let rest = pool.filter { !seen.contains($0.id) }.shuffled(using: &rng)
    return Array((picked + rest).prefix(ExamRules.size)).shuffled(using: &rng)
}

public func drawExam(_ pool: [Question]) -> [Question] {
    var rng = SystemRandomNumberGenerator()
    return drawExam(pool, using: &rng)
}
