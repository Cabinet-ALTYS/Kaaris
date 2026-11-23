import Charts
import SwiftUI

struct WorkoutLogEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: CoachStore
    @State private var performedAt: Date
    @State private var equipment: WorkoutEquipment?
    @State private var exercises: [ExerciseDraft]
    @State private var errorMessage: String?

    let session: WorkoutSession

    init(session: WorkoutSession, log: WorkoutLog?) {
        self.session = session
        let initialDate = session.status == .completed ? min(session.date, .now) : .now
        _performedAt = State(initialValue: log?.performedAt ?? initialDate)
        _equipment = State(initialValue: log == nil ? session.equipment : log?.equipment)
        _exercises = State(initialValue: session.exercises.map { exercise in
            let recorded = log?.exercises.first(where: { $0.id == exercise.id })?.sets ?? []
            let rows = recorded.isEmpty ? [WorkoutSetDraft()] : recorded.map { WorkoutSetDraft($0) }
            return ExerciseDraft(exercise: exercise, sets: rows)
        })
    }

    var body: some View {
        KPage {
            SectionLabel(text: session.title)
            KTitle(text: "MON JOURNAL.")

            VStack(alignment: .leading, spacing: 12) {
                DatePicker("Date de réalisation", selection: $performedAt, in: ...Date.now)
                    .font(.subheadline.weight(.semibold))
                Picker("Matériel utilisé", selection: $equipment) {
                    Text("Non renseigné").tag(Optional<WorkoutEquipment>.none)
                    ForEach(WorkoutEquipment.allCases) { item in Text(item.rawValue).tag(Optional(item)) }
                }
                .font(.subheadline.weight(.semibold))
            }
            .kPanel()

            if !exercises.isEmpty {
                Text("Renseigne les séries faites. La charge en kg est facultative.")
                    .font(.footnote).foregroundStyle(muted)
                ForEach($exercises) { $exercise in
                    ExerciseLogFields(draft: $exercise)
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.subheadline).foregroundStyle(acid)
            }
            Button(session.status == .completed ? "Enregistrer le journal" : "Valider la séance", action: save)
                .buttonStyle(ActionStyle())
        }
        .navigationTitle("Journal de séance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
    }

    private func save() {
        errorMessage = nil
        do {
            let logged = try exercises.compactMap { draft -> LoggedExercise? in
                do {
                    let measure = WorkoutMeasure(draft.exercise)
                    let sets = try draft.sets.compactMap { try $0.logged(for: measure) }
                    return sets.isEmpty ? nil : LoggedExercise(exercise: draft.exercise, sets: sets)
                } catch {
                    errorMessage = "\(draft.exercise.name) — \(error.localizedDescription)"
                    throw error
                }
            }
            try store.saveWorkoutLog(WorkoutLog(sessionID: session.id, performedAt: performedAt, equipment: equipment, exercises: logged))
            dismiss()
        } catch {
            if errorMessage == nil { errorMessage = error.localizedDescription }
        }
    }
}

private struct ExerciseDraft: Identifiable {
    let exercise: WorkoutExercise
    var sets: [WorkoutSetDraft]

    var id: UUID { exercise.id }
}

private struct ExerciseLogFields: View {
    @Binding var draft: ExerciseDraft

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array($draft.sets.enumerated()), id: \.element.wrappedValue.id) { index, $set in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Série \(index + 1)").font(.caption.weight(.semibold)).foregroundStyle(muted)
                        HStack(alignment: .center, spacing: 8) {
                            TextField(WorkoutMeasure(draft.exercise).fieldTitle, text: $set.amount)
                                .keyboardType(.numberPad)
                                .accessibilityLabel("Série \(index + 1), \(WorkoutMeasure(draft.exercise).fieldTitle)")
                            TextField("kg", text: $set.load)
                                .keyboardType(.decimalPad)
                                .accessibilityLabel("Série \(index + 1), charge en kg")
                            Button {
                                let rowID = set.id
                                draft.sets.removeAll { $0.id == rowID }
                            } label: {
                                Image(systemName: "minus.circle").frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Retirer la série \(index + 1)")
                        }
                        .textFieldStyle(.roundedBorder)
                    }
                }

                if draft.sets.count < WorkoutSetDraft.maxSets {
                    Button {
                        draft.sets.append(WorkoutSetDraft())
                    } label: {
                        Label("Ajouter une série", systemImage: "plus")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(acid)
                }
            }
            .padding(.top, 8)
        } label: {
            Text(draft.exercise.name).font(.headline).frame(minHeight: 44, alignment: .leading)
        }
        .kPanel()
    }
}

