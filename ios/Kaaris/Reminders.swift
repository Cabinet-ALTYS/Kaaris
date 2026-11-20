import Foundation
import OSLog
import UserNotifications

enum ReminderTarget: String, Sendable {
    case coach, call, test
}

struct ReminderDestination: Equatable, Sendable {
    let target: ReminderTarget
    let sessionID: UUID?
}

struct ReminderDelivery: Equatable {
    enum Authorization: Equatable {
        case unknown, demo, notRequested, denied, allowed, quiet

        var acceptsReminders: Bool { self == .allowed || self == .quiet }

        var label: String {
            switch self {
            case .unknown: "Vérification iOS en cours"
            case .demo: "Mode démo"
            case .notRequested: "Autorisation iOS à demander"
            case .denied: "Bloquées par iOS"
            case .allowed: "Autorisées dans iOS"
            case .quiet: "Distribution discrète dans iOS"
            }
        }
    }

    let authorization: Authorization
    var banners = false
    var lockScreen = false
    var sound = false
    var scheduledSummary = false

    static let initial = ReminderDelivery(authorization: .unknown)
    static let demo = ReminderDelivery(authorization: .demo)
}

struct WorkoutReminder: Equatable {
    let identifier: String
    let date: Date
    let title: String
    let message: String
    let sessionID: UUID
    let target: ReminderTarget
    let usesBluntTone: Bool
}

struct ReminderLedger: Codable {
    private static let storageKey = "kaaris.reminder-ledger.v1"
    private var elapsed: [Date] = []
    private var scheduled: [Date] = []

    static func load(from defaults: UserDefaults = .standard) -> ReminderLedger {
        guard let data = defaults.data(forKey: storageKey),
              let ledger = try? JSONDecoder().decode(Self.self, from: data) else { return ReminderLedger() }
        return ledger
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.storageKey) }
    }

    func dueDates(at now: Date) -> [Date] {
        elapsed + scheduled.filter { $0 <= now }
    }

    mutating func recordScheduled(at date: Date) {
        scheduled.append(date)
    }

    mutating func cancelFuture(at now: Date, calendar: Calendar) {
        elapsed = dueDates(at: now)
        scheduled.removeAll()

        // Keep yesterday as well, in case the local day changes after travel.
        let today = calendar.startOfDay(for: now)
        let keepFrom = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        elapsed.removeAll { $0 < keepFrom }
    }
}

enum ReminderPlan {
    static let identifierPrefix = "kaaris.workout."
    static let testIdentifier = "kaaris.reminder.test"
    static let maxDailyReminders = 5

    static func make(
        sessions: [WorkoutSession],
        preferences: CoachPreferences,
        now: Date,
        calendar: Calendar = .current,
        alreadyDue: [Date]? = nil
    ) -> [WorkoutReminder] {
        guard preferences.remindersEnabled, preferences.reminderIntensity > 0 else { return [] }

        let prompts = [
            Prompt(key: "before", offsetMinutes: -60, title: "Séance dans une heure", message: "Ta séance approche. Prends deux minutes pour te préparer.", target: .coach),
            Prompt(key: "start", offsetMinutes: 0, title: "C’est l’heure de ta séance", message: "Ouvre le pointage KAARIS pour indiquer où tu en es.", target: .call),
            Prompt(key: "check-in", offsetMinutes: 45, title: "Point sur ta séance", message: "Tu as pu faire ta séance ? Fais le point avec KAARIS.", target: .call),
            Prompt(key: "prepare", offsetMinutes: -180, title: "Séance aujourd’hui", message: "Vérifie ton créneau et prépare tes affaires.", target: .coach),
            Prompt(key: "follow-up", offsetMinutes: 120, title: "Confirme ta séance", message: "Fais le point sur ta séance ou reprogramme-la.", target: .call)
        ]

        let candidates = sessions.filter { $0.status == .planned }.flatMap { session in
            prompts.prefix(preferences.reminderIntensity).enumerated().compactMap { index, prompt -> WorkoutReminder? in
                let date = session.date.addingTimeInterval(Double(prompt.offsetMinutes) * 60)
                guard date > now, date >= (preferences.pausedUntil ?? .distantPast),
                      !preferences.isQuiet(at: date, calendar: calendar) else { return nil }
                let blunt = preferences.bluntNotificationsEnabled
                return WorkoutReminder(
                    identifier: identifierPrefix + session.id.uuidString + "." + prompt.key,
                    date: date,
                    title: prompt.title,
                    message: blunt ? "\(preferences.coachOpener(variant: index)) \(prompt.message)" : prompt.message,
                    sessionID: session.id,
                    target: prompt.target,
                    usesBluntTone: blunt
                )
            }
        }

        let dueDates = alreadyDue ?? ReminderLedger.load().dueDates(at: now)
        var byDay: [Date: Int] = [:]
        for date in dueDates {
            byDay[calendar.startOfDay(for: date), default: 0] += 1
        }
        let eligible = candidates.sorted { $0.date < $1.date }.filter { reminder in
            let day = calendar.startOfDay(for: reminder.date)
            guard byDay[day, default: 0] < maxDailyReminders else { return false }
            byDay[day, default: 0] += 1
            return true
        }
        return Array(eligible.prefix(60))
    }

