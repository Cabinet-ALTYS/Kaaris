import Foundation

enum WorkoutMeasure: String, Codable, Hashable {
    case repetitions, seconds, minutes

    init(_ exercise: WorkoutExercise) {
        if exercise.reps.hasSuffix(" min") { self = .minutes }
        else if exercise.reps.hasSuffix(" s") { self = .seconds }
        else { self = .repetitions }
    }

    var fieldTitle: String {
        switch self {
        case .repetitions: "Reps"
        case .seconds: "Durée (s)"
        case .minutes: "Durée (min)"
        }
    }

    var unit: String {
        switch self {
        case .repetitions: "reps"
        case .seconds: "s"
        case .minutes: "min"
        }
    }

    var validRange: ClosedRange<Int> {
        switch self {
        case .repetitions: 1...1000
        case .seconds: 1...21_600
        case .minutes: 1...360
        }
    }
}

struct LoggedSet: Codable, Equatable, Identifiable {
    let id: UUID
    let amount: Int
    let loadKg: Double?

    init(id: UUID = UUID(), amount: Int, loadKg: Double? = nil) {
        self.id = id
        self.amount = amount
        self.loadKg = loadKg
    }

    func label(for measure: WorkoutMeasure) -> String {
        let performance = "\(amount) \(measure.unit)"
        guard let loadKg else { return performance }
        return "\(performance) · \(loadKg.formatted(.number.locale(Locale(identifier: "fr_FR")))) kg"
    }
}

struct LoggedExercise: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let measure: WorkoutMeasure
    let sets: [LoggedSet]

    init(exercise: WorkoutExercise, sets: [LoggedSet]) {
        id = exercise.id
        name = exercise.name
        measure = WorkoutMeasure(exercise)
        self.sets = sets
    }
}

struct WorkoutLog: Codable, Equatable {
    let sessionID: UUID
    let performedAt: Date
    let equipment: WorkoutEquipment?
    let exercises: [LoggedExercise]

    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }

    func validate(for session: WorkoutSession, now: Date = .now) throws {
        guard sessionID == session.id, performedAt <= now,
              Set(exercises.map(\.id)).count == exercises.count else { throw WorkoutLogError.invalidRecord }

        for logged in exercises {
            guard let exercise = session.exercises.first(where: { $0.id == logged.id }),
                  logged.name == exercise.name, logged.measure == WorkoutMeasure(exercise),
                  !logged.sets.isEmpty, logged.sets.count <= WorkoutSetDraft.maxSets,
                  Set(logged.sets.map(\.id)).count == logged.sets.count else { throw WorkoutLogError.invalidRecord }
            guard logged.sets.allSatisfy({ logged.measure.validRange.contains($0.amount) && WorkoutSetDraft.validLoad($0.loadKg) }) else {
                throw WorkoutLogError.invalidRecord
            }
        }
    }
}

struct WorkoutSetDraft: Identifiable {
    static let maxSets = 20
    let id: UUID
    var amount: String
    var load: String

    init(_ recorded: LoggedSet? = nil) {
        id = recorded?.id ?? UUID()
        amount = recorded.map { String($0.amount) } ?? ""
        load = recorded?.loadKg.map { String($0).replacingOccurrences(of: ".", with: ",") } ?? ""
    }

    func logged(for measure: WorkoutMeasure) throws -> LoggedSet? {
        let countText = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        let loadText = load.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        if countText.isEmpty && loadText.isEmpty { return nil }

        guard let count = Int(countText), measure.validRange.contains(count) else {
            throw WorkoutLogError.invalidAmount(measure)
        }
        if loadText.isEmpty { return LoggedSet(id: id, amount: count) }

        let parts = loadText.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count), parts.count == 1 || parts[1].count <= 3,
              parts.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let kilograms = Double(loadText), Self.validLoad(kilograms) else { throw WorkoutLogError.invalidLoad }
        return LoggedSet(id: id, amount: count, loadKg: kilograms)
    }

    static func validLoad(_ value: Double?) -> Bool {
        guard let value else { return true }
        return value.isFinite && (0...9999).contains(value)
    }
}

enum WorkoutLogError: LocalizedError {
    case invalidAmount(WorkoutMeasure), invalidLoad, invalidRecord

    var errorDescription: String? {
        switch self {
        case .invalidAmount(let measure):
            "Indique un nombre entier de \(measure.unit) pour chaque série renseignée."
        case .invalidLoad:
            "Saisis une charge en kg, par exemple 12,5."
        case .invalidRecord:
            "Vérifie la date et les séries de cette séance."
        }
    }
}

struct ExerciseProgressKey: Hashable {
    let name: String
    let equipment: WorkoutEquipment?
    let measure: WorkoutMeasure

    var equipmentLabel: String { equipment?.rawValue ?? "Matériel non renseigné" }
}

struct ExerciseProgressEntry: Identifiable {
    let id: UUID
    let date: Date
    let sets: [LoggedSet]
}

struct ExerciseProgress: Identifiable {
    let id: ExerciseProgressKey
    let entries: [ExerciseProgressEntry]

    var usesLoad: Bool { entries.contains { $0.sets.contains { ($0.loadKg ?? 0) > 0 } } }
    var unit: String { usesLoad ? "kg" : id.measure.unit }

    func bestSet(in sets: [LoggedSet]) -> LoggedSet? {
        if usesLoad {
            return sets.filter { $0.loadKg != nil }.max { first, second in
                if first.loadKg != second.loadKg { return (first.loadKg ?? 0) < (second.loadKg ?? 0) }
                return first.amount < second.amount
            }
        }
        return sets.max { $0.amount < $1.amount }
    }

    var best: LoggedSet? { bestSet(in: entries.flatMap(\.sets)) }

    func result(in entry: ExerciseProgressEntry) -> Double? {
        guard let set = bestSet(in: entry.sets) else { return nil }
        return usesLoad ? set.loadKg : Double(set.amount)
    }

    static func make(from logs: [WorkoutLog]) -> [ExerciseProgress] {
        var series: [ExerciseProgressKey: [ExerciseProgressEntry]] = [:]
        for log in logs.sorted(by: { $0.performedAt < $1.performedAt }) {
            let exercises = Dictionary(grouping: log.exercises) {
                ExerciseProgressKey(name: $0.name, equipment: log.equipment, measure: $0.measure)
            }
            for (key, sameExercise) in exercises {
                series[key, default: []].append(ExerciseProgressEntry(
                    id: log.sessionID, date: log.performedAt, sets: sameExercise.flatMap(\.sets)
                ))
            }
        }
        return series.map { ExerciseProgress(id: $0.key, entries: $0.value) }.sorted {
            ($0.id.name, $0.id.equipmentLabel, $0.id.measure.rawValue) < ($1.id.name, $1.id.equipmentLabel, $1.id.measure.rawValue)
        }
    }
}
