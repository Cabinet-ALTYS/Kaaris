import Foundation
import SwiftUI

enum FitnessGoal: String, CaseIterable, Codable, Identifiable {
    case buildMuscle = "Prendre du muscle"
    case loseWeight = "Perdre du poids"
    case getStronger = "Gagner en force"
    case getFitter = "Me remettre en forme"

    var id: String { rawValue }
}

enum FitnessLevel: String, CaseIterable, Codable, Identifiable {
    case beginner = "Débutant"
    case intermediate = "Intermédiaire"
    case advanced = "Confirmé"

    var id: String { rawValue }
}

enum WorkoutEquipment: String, CaseIterable, Codable, Identifiable {
    case gym = "Salle de sport"
    case dumbbells = "Haltères"
    case bodyweight = "Poids du corps"

    var id: String { rawValue }
}

enum WorkoutStatus: String, CaseIterable, Codable, Identifiable {
    case planned = "Prévue"
    case checkedIn = "En cours"
    case completed = "Terminée"
    case skipped = "Passée"

    var id: String { rawValue }
}

struct CoachProfile: Codable, Equatable {
    var goal: FitnessGoal = .buildMuscle
    var level: FitnessLevel = .beginner
    var equipment: WorkoutEquipment = .gym
    var sessionsPerWeek = 3
    var sessionMinutes = 45
    var preferredHour = 18
    var heightCM: Double?
    var weightKG: Double?
    var screenMinutes: Int?
    var cigarettesPerDay: Int?
    var alcoholServingsPerWeek: Int?
    var smokingNotes = ""
    var habitNotes = ""
}

struct CoachPreferences: Codable, Equatable {
    var languageIntensity = 0
    var egoPressure = 0
    var reminderIntensity = 2
    var bluntConsent = false {
        didSet {
            if !bluntConsent {
                languageIntensity = min(languageIntensity, 1)
                bluntNotificationConsent = nil
            }
        }
    }
    var bluntNotificationConsent: Bool?
    var remindersEnabled = false
    var quietStartHour = 22
    var quietEndHour = 7
    var pausedUntil: Date?
    var onlineCoachConsent: Bool?
    var elevenLabsVoiceConsent: Bool?

    var onlineCoachConsented: Bool { onlineCoachConsent == true }
    var maxLanguageIntensity: Int { bluntConsent ? 4 : 1 }
    var effectiveLanguageIntensity: Int { max(0, min(maxLanguageIntensity, languageIntensity)) }
    var bluntNotificationsEnabled: Bool { bluntConsent && bluntNotificationConsent == true && effectiveLanguageIntensity >= 2 }

    var previewMessage: String { coachMessage() }

    func coachMessage(variant: Int = 0) -> String {
        let pressure = [
            "Tu confirmes ou tu la décales ?",
            "Rappelle-toi l’objectif que tu t’es fixé.",
            "Ton défi du jour, c’est d’y aller et de faire le premier exercice.",
            "Tu t’étais donné ta parole. Qu’est-ce que tu fais pour la tenir aujourd’hui ?"
        ]
        return "\(coachOpener(variant: variant)) \(pressure[max(0, min(3, egoPressure))])"
    }

    func coachOpener(variant: Int) -> String {
        let lines = [
            ["Tu as une séance prévue.", "On fait le point sur ta séance.", "Reviens à ton planning."],
            ["Allez, arrête de négocier.", "Tu l’as calée, cette séance. Fais le point.", "Regarde le créneau que tu as choisi."],
            ["Bouge-toi, t’avais dit que tu irais.", "Allez, fais pas traîner le pointage.", "T’as bloqué l’heure. Maintenant assume le plan."],
            ["Debout, bouffon. Tu t’étais calé une séance.", "Bouffon, t’as réservé une séance, pas une excuse.", "Arrête ton cinéma, bouffon. On fait le point."],
            ["Putain, bouge ton cul. On fait le point.", "Arrête tes conneries. T’as fixé une heure, tiens-la.", "T’as bloqué ton créneau. Alors bouge, bordel."]
        ]
        let choices = lines[effectiveLanguageIntensity]
        return choices[max(0, variant) % choices.count]
    }

    func isQuiet(at date: Date, calendar: Calendar = .current) -> Bool {
        let start = max(0, min(23, quietStartHour))
        let end = max(0, min(23, quietEndHour))
        let hour = calendar.component(.hour, from: date)
        if start < end { return (start..<end).contains(hour) }
        if start > end { return hour >= start || hour < end }
        return false
    }
}

struct WorkoutExercise: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let sets: Int
    let reps: String
    let restSeconds: Int

    init(id: UUID = UUID(), name: String, sets: Int, reps: String, restSeconds: Int) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
    }
}