struct WorkoutHistoryScreen: View {
    @EnvironmentObject private var store: CoachStore
    @State private var weekOffset = 0

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: .now) ?? .now
    }

    private var completedThisWeek: [WorkoutSession] {
        store.completedSessions.filter {
            Calendar.current.isDate(store.completionDate(for: $0), equalTo: referenceDate, toGranularity: .weekOfYear)
        }
    }

    private var records: [ExerciseProgress] {
        ExerciseProgress.make(from: store.completedSessions.compactMap { store.workoutLogs[$0.id] })
    }

    var body: some View {
        KPage {
            KTitle(text: "MON BILAN.")
            weeklySummary

            SectionLabel(text: "PROGRESSION PAR EXERCICE")
            if records.isEmpty {
                Text("Renseigne une série dans le journal d’une séance pour suivre un exercice.")
                    .font(.subheadline).foregroundStyle(muted)
            }
            ForEach(records) { record in
                NavigationLink {
                    ExerciseHistoryScreen(key: record.id)
                } label: {
                    historyRow(record.id.name, detail: record.id.equipmentLabel)
                }
                .buttonStyle(.plain)
            }

            SectionLabel(text: "SÉANCES RÉALISÉES")
            if store.completedSessions.isEmpty {
                Text("Ton historique apparaîtra après ta première séance validée.")
                    .font(.subheadline).foregroundStyle(muted)
            }
            ForEach(store.completedSessions) { session in
                NavigationLink {
                    WorkoutDetail(sessionID: session.id)
                } label: {
                    historyRow(session.title, detail: sessionCaption(session))
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Bilan et historique")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var weeklySummary: some View {
        let completed = completedThisWeek
        let recordedSets = completed.reduce(0) { $0 + (store.workoutLogs[$1.id]?.setCount ?? 0) }
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: referenceDate)?.start ?? referenceDate
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { weekOffset -= 1 } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                    .accessibilityLabel("Semaine précédente")
                Spacer()
                SectionLabel(text: "SEMAINE DU \(start.formatted(.dateTime.day().month().year()))")
                Spacer()
                Button { weekOffset += 1 } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                    .accessibilityLabel("Semaine suivante")
                    .disabled(weekOffset == 0)
            }
            .buttonStyle(.plain)
            if weekOffset == 0 {
                Text("\(completed.count)/\(store.profile.sessionsPerWeek) séances réalisées").font(.title3.weight(.bold))
            } else {
                Text("\(completed.count) \(completed.count == 1 ? "séance réalisée" : "séances réalisées")").font(.title3.weight(.bold))
            }
            if recordedSets > 0 {
                Text("\(recordedSets) \(recordedSets == 1 ? "série renseignée" : "séries renseignées")")
                    .font(.caption).foregroundStyle(muted)
            }
        }
        .kPanel()
    }

    private func sessionCaption(_ session: WorkoutSession) -> String {
        let date = store.completionDate(for: session).formatted(.dateTime.day().month(.abbreviated).year())
        guard let log = store.workoutLogs[session.id] else { return "\(date) · Date prévue" }
        if log.setCount == 0 { return "\(date) · Séries non renseignées" }
        return "\(date) · \(log.setCount) \(log.setCount == 1 ? "série" : "séries")"
    }

    private func historyRow(_ title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(muted)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(acid).accessibilityHidden(true)
        }
        .kPanel()
    }
}

private struct ExerciseHistoryScreen: View {
    @EnvironmentObject private var store: CoachStore
    let key: ExerciseProgressKey

    var body: some View {
        KPage {
            SectionLabel(text: key.equipmentLabel)
            KTitle(text: key.name)
            let logs = store.completedSessions.compactMap { store.workoutLogs[$0.id] }
            if let record = ExerciseProgress.make(from: logs).first(where: { $0.id == key }) {
                exerciseHistory(record)
            } else {
                Text("Aucune série pour ce groupe d’exercice.").foregroundStyle(muted)
            }
        }
        .navigationTitle("Progression")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    @ViewBuilder
    private func exerciseHistory(_ record: ExerciseProgress) -> some View {
        let points = record.entries.compactMap { entry in
            record.result(in: entry).map { ProgressPoint(id: entry.id, date: entry.date, value: $0) }
        }
        VStack(alignment: .leading, spacing: 14) {
            if let last = record.entries.last?.sets.last {
                result(label: "Dernière série", value: last.label(for: record.id.measure))
            }
            if let best = record.best {
                result(label: "Meilleure série", value: best.label(for: record.id.measure))
            }
        }
        .kPanel()

        if points.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "MEILLEURE SÉRIE PAR SÉANCE · \(record.unit)")
                Chart(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value(record.unit, point.value))
                        .foregroundStyle(acid)
                    PointMark(x: .value("Date", point.date), y: .value(record.unit, point.value))
                        .foregroundStyle(acid)
                }
                .chartYScale(domain: 0...max(1, (points.map(\.value).max() ?? 1) * 1.1))
                .frame(height: 160)
                .accessibilityLabel("Évolution de la meilleure série en \(record.unit)")
            }
            .kPanel()
        }

        SectionLabel(text: "HISTORIQUE")
        ForEach(record.entries.reversed()) { entry in
            NavigationLink {
                WorkoutDetail(sessionID: entry.id)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.date.formatted(.dateTime.day().month(.abbreviated).year())).font(.headline)
                    ForEach(Array(entry.sets.enumerated()), id: \.offset) { index, set in
                        Text("Série \(index + 1) · \(set.label(for: record.id.measure))")
                            .font(.subheadline).foregroundStyle(muted)
                    }
                }
                .kPanel()
            }
            .buttonStyle(.plain)
        }
    }

    private func result(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(muted)
            Text(value).font(.title3.weight(.bold))
        }
    }

    private struct ProgressPoint: Identifiable {
        let id: UUID
        let date: Date
        let value: Double
    }
}
