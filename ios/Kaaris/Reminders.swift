import Foundation
import OSLog
import UserNotifications

struct WorkoutReminder: Equatable {
    let identifier: String
    let date: Date
    let title: String
    let message: String
    let sessionID: UUID
}

enum ReminderPlan {
    static let identifierPrefix = "kaaris.workout."

    static func make(
        sessions: [WorkoutSession],
        preferences: CoachPreferences,
        now: Date,
        calendar: Calendar = .current
    ) -> [WorkoutReminder] {
        guard preferences.remindersEnabled, preferences.reminderIntensity > 0 else { return [] }

        let prompts = [
            Prompt(key: "before", offsetMinutes: -60, title: "Séance dans une heure", message: "Ta séance approche. Prends deux minutes pour te préparer."),
            Prompt(key: "start", offsetMinutes: 0, title: "C’est l’heure de ta séance", message: "Tu peux confirmer ton arrivée ou choisir un autre créneau."),
            Prompt(key: "check-in", offsetMinutes: 45, title: "Point sur ta séance", message: "Tu as pu faire ta séance ? Mets ton planning à jour.")
        ]

        return sessions.filter { $0.status == .planned }.flatMap { session in
            prompts.prefix(preferences.reminderIntensity).compactMap { prompt -> WorkoutReminder? in
                let date = session.date.addingTimeInterval(Double(prompt.offsetMinutes) * 60)
                guard date > now, date >= (preferences.pausedUntil ?? .distantPast),
                      !preferences.isQuiet(at: date, calendar: calendar) else { return nil }
                return WorkoutReminder(
                    identifier: identifierPrefix + session.id.uuidString + "." + prompt.key,
                    date: date,
                    title: prompt.title,
                    message: prompt.message,
                    sessionID: session.id
                )
            }
        }.sorted { $0.date < $1.date }.prefix(48).map { $0 }
    }

    private struct Prompt {
        let key: String
        let offsetMinutes: Int
        let title: String
        let message: String
    }
}

@MainActor
final class ReminderScheduler {
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "Kaaris", category: "Reminders")
    private var pendingReplacement: Task<Void, Never>?
    private var revision = 0

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("Notification authorization request failed")
            return false
        }
    }

    func replace(sessions: [WorkoutSession], preferences: CoachPreferences) {
        revision += 1
        let target = revision
        let previous = pendingReplacement
        pendingReplacement = Task { @MainActor [weak self] in
            await previous?.value
            guard let self, self.revision == target else { return }
            await self.apply(sessions: sessions, preferences: preferences, revision: target)
        }
    }

    private func apply(sessions: [WorkoutSession], preferences: CoachPreferences, revision: Int) async {
        let existing = await center.pendingNotificationRequests().map(\.identifier)
        guard revision == self.revision else { return }

        let existingWorkoutReminders = existing.filter { $0.hasPrefix(ReminderPlan.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existingWorkoutReminders)

        guard preferences.remindersEnabled else { return }
        let settings = await center.notificationSettings()
        guard revision == self.revision else { return }
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        case .notDetermined, .denied: return
        @unknown default: return
        }

        let reminders = ReminderPlan.make(sessions: sessions, preferences: preferences, now: .now)
        for reminder in reminders {
            guard revision == self.revision else { return }
            do {
                try await center.add(request(for: reminder))
            } catch {
                logger.error("Could not schedule a workout reminder")
            }
        }
    }

    private func request(for reminder: WorkoutReminder) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.sound = .default
        content.interruptionLevel = .active
        content.userInfo = ["sessionID": reminder.sessionID.uuidString]

        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.date)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
    }
}