struct WorkoutSession: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    var date: Date
    let durationMinutes: Int
    let focus: String
    let exercises: [WorkoutExercise]
    var status: WorkoutStatus

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        durationMinutes: Int,
        focus: String,
        exercises: [WorkoutExercise],
        status: WorkoutStatus = .planned
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.durationMinutes = durationMinutes
        self.focus = focus
        self.exercises = exercises
        self.status = status
    }

    var endDate: Date { date.addingTimeInterval(Double(durationMinutes) * 60) }
}

@MainActor
final class CoachStore: ObservableObject {
    @Published var profile: CoachProfile { didSet { save() } }
    @Published var preferences: CoachPreferences {
        didSet {
            save()
            let toneReduced = preferences.effectiveLanguageIntensity < oldValue.effectiveLanguageIntensity
            let clearBluntDelivery = oldValue.bluntNotificationsEnabled && (!preferences.bluntNotificationsEnabled || toneReduced)
            refreshReminders(clearBluntDelivery: clearBluntDelivery)
        }
    }
    @Published private(set) var sessions: [WorkoutSession] {
        didSet {
            save()
            refreshReminders()
        }
    }
    @Published private(set) var hasOnboarded: Bool { didSet { save() } }
    @Published private(set) var notificationDelivery = ReminderDelivery.initial

    let isDemo: Bool
    private let defaults: UserDefaults
    private let scheduler = ReminderScheduler()
    private static let storageKey = "kaaris.coach.v1"

    init(
        demo: Bool = ProcessInfo.processInfo.arguments.contains("--demo"),
        defaults: UserDefaults = .standard
    ) {
        isDemo = demo
        self.defaults = defaults

        if demo {
            var demoProfile = CoachProfile()
            demoProfile.sessionsPerWeek = 4
            profile = demoProfile
            var demoPreferences = CoachPreferences()
            demoPreferences.languageIntensity = 2
            demoPreferences.egoPressure = 2
            demoPreferences.reminderIntensity = 2
            demoPreferences.bluntConsent = true
            preferences = demoPreferences
            let now = Date.now
            var demoSessions = WorkoutPlan.make(for: demoProfile, from: now)
            if let first = demoSessions.first {
                demoSessions.insert(
                    WorkoutSession(
                        title: first.title,
                        date: Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now,
                        durationMinutes: first.durationMinutes,
                        focus: first.focus,
                        exercises: first.exercises,
                        status: .completed
                    ),
                    at: 0
                )
            }
            sessions = demoSessions
            hasOnboarded = true
        } else if let data = defaults.data(forKey: Self.storageKey),
                  let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
            profile = snapshot.profile
            preferences = snapshot.preferences
            sessions = snapshot.sessions
            hasOnboarded = snapshot.hasOnboarded
        } else {
            profile = CoachProfile()
            preferences = CoachPreferences()
            sessions = []
            hasOnboarded = false
        }
    }

    var nextSession: WorkoutSession? {
        sessions.first { $0.status == .checkedIn }
            ?? sessions.first { $0.status == .planned && $0.endDate > .now }
    }

    func finishOnboarding() {
        guard !hasOnboarded else { return }
        generatePlan()
        hasOnboarded = true
    }

    func generatePlan(from date: Date = .now) {
        let existing = sessions.filter { $0.status != .planned || $0.date < date }
        let reserved = existing.filter { ($0.status == .checkedIn || $0.status == .completed) && $0.endDate > date }
        sessions = (existing + WorkoutPlan.make(for: profile, from: date, excluding: reserved))
            .sorted { $0.date < $1.date }
    }

    func updateStatus(_ status: WorkoutStatus, for id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }),
              sessions[index].status != status else { return }
        sessions[index].status = status
    }

    @discardableResult
    func reschedule(_ id: UUID, to date: Date) -> Bool {
        guard let index = sessions.firstIndex(where: { $0.id == id }),
              date > .now,
              sessions[index].status == .planned || sessions[index].status == .skipped else { return false }

        var session = sessions[index]
        session.date = date
        session.status = .planned
        let conflicts = sessions.contains {
            $0.id != id && ($0.status == .planned || $0.status == .checkedIn)
                && $0.date < session.endDate && session.date < $0.endDate
        }
        guard !conflicts else { return false }
        var updated = sessions
        updated[index] = session
        sessions = updated.sorted { $0.date < $1.date }
        return true
    }

    func refreshReminders(clearBluntDelivery: Bool = false) {
        guard !isDemo else { return }
        scheduler.replace(sessions: sessions, preferences: preferences, clearBluntDelivery: clearBluntDelivery) { [weak self] delivery in
            self?.notificationDelivery = delivery
        }
        publishWidget()
    }

    func updateNotificationDelivery() async {
        notificationDelivery = isDemo ? .demo : await scheduler.settledDelivery()
    }

    @discardableResult
    func requestNotifications() async -> Bool {
        guard !isDemo else { return false }
        let authorized = await scheduler.requestPermission()
        preferences.remindersEnabled = authorized
        await updateNotificationDelivery()
        return authorized
    }

    @discardableResult
    func sendTestNotification() async -> Bool {
        guard !isDemo else { return false }
        if await scheduler.deliverySettings().authorization == .notRequested,
           !(await scheduler.requestPermission()) {
            await updateNotificationDelivery()
            return false
        }
        let sent = await scheduler.sendTest()
        await updateNotificationDelivery()
        return sent
    }

    private func save() {
        guard !isDemo else { return }
        let snapshot = Snapshot(
            profile: profile,
            preferences: preferences,
            sessions: sessions,
            hasOnboarded: hasOnboarded
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.storageKey)
        }
        publishWidget()
    }

    private func publishWidget() {
        guard hasOnboarded else { return }
        WidgetSnapshot.publish(sessions: sessions, goal: profile.sessionsPerWeek)
    }

    private struct Snapshot: Codable {
        let profile: CoachProfile
        let preferences: CoachPreferences
        let sessions: [WorkoutSession]
        let hasOnboarded: Bool
    }
}

