import Foundation

/// When to remind the learner to practice. Pure rules: the app turns them into notifications.
public enum ReminderPlan {
    /// The hour of the streak alert.
    public static let streakHour = 20
    public static let streakMinute = 30
    public static let defaultHour = 19

    /// The hour at which the learner usually finishes lessons (the most frequent one, the earliest on a tie).
    public static func habitualHour(_ hours: [String: Int]) -> Int {
        hours.compactMap { k, v in Int(k).map { ($0, v) } }
            .max { ($0.1, -$0.0) < ($1.1, -$1.0) }?.0 ?? defaultHour
    }

    /// When to warn that the streak is at risk: tonight if nothing was done today, otherwise tomorrow night.
    public static func streakAlert(now: Date, practicedToday: Bool, calendar: Calendar = .current) -> Date {
        let tonight = calendar.date(bySettingHour: streakHour, minute: streakMinute, second: 0, of: now)!
        if !practicedToday, tonight > now { return tonight }
        return calendar.date(byAdding: .day, value: 1, to: tonight)!
    }
}
