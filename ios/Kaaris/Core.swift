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
    var sessionsPerWeek = 5
    var upperBodyPriorityPlan: Bool? = true
    var sessionMinutes = 45
    var preferredHour = 18
    var heightCM: Double?
    var weightKG: Double?
    var screenMinutes: Int?
    var cigarettesPerDay: Int?
    var alcoholServingsPerWeek: Int?
    var smokingNotes = ""
    var habitNotes = ""

    var usesPriorityPlan: Bool {
        upperBodyPriorityPlan == true && sessionsPerWeek == 5 && equipment != .bodyweight
    }
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
    let equipment: WorkoutEquipment?

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        durationMinutes: Int,
        focus: String,
        exercises: [WorkoutExercise],
        status: WorkoutStatus = .planned,
        equipment: WorkoutEquipment? = nil
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.durationMinutes = durationMinutes
        self.focus = focus
        self.exercises = exercises
        self.status = status
        self.equipment = equipment
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
    @Published private(set) var workoutLogs: [UUID: WorkoutLog] = [:]

    let isDemo: Bool
    private let defaults: UserDefaults
    private let scheduler = ReminderScheduler()
    private static let storageKey = "kaaris.coach.v1"
    private var nextPriorityWeek: Date?

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
                        status: .completed,
                        equipment: first.equipment
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
            workoutLogs = snapshot.workoutLogs ?? [:]
            nextPriorityWeek = snapshot.nextPriorityWeek
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
        if profile.usesPriorityPlan {
            let start = PriorityWorkoutPlan.nextStart(for: profile, after: date)
            schedulePriorityWeeks(2, from: start, keeping: existing)
            return
        }
        nextPriorityWeek = nil
        let reserved = existing.filter { ($0.status == .checkedIn || $0.status == .completed) && $0.endDate > date }
        sessions = (existing + WorkoutPlan.make(for: profile, from: date, excluding: reserved))
            .sorted { $0.date < $1.date }
    }

    func activatePriorityPlan() {
        guard profile.equipment != .bodyweight else { return }
        var updated = profile
        updated.sessionsPerWeek = 5
        updated.upperBodyPriorityPlan = true
        profile = updated
        generatePlan()
    }

    func replenishPriorityPlan(now: Date = .now) {
        let calendar = Calendar.current
        guard profile.usesPriorityPlan, let next = nextPriorityWeek,
              let horizon = calendar.date(byAdding: .day, value: 7, to: now), next <= horizon else { return }
        let missedWeek = next < now
        let start = missedWeek ? PriorityWorkoutPlan.nextStart(for: profile, after: now, calendar: calendar) : next
        schedulePriorityWeeks(missedWeek ? 2 : 1, from: start, keeping: sessions, calendar: calendar)
    }

    private func schedulePriorityWeeks(_ count: Int, from start: Date, keeping existing: [WorkoutSession],
                                       calendar: Calendar = .current) {
        var schedule = existing
        var anchor = start
        for _ in 0..<count {
            guard let next = calendar.date(byAdding: .day, value: 7, to: anchor) else { break }
            let reserved = schedule.filter { $0.status != .skipped && $0.endDate > anchor }
            schedule += PriorityWorkoutPlan.week(for: profile, starting: anchor, calendar: calendar, excluding: reserved)
            anchor = next
        }
        nextPriorityWeek = anchor
        sessions = schedule.sorted { $0.date < $1.date }
    }

    func updateStatus(_ status: WorkoutStatus, for id: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == id }),
              sessions[index].status != status else { return }
        if status == .completed, workoutLogs[id] == nil {
            workoutLogs[id] = WorkoutLog(sessionID: id, performedAt: .now, equipment: sessions[index].equipment, exercises: [])
        }
        sessions[index].status = status
    }

    func saveWorkoutLog(_ log: WorkoutLog) throws {
        guard let index = sessions.firstIndex(where: { $0.id == log.sessionID }) else { throw WorkoutLogError.invalidRecord }
        try log.validate(for: sessions[index])
        workoutLogs[log.sessionID] = log
        if sessions[index].status == .completed {
            save()
        } else {
            sessions[index].status = .completed
        }
    }

    var completedSessions: [WorkoutSession] {
        sessions.filter { $0.status == .completed }.sorted { completionDate(for: $0) > completionDate(for: $1) }
    }

    func completionDate(for session: WorkoutSession) -> Date {
        workoutLogs[session.id]?.performedAt ?? session.date
    }

    func validateWorkoutRevision(_ revision: WorkoutRevision) throws {
        guard let current = sessions.first(where: { $0.id == revision.original.id }),
              current == revision.original else { throw WorkoutRevisionError.stale }
        guard current.canRevise, workoutLogs[current.id] == nil else { throw WorkoutRevisionError.inactive }
        let proposed = revision.revised
        guard proposed.id == current.id, proposed.date == current.date, proposed.status == current.status,
              (10...90).contains(proposed.durationMinutes), !proposed.exercises.isEmpty else {
            throw WorkoutRevisionError.inactive
        }
        guard proposed != current else { throw WorkoutRevisionError.noChange }
        guard !sessions.contains(where: {
            $0.id != current.id && $0.canRevise && $0.date < proposed.endDate && proposed.date < $0.endDate
        }) else { throw WorkoutRevisionError.conflict }
    }

    func applyWorkoutRevision(_ revision: WorkoutRevision) throws {
        try validateWorkoutRevision(revision)
        guard let index = sessions.firstIndex(where: { $0.id == revision.original.id }) else {
            throw WorkoutRevisionError.stale
        }
        sessions[index] = revision.revised
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
            hasOnboarded: hasOnboarded,
            workoutLogs: workoutLogs,
            nextPriorityWeek: nextPriorityWeek
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.storageKey)
        }
        publishWidget()
    }

    private func publishWidget() {
        guard hasOnboarded else { return }
        let widgetSessions = sessions.map { session in
            guard session.status == .completed else { return session }
            var completed = session
            completed.date = completionDate(for: session)
            return completed
        }
        WidgetSnapshot.publish(sessions: widgetSessions, goal: profile.sessionsPerWeek)
    }

    struct Snapshot: Codable {
        let profile: CoachProfile
        let preferences: CoachPreferences
        let sessions: [WorkoutSession]
        let hasOnboarded: Bool
        let workoutLogs: [UUID: WorkoutLog]?
        let nextPriorityWeek: Date?
    }
}

