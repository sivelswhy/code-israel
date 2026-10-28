import CodeIsraelKit
import Foundation
import UserNotifications

/// Local reminders (nothing leaves the device): one every day at the hour the learner usually studies, and a warning in
/// the evening when the streak is at risk.
@MainActor
enum Reminders {
    private static let key = "remindersOn"
    private static let daily = "daily-reminder"
    private static let streak = "streak-alert"

    static var isOn: Bool { UserDefaults.standard.bool(forKey: key) }

    /// The hour of the daily reminder, learned from when lessons were finished.
    static func hour(_ app: AppModel) -> Int { ReminderPlan.habitualHour(app.progress.journey.hours) }

    /// Turns the reminders on (asking for permission the first time) or off. Returns whether they are on.
    @discardableResult
    static func setOn(_ on: Bool, app: AppModel) async -> Bool {
        var enabled = on
        if on {
            enabled = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        }
        UserDefaults.standard.set(enabled, forKey: key)
        refresh(app)
        return enabled
    }

    /// Plans the notifications again from the current progress.
    static func refresh(_ app: AppModel) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [daily, streak])
        guard isOn else { return }
        let calendar = Calendar.current

        let reminder = UNMutableNotificationContent()
        reminder.title = "C’est l’heure de votre leçon"
        if let plan = app.examPlan, plan.daysLeft > 0 {
            // With an exam date set, the reminder counts down and says how much to do today.
            reminder.title = "Examen dans \(plan.daysLeft) jour\(plan.daysLeft > 1 ? "s" : "")"
            reminder.body = plan.toLearn > 0 ? "Environ \(plan.perDay) question\(plan.perDay > 1 ? "s" : "") à travailler aujourd’hui." : "Tout est acquis : un examen blanc pour garder le rythme ?"
        } else {
            reminder.body = "Quelques minutes suffisent pour avancer vers le permis."
        }
        reminder.sound = .default
        center.add(UNNotificationRequest(identifier: daily, content: reminder, trigger: UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour(app)), repeats: true)))

        guard app.progress.streak() > 0 else { return }
        let practiced = app.progress.answeredToday() > 0
        let when = ReminderPlan.streakAlert(now: .now, practicedToday: practiced, calendar: calendar)
        let alert = UNMutableNotificationContent()
        alert.title = "Votre série est en danger"
        alert.body = "Une leçon avant minuit suffit pour la garder."
        alert.sound = .default
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: when)
        center.add(UNNotificationRequest(identifier: streak, content: alert, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
    }
}