enum WorkoutPlan {
    static func make(
        for profile: CoachProfile,
        from date: Date,
        calendar: Calendar = .current,
        excluding reserved: [WorkoutSession] = []
    ) -> [WorkoutSession] {
        let hour = max(0, min(23, profile.preferredHour))
        let days = calendar.startOfDay(for: date)
        guard let today = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: days) else { return [] }
        let startDay = today >= date ? days : calendar.date(byAdding: .day, value: 1, to: days) ?? days
        let minutes = max(15, min(90, profile.sessionMinutes))
        let layout = split(for: max(2, min(6, profile.sessionsPerWeek)), goal: profile.goal)

        var result: [WorkoutSession] = []
        var lastUsedOffset = -1
        for (dayOffset, kind) in layout {
            var offset = max(dayOffset, lastUsedOffset + 1)
            while offset < 7 {
                guard let day = calendar.date(byAdding: .day, value: offset, to: startDay),
                      let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) else { break }
                let end = start.addingTimeInterval(Double(minutes) * 60)
                if !reserved.contains(where: { $0.date < end && $0.endDate > start }) {
                    result.append(
                        WorkoutSession(
                            title: kind.title,
                            date: start,
                            durationMinutes: minutes,
                            focus: kind.focus,
                            exercises: kind.exercises(for: profile, minutes: minutes)
                        )
                    )
                    lastUsedOffset = offset
                    break
                }
                offset += 1
            }
        }
        return result
    }

    private static func split(for count: Int, goal: FitnessGoal) -> [(Int, SessionKind)] {
        let emphasizeCardio = goal == .loseWeight || goal == .getFitter
        if emphasizeCardio {
            switch count {
            case 3: return [(0, .fullA), (2, .conditioning), (4, .fullB)]
            case 4: return [(0, .fullA), (2, .conditioning), (4, .fullB), (6, .conditioning)]
            case 5: return [(0, .fullA), (1, .conditioning), (3, .fullB), (4, .conditioning), (6, .mobility)]
            case 6: return [(0, .fullA), (1, .conditioning), (2, .mobility), (3, .fullB), (4, .conditioning), (6, .mobility)]
            default: break
            }
        }
        return switch count {
        case 2: [(0, .fullA), (3, .fullB)]
        case 3: [(0, .fullA), (2, .fullB), (4, .fullA)]
        case 4: [(0, .upper), (1, .lower), (3, .upperPull), (5, .lowerHips)]
        case 5: [(0, .upper), (1, .lower), (2, .conditioning), (4, .upperPull), (5, .lowerHips)]
        default: [(0, .upper), (1, .lower), (2, .conditioning), (3, .upperPull), (4, .lowerHips), (6, .mobility)]
        }
    }
}

private enum SessionKind {
    case fullA, fullB, upper, lower, upperPull, lowerHips, conditioning, mobility

    var title: String {
        switch self {
        case .fullA: "Corps entier A"
        case .fullB: "Corps entier B"
        case .upper: "Haut du corps A"
        case .lower: "Bas du corps A"
        case .upperPull: "Haut du corps B"
        case .lowerHips: "Bas du corps B"
        case .conditioning: "Cardio modéré"
        case .mobility: "Récupération active"
        }
    }

