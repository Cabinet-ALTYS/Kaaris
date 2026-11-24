import Foundation

enum PriorityWorkoutDay: String, CaseIterable {
    case pushA = "Pectoraux et triceps A"
    case pull = "Dos et biceps"
    case legs = "Jambes et abdos"
    case pushB = "Pectoraux et triceps B"
    case biceps = "Biceps B"

    fileprivate var dayOffset: Int {
        switch self {
        case .pushA: 0
        case .pull: 1
        case .legs: 3
        case .pushB: 4
        case .biceps: 5
        }
    }

    fileprivate var focus: String {
        switch self {
        case .pushA, .pushB: "Poussée · pectoraux et triceps"
        case .pull: "Tirage · dos et biceps"
        case .legs: "Quadriceps, hanches et abdos"
        case .biceps: "Biceps et marche facile"
        }
    }

    func exercises(for profile: CoachProfile, minutes: Int) -> [WorkoutExercise] {
        let gym = profile.equipment == .gym
        let short = minutes < 25
        let sets = profile.level == .beginner || short ? 2 : 3
        func lift(_ name: String, sets: Int? = nil, reps: String = "8–12", rest: Int = 90) -> WorkoutExercise {
            WorkoutExercise(name: name, sets: sets ?? (short || profile.level == .beginner ? 2 : 3), reps: reps, restSeconds: rest)
        }

        let exercises: [WorkoutExercise]
        switch self {
        case .pushA:
            exercises = [
                lift(gym ? "Développé à la machine" : "Développé haltères au sol"),
                lift("Pompes au mur, prise serrée", sets: 2, reps: "10–15", rest: 60),
                lift("Pompes inclinées", sets: 2, reps: "8–12", rest: 60),
                lift(gym ? "Développé épaules à la machine" : "Développé épaules avec haltères", sets: 2),
            ]
        case .pull:
            exercises = [
                lift(gym ? "Tirage horizontal assis" : "Rowing haltère unilatéral"),
                lift("Curl biceps avec haltères", sets: sets, reps: "10–15", rest: 60),
                lift(gym ? "Tirage vertical poitrine" : "Pull-over haltère au sol", sets: 2),
            ]
        case .legs:
            exercises = [
                lift(gym ? "Presse à cuisses" : "Goblet squat"),
                lift("Gainage ventral", sets: 2, reps: "20–30 s", rest: 60),
                lift("Soulevé de terre roumain avec haltères"),
                lift(gym ? "Mollets debout" : "Fentes arrière avec haltères",
                     sets: 2, reps: gym ? "10–15" : "8–10 / côté", rest: 60),
            ]
        case .pushB:
            exercises = [
                lift("Développé haltères au sol"),
                lift("Pompes au mur, prise serrée", sets: 2, reps: "10–15", rest: 60),
                lift("Pompes inclinées", sets: 2, reps: "8–12", rest: 60),
            ]
        case .biceps:
            return [
                lift(gym ? "Curl biceps à la poulie" : "Curl biceps avec haltères",
                     sets: sets, reps: "10–15", rest: 75),
                WorkoutExercise(name: "Marche, allure facile", sets: 1,
                                reps: "\(min(25, max(5, minutes - 10))) min", restSeconds: 0),
            ]
        }
        return Array(exercises.prefix(short ? 2 : minutes < 40 ? 3 : 4))
    }
}

enum PriorityWorkoutPlan {
    static func nextStart(for profile: CoachProfile, after date: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.date(bySettingHour: max(0, min(23, profile.preferredHour)), minute: 0, second: 0, of: date) ?? date
        if today >= date { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? date
    }

    static func week(
        for profile: CoachProfile,
        starting start: Date,
        calendar: Calendar = .current,
        excluding reserved: [WorkoutSession] = []
    ) -> [WorkoutSession] {
        var result: [WorkoutSession] = []
        let minutes = max(15, min(90, profile.sessionMinutes))
        var lastOffset = -1
        for day in PriorityWorkoutDay.allCases {
            for offset in max(day.dayOffset, lastOffset + 1)..<7 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
                let end = date.addingTimeInterval(Double(minutes) * 60)
                guard !reserved.contains(where: { $0.date < end && date < $0.endDate }) else { continue }
                result.append(WorkoutSession(title: day.rawValue, date: date, durationMinutes: minutes,
                                             focus: day.focus, exercises: day.exercises(for: profile, minutes: minutes),
                                             equipment: profile.equipment))
                lastOffset = offset
                break
            }
            if lastOffset == 6 { break }
        }
        return result
    }
}
