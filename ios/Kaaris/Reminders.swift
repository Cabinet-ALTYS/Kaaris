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
    var notificationCenter = false
    var sound = false
    var scheduledSummary = false
    var pendingCount = 0
    var nextReminderDate: Date?

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
    private var elapsed: [Date] = []
    private var scheduled: [Date] = []

    private static func storageKey(for accountID: UUID) -> String {
        "kaaris.reminder-ledger.v2.\(accountID.uuidString)"
    }

    static func load(from defaults: UserDefaults, accountID: UUID?) -> ReminderLedger {
        guard let accountID, let data = defaults.data(forKey: storageKey(for: accountID)),
              let ledger = try? JSONDecoder().decode(Self.self, from: data) else { return ReminderLedger() }
        return ledger
    }

    func save(to defaults: UserDefaults, accountID: UUID?) {
        guard let accountID, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.storageKey(for: accountID))
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
        alreadyDue: [Date] = []
    ) -> [WorkoutReminder] {
        guard preferences.remindersEnabled, preferences.reminderIntensity > 0 else { return [] }

        let start = Prompt(key: "start", offsetMinutes: 0, title: "KAARIS t’appelle", message: "Ta séance commence. Touche cette notification pour faire le point.", target: .call)
        let prompts = [
            Prompt(key: "before", offsetMinutes: -60, title: "Séance dans une heure", message: "Ta séance approche. Prends deux minutes pour te préparer.", target: .coach),
            start,
            Prompt(key: "check-in", offsetMinutes: 45, title: "Point sur ta séance", message: "Tu as pu faire ta séance ? Fais le point avec KAARIS.", target: .call),
            Prompt(key: "prepare", offsetMinutes: -180, title: "Séance aujourd’hui", message: "Vérifie ton créneau et prépare tes affaires.", target: .coach),
            Prompt(key: "follow-up", offsetMinutes: 120, title: "Confirme ta séance", message: "Fais le point sur ta séance ou reprogramme-la.", target: .call)
        ]
        let dueDates = alreadyDue
        let blunt = preferences.bluntNotificationsEnabled

        func eligible(_ date: Date) -> Bool {
            date > now && date >= (preferences.pausedUntil ?? .distantPast)
                && !preferences.isQuiet(at: date, calendar: calendar)
        }

        let candidates = sessions.filter { $0.status == .planned }.flatMap { session in
            let regular = prompts.prefix(preferences.reminderIntensity).enumerated().compactMap { index, prompt -> WorkoutReminder? in
                let date = session.date.addingTimeInterval(Double(prompt.offsetMinutes) * 60)
                guard eligible(date) else { return nil }
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
            // A single advance reminder may be in the past or in quiet hours when the user turns reminders on.
            let advanceDate = session.date.addingTimeInterval(-3600)
            guard regular.isEmpty, preferences.reminderIntensity == 1, eligible(session.date),
                  !dueDates.contains(where: { abs($0.timeIntervalSince(advanceDate)) <= 1 }) else { return regular }
            return [WorkoutReminder(
                identifier: identifierPrefix + session.id.uuidString + "." + start.key,
                date: session.date, title: start.title,
                message: blunt ? "\(preferences.coachOpener(variant: 0)) \(start.message)" : start.message,
                sessionID: session.id, target: .call, usesBluntTone: blunt
            )]
        }

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
    private let accountID: UUID?
    private let defaults: UserDefaults
    private var active: Bool
    private var pendingReplacement: Task<Void, Never>?
    private var pendingTest: Task<Bool, Never>?
    private var revision = 0
    private var clearBluntDeliveryRequested = false
    private var ledger: ReminderLedger

    init(accountID: UUID?, defaults: UserDefaults) {
        self.accountID = accountID
        self.defaults = defaults
        active = accountID != nil
        ledger = ReminderLedger.load(from: defaults, accountID: accountID)
    }

    func requestPermission() async -> Bool {
        guard active else { return false }
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
        let now = Date.now
        let dates = authorization.acceptsReminders ? await center.pendingNotificationRequests().compactMap { request -> Date? in
            guard request.identifier.hasPrefix(ReminderPlan.identifierPrefix),
                  let date = (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate(),
                  date > now else { return nil }
            return date
        } : []
        return ReminderDelivery(
            authorization: authorization,
            banners: settings.alertSetting == .enabled && settings.alertStyle != .none,
            lockScreen: settings.lockScreenSetting == .enabled,
            notificationCenter: settings.notificationCenterSetting == .enabled,
            sound: settings.soundSetting == .enabled,
            scheduledSummary: settings.scheduledDeliverySetting == .enabled,
            pendingCount: dates.count,
            nextReminderDate: dates.min()
        )
    }

    func settledDelivery() async -> ReminderDelivery {
        let pending = pendingReplacement
        await pending?.value
        return await deliverySettings()
    }

    func sendTest() async -> Bool {
        guard active else { return false }
        if let pendingTest { return await pendingTest.value }
        let task = Task { await queueTest() }
        pendingTest = task
        let sent = await task.value
        pendingTest = nil
        return active && sent
    }

    private func queueTest() async -> Bool {
        guard await deliverySettings().authorization.acceptsReminders, active else { return false }
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

    func replace(
        sessions: [WorkoutSession], preferences: CoachPreferences, clearBluntDelivery: Bool,
        didUpdate: @escaping @MainActor (ReminderDelivery) -> Void
    ) {
        guard active else { return }
        clearBluntDeliveryRequested = clearBluntDeliveryRequested || clearBluntDelivery
        revision += 1
        let target = revision
        let previous = pendingReplacement
        pendingReplacement = Task { @MainActor [weak self] in
            await previous?.value
            guard let self, self.revision == target else { return }
            await self.apply(sessions: sessions, preferences: preferences, revision: target)
            let delivery = await self.deliverySettings()
            guard self.revision == target else { return }
            didUpdate(delivery)
        }
    }

    func remindersAlreadyDue(at date: Date) -> [Date] {
        ledger.dueDates(at: date)
    }

    func deactivate() async {
        active = false
        revision += 1
        await pendingReplacement?.value
        _ = await pendingTest?.value
        await Self.clearAccountNotifications()
        ledger.cancelFuture(at: .now, calendar: .current)
        ledger.save(to: defaults, accountID: accountID)
    }

    static func clearAccountNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter(isAccountNotification)
        center.removePendingNotificationRequests(withIdentifiers: pending)
        let delivered = await center.deliveredNotifications().map(\.request.identifier).filter(isAccountNotification)
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }

    private static func isAccountNotification(_ identifier: String) -> Bool {
        identifier.hasPrefix(ReminderPlan.identifierPrefix) || identifier == ReminderPlan.testIdentifier
    }

    private func apply(sessions: [WorkoutSession], preferences: CoachPreferences, revision: Int) async {
        let settings = await center.notificationSettings()
        let existing = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(ReminderPlan.identifierPrefix) }
        guard revision == self.revision else { return }
        let canDeliver = [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus)
        let calendar = Calendar.current
        let now = Date.now
        let reminders = canDeliver ? ReminderPlan.make(
            sessions: sessions, preferences: preferences, now: now, calendar: calendar,
            alreadyDue: ledger.dueDates(at: now)
        ) : []
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.identifier, $0) })
        var keep: Set<String> = []
        var add: [(UNNotificationRequest, Date)] = []
        ledger.cancelFuture(at: now, calendar: calendar)
        for reminder in reminders {
            let trigger = Self.trigger(for: reminder.date, calendar: calendar)
            guard let dueAt = trigger.nextTriggerDate(), dueAt > now else { continue }
            let expected = request(for: reminder, trigger: trigger, maxIntensity: preferences.reminderIntensity == ReminderPlan.maxDailyReminders)
            if let previous = existingByID[expected.identifier],
               (previous.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() == dueAt {
                let unchanged = previous.content.title == expected.content.title
                    && previous.content.body == expected.content.body
                    && NSDictionary(dictionary: previous.content.userInfo).isEqual(to: expected.content.userInfo)
                let previousWasBlunt = previous.content.userInfo["blunt"] as? Bool == true
                // Keep a valid same-time reminder in place until the replacement is accepted.
                if unchanged || !(clearBluntDeliveryRequested && previousWasBlunt) {
                    keep.insert(expected.identifier)
                    ledger.recordScheduled(at: dueAt)
                }
                if unchanged { continue }
            }
            add.append((expected, dueAt))
        }
        let obsolete = existingByID.keys.filter { !keep.contains($0) }
        if !obsolete.isEmpty { center.removePendingNotificationRequests(withIdentifiers: Array(obsolete)) }
        ledger.save(to: defaults, accountID: accountID)
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
        for (request, dueAt) in add {
            guard revision == self.revision else { return }
            guard dueAt > .now else { continue }
            do {
                try await center.add(request)
                if !keep.contains(request.identifier) {
                    ledger.recordScheduled(at: dueAt)
                    ledger.save(to: defaults, accountID: accountID)
                }
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
        if let accountID { content.userInfo["accountID"] = accountID.uuidString }
        return content
    }
}