    var focus: String {
        switch self {
        case .fullA: "Jambes, poussée, tirage"
        case .fullB: "Hanches, dos, gainage"
        case .upper: "Pectoraux, dos, épaules"
        case .lower: "Quadriceps, fessiers, mollets"
        case .upperPull: "Dos, épaules, bras"
        case .lowerHips: "Ischio-jambiers, fessiers, gainage"
        case .conditioning: "Endurance et retour au calme"
        case .mobility: "Mobilité et marche facile"
        }
    }

    func exercises(for profile: CoachProfile, minutes: Int) -> [WorkoutExercise] {
        if self == .conditioning {
            let activity = profile.equipment == .gym ? "Vélo ou tapis, allure modérée" : "Marche rapide, allure modérée"
            return [
                WorkoutExercise(name: activity, sets: 1, reps: "\(min(35, minutes - 5)) min", restSeconds: 0),
                WorkoutExercise(name: "Retour au calme, allure facile", sets: 1, reps: "5 min", restSeconds: 0)
            ]
        }
        if self == .mobility {
            return [
                WorkoutExercise(name: "Marche, allure facile", sets: 1, reps: "\(min(30, minutes - 5)) min", restSeconds: 0),
                WorkoutExercise(name: "Mobilité douce des hanches et des épaules", sets: 1, reps: "5 min", restSeconds: 0)
            ]
        }

        let count = minutes < 25 ? 2 : minutes < 40 ? 3 : 4
        let sets = profile.level == .beginner || minutes < 25 ? 2 : 3
        let strength = profile.goal == .getStronger
        let mainReps = strength && profile.equipment != .bodyweight ? "6–8" : "8–12"
        let mainRest = strength ? 120 : 90
        return moves.prefix(count).enumerated().map { index, move in
            WorkoutExercise(
                name: move.name(for: profile.equipment),
                sets: index < 2 ? sets : 2,
                reps: move.reps ?? (index < 2 ? mainReps : "10–15"),
                restSeconds: index < 2 ? mainRest : 60
            )
        }
    }

    private var moves: [Move] {
        switch self {
        case .fullA: [.squat, .press, .row, .core]
        case .fullB: [.hinge, .verticalPull, .overhead, .core]
        case .upper: [.press, .row, .overhead, .arm]
        case .lower: [.squat, .hinge, .splitSquat, .calf]
        case .upperPull: [.verticalPull, .overhead, .row, .arm]
        case .lowerHips: [.hinge, .splitSquat, .bridge, .core]
        case .conditioning, .mobility: []
        }
    }
}

private enum Move {
    case squat, press, row, core, hinge, verticalPull, overhead, arm, splitSquat, calf, bridge

    var reps: String? {
        switch self {
        case .core: "20–30 s"
        case .splitSquat: "8–10 / côté"
        case .row: "8–12"
        default: nil
        }
    }

    func name(for equipment: WorkoutEquipment) -> String {
        let variants: (gym: String, dumbbells: String, bodyweight: String)
        switch self {
        case .squat: variants = ("Presse à cuisses", "Goblet squat", "Squat au poids du corps")
        case .press: variants = ("Développé à la machine", "Développé haltères au sol", "Pompes inclinées")
        case .row: variants = ("Tirage horizontal assis", "Rowing haltère unilatéral", "Tirage des coudes au sol")
        case .core: variants = ("Gainage ventral", "Gainage ventral", "Gainage ventral")
        case .hinge: variants = ("Soulevé de terre roumain avec haltères", "Soulevé de terre roumain avec haltères", "Bascule du bassin, dos neutre")
        case .verticalPull: variants = ("Tirage vertical poitrine", "Pull-over haltère au sol", "Y-T-W au sol")
        case .overhead: variants = ("Développé épaules à la machine", "Développé épaules avec haltères", "Glissés des bras au mur")
        case .arm: variants = ("Curl biceps à la poulie", "Curl biceps avec haltères", "Pompes au mur, prise serrée")
        case .splitSquat: variants = ("Fentes arrière", "Fentes arrière avec haltères", "Fentes arrière avec appui")
        case .calf: variants = ("Mollets debout", "Mollets debout avec haltères", "Mollets debout avec appui")
        case .bridge: variants = ("Hip thrust guidé", "Pont fessier avec haltère", "Pont fessier au sol")
        }
        switch equipment {
        case .gym: return variants.gym
        case .dumbbells: return variants.dumbbells
        case .bodyweight: return variants.bodyweight
        }
    }
}