enum WorkoutPlan {
    static func make(
        for profile: CoachProfile,
        from date: Date,
        calendar: Calendar = .current,
        excluding reserved: [WorkoutSession] = []
    ) -> [WorkoutSession] {
        if profile.usesPriorityPlan {
            let start = PriorityWorkoutPlan.nextStart(for: profile, after: date, calendar: calendar)
            return PriorityWorkoutPlan.week(for: profile, starting: start, calendar: calendar, excluding: reserved)
        }
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
                            exercises: kind.exercises(for: profile, minutes: minutes),
                            equipment: profile.equipment
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

    static func adapt(_ session: WorkoutSession, for profile: CoachProfile, request: WorkoutRevisionRequest) throws -> WorkoutSession {
        let sourceEquipment = session.equipment ?? profile.equipment
        let equipment = request.equipment ?? sourceEquipment
        let minutes = request.minutes ?? session.durationMinutes
        var newProfile = profile
        newProfile.equipment = equipment

        let oldKind = SessionKind.allCases.first { $0.title == session.title }
        let kind = request.focus.map(SessionKind.init(focus:)) ?? oldKind
        let refocus = request.focus != nil && kind != oldKind
        var exercises = session.exercises
        if refocus, let kind {
            exercises = kind.exercises(for: newProfile, minutes: minutes)
        } else if let day = PriorityWorkoutDay(rawValue: session.title), equipment != sourceEquipment, equipment != .bodyweight {
            exercises = day.exercises(for: newProfile, minutes: minutes)
        } else if let kind, kind == .conditioning || kind == .mobility,
                  equipment != sourceEquipment || minutes != session.durationMinutes {
            exercises = kind.exercises(for: newProfile, minutes: minutes)
        } else {
            if equipment != sourceEquipment {
                exercises = try exercises.map { exercise in
                    guard let move = Move.containing(exercise.name) else {
                        if exercise.restSeconds == 0 { return exercise }
                        throw WorkoutRevisionError.unsupported("Choisis aussi un type de séance pour adapter ces exercices à ton matériel.")
                    }
                    if exercise.name == "Pompes au mur, prise serrée" { return exercise }
                    if move == .arm, equipment == .bodyweight {
                        throw WorkoutRevisionError.unsupported("Pour garder le travail direct des biceps, il faut des haltères ou une poulie. Tu peux aussi demander un autre type de séance.")
                    }
                    return exercise.revised(name: move.name(for: equipment))
                }
                var included: Set<String> = []
                exercises = exercises.filter { included.insert($0.name).inserted }
            }
            if minutes < session.durationMinutes, exercises.contains(where: { $0.restSeconds > 0 }) {
                let maximumExercises = minutes < 25 ? 2 : minutes < 40 ? 3 : 4
                exercises = Array(exercises.prefix(maximumExercises))
                if minutes < 25 { exercises = exercises.map { $0.revised(sets: min(2, $0.sets)) } }
            }
        }

        if let target = request.target {
            let names = exercises.map(\.name)
            let matches = WorkoutRevisionRequest.matchingExercise(target, in: names)
            guard matches.count == 1, let name = matches.first, let index = names.firstIndex(of: name) else {
                throw WorkoutRevisionError.unsupported("Précise le nom de l’exercice dans la séance proposée.")
            }
            if let replacement = request.replacement {
                let alternatives = Move.containing(name).map { move in
                    WorkoutEquipment.allCases.map { move.name(for: $0) }.filter { $0 != name }
                } ?? []
                let allowed = Move.allCases.flatMap { move in
                    switch equipment {
                    case .gym: WorkoutEquipment.allCases.map { move.name(for: $0) }
                    case .dumbbells: [move.name(for: .dumbbells), move.name(for: .bodyweight)]
                    case .bodyweight: [move.name(for: .bodyweight)]
                    }
                }
                let choices: [String]
                if replacement.isEmpty {
                    choices = alternatives.filter { allowed.contains($0) && !names.contains($0) }
                } else {
                    choices = WorkoutRevisionRequest.matchingExercise(replacement, in: Array(Set(allowed))).filter { !names.contains($0) }
                }
                guard let choice = choices.first, replacement.isEmpty || choices.count == 1 else {
                    throw WorkoutRevisionError.unsupported("Indique un autre exercice compatible avec le matériel de la séance.")
                }
                let exercise = exercises[index]
                let reps = Move.containing(choice)?.reps ?? "8–12"
                exercises[index] = exercise.revised(name: choice, reps: reps, restSeconds: max(60, exercise.restSeconds))
            } else {
                guard exercises.count > 1 else {
                    throw WorkoutRevisionError.unsupported("La séance doit garder un exercice. Tu peux demander de le remplacer.")
                }
                exercises.remove(at: index)
            }
        }

        if let effort = request.effort {
            exercises = exercises.map { exercise in
                if exercise.restSeconds > 0 {
                    let sets = effort == .lighter ? max(1, exercise.sets - 1) : max(exercise.sets, min(minutes < 25 ? 2 : 4, exercise.sets + 1))
                    return exercise.revised(sets: sets)
                }
                guard exercise.reps.hasSuffix(" min"),
                      let duration = Int(exercise.reps.dropLast(4)), duration > 5 else { return exercise }
                let adjusted = effort == .lighter ? max(5, duration - 5) : min(minutes - 5, duration + 5)
                return exercise.revised(reps: "\(adjusted) min")
            }
        }

        let result = WorkoutSession(
            id: session.id, title: refocus ? kind?.title ?? session.title : session.title,
            date: session.date, durationMinutes: minutes, focus: refocus ? kind?.focus ?? session.focus : session.focus,
            exercises: exercises, status: session.status, equipment: request.equipment ?? session.equipment
        )
        guard result != session else { throw WorkoutRevisionError.noChange }
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

private enum SessionKind: CaseIterable {
    case fullA, fullB, upper, lower, upperPull, lowerHips, conditioning, mobility

    init(focus: WorkoutRevisionFocus) {
        self = switch focus {
        case .fullBody: .fullA
        case .upperBody: .upper
        case .lowerBody: .lower
        case .cardio: .conditioning
        case .recovery: .mobility
        }
    }

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

private enum Move: CaseIterable {
    case squat, press, row, core, hinge, verticalPull, overhead, arm, splitSquat, calf, bridge

    var reps: String? {
        switch self {
        case .core: "20–30 s"
        case .splitSquat: "8–10 / côté"
        case .row: "8–12"
        default: nil
        }
    }

    static func containing(_ name: String) -> Self? {
        allCases.first { move in WorkoutEquipment.allCases.contains { move.name(for: $0) == name } }
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

extension WorkoutSession {
    var canRevise: Bool { status == .planned || status == .checkedIn }
}

private extension WorkoutExercise {
    func revised(name: String? = nil, sets: Int? = nil, reps: String? = nil, restSeconds: Int? = nil) -> Self {
        let name = name ?? self.name
        return Self(id: name == self.name ? id : UUID(), name: name, sets: sets ?? self.sets,
                    reps: reps ?? self.reps, restSeconds: restSeconds ?? self.restSeconds)
    }
}