    private struct Prompt {
        let key: String
        let offsetMinutes: Int
        let title: String
        let message: String
        let target: ReminderTarget
    }
}

@MainActor
final class ReminderScheduler {
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "Kaaris", category: "Reminders")
    private var pendingReplacement: Task<Void, Never>?
    private var revision = 0
    private var clearBluntDeliveryRequested = false
    private var ledger = ReminderLedger.load()

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("Notification authorization request failed")
            return false
        }
    }

    func deliverySettings() async -> ReminderDelivery {
        let settings = await center.notificationSettings()
        let authorization: ReminderDelivery.Authorization
        switch settings.authorizationStatus {
        case .authorized: authorization = .allowed
        case .provisional, .ephemeral: authorization = .quiet
        case .notDetermined: authorization = .notRequested
        case .denied: authorization = .denied
        @unknown default: authorization = .unknown
        }
        return ReminderDelivery(
            authorization: authorization,
            banners: settings.alertSetting == .enabled && settings.alertStyle != .none,
            lockScreen: settings.lockScreenSetting == .enabled,
            sound: settings.soundSetting == .enabled,
            scheduledSummary: settings.scheduledDeliverySetting == .enabled
        )
    }

    func sendTest() async -> Bool {
        guard await deliverySettings().authorization.acceptsReminders else { return false }
        let content = content(
            title: "Test de notification KAARIS",
            body: "Ouvre ce test pour essayer l’appel simulé dans l’app.",
            target: .test
        )
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: ReminderPlan.testIdentifier, content: content, trigger: trigger))
            return true
        } catch {
            logger.error("Could not queue a test reminder")
            return false
        }
    }

    func replace(sessions: [WorkoutSession], preferences: CoachPreferences, clearBluntDelivery: Bool) {
        clearBluntDeliveryRequested = clearBluntDeliveryRequested || clearBluntDelivery
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
        let calendar = Calendar.current
        ledger.cancelFuture(at: .now, calendar: calendar)
        ledger.save()
        if clearBluntDeliveryRequested {
            let delivered = await center.deliveredNotifications()
            guard revision == self.revision else { return }
            let blunt = delivered.filter {
                $0.request.identifier.hasPrefix(ReminderPlan.identifierPrefix)
                    && $0.request.content.userInfo["blunt"] as? Bool == true
            }.map(\.request.identifier)
            center.removeDeliveredNotifications(withIdentifiers: blunt)
            clearBluntDeliveryRequested = false
        }

        guard preferences.remindersEnabled else { return }
        let settings = await center.notificationSettings()
        guard revision == self.revision else { return }
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: break
        case .notDetermined, .denied: return
        @unknown default: return
        }

        let now = Date.now
        let reminders = ReminderPlan.make(
            sessions: sessions, preferences: preferences, now: now, calendar: calendar,
            alreadyDue: ledger.dueDates(at: now)
        )
        for reminder in reminders {
            guard revision == self.revision else { return }
            let trigger = Self.trigger(for: reminder.date, calendar: calendar)
            guard let dueAt = trigger.nextTriggerDate(), dueAt > .now else { continue }
            do {
                try await center.add(request(for: reminder, trigger: trigger, maxIntensity: preferences.reminderIntensity == ReminderPlan.maxDailyReminders))
                ledger.recordScheduled(at: dueAt)
                ledger.save()
            } catch {
                logger.error("Could not schedule a workout reminder")
            }
        }
    }

    private func request(for reminder: WorkoutReminder, trigger: UNCalendarNotificationTrigger, maxIntensity: Bool) -> UNNotificationRequest {
        let content = content(title: reminder.title, body: reminder.message, target: reminder.target)
        content.userInfo["sessionID"] = reminder.sessionID.uuidString
        content.userInfo["blunt"] = reminder.usesBluntTone
        content.userInfo["foregroundCall"] = maxIntensity && reminder.target == .call
        return UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
    }

    private static func trigger(for date: Date, calendar: Calendar) -> UNCalendarNotificationTrigger {
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    private func content(title: String, body: String, target: ReminderTarget) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .active
        content.userInfo = ["target": target.rawValue]
        return content
    }
}
