import AVFoundation
import SwiftUI

struct TodayScreen: View {
    @EnvironmentObject private var store: CoachStore
    @Binding var selection: KaarisTab

    private var next: WorkoutSession? {
        let upcoming = store.sessions.filter { [.planned, .checkedIn].contains($0.status) }
        return upcoming.first { $0.date >= .now } ?? upcoming.last
    }

    var body: some View {
        KPage {
            HStack {
                BrandMark()
                Spacer()
                Text(dateLabel(.now).uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .tracking(1)
                    .foregroundStyle(muted)
            }

            VStack(alignment: .leading, spacing: 3) {
                SectionLabel(text: "AUJOURD’HUI")
                KTitle(text: "PLACE À L’ACTION.")
            }

            ZStack(alignment: .bottomLeading) {
                CoachPortrait(height: 284)
                LinearGradient(colors: [.clear, .black.opacity(0.92)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 7) {
                    SectionLabel(text: "TON COACH")
                    Text(store.preferences.previewMessage)
                        .font(.system(.title3).weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.13)) }

            if let next {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            SectionLabel(text: next.date < .now ? "SÉANCE À CONFIRMER" : "PROCHAINE SÉANCE")
                            Text(next.title).font(.title3.weight(.heavy))
                            Text("\(dateLabel(next.date).capitalized) · \(next.durationMinutes) min")
                                .font(.subheadline).foregroundStyle(muted)
                        }
                        Spacer(minLength: 6)
                        Text(hourLabel(next.date)).font(.system(size: 26, weight: .black, design: .monospaced))
                    }
                    NavigationLink {
                        WorkoutDetail(sessionID: next.id)
                    } label: {
                        Label("Voir ma séance", systemImage: "arrow.up.right")
                    }
                    .buttonStyle(ActionStyle())
                }
                .kPanel()
            } else {
                Button("Voir mon programme") { selection = .plan }.buttonStyle(ActionStyle())
            }
        }
    }
}

struct PlanScreen: View {
    @EnvironmentObject private var store: CoachStore
    @State private var showNewPlan = false

    private var planned: [WorkoutSession] {
        store.sessions.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .weekOfYear) }
    }

    var body: some View {
        KPage {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    SectionLabel(text: "ENTRAÎNEMENT")
                    KTitle(text: "MON PLAN.")
                }
                Spacer()
                NavigationLink {
                    AgendaScreen()
                } label: {
                    Image(systemName: "calendar.badge.plus").font(.system(size: 20, weight: .semibold))
                        .frame(width: 46, height: 46)
                        .background(panel, in: RoundedRectangle(cornerRadius: 13))
                }
                .accessibilityLabel("Google Agenda")
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "CETTE SEMAINE")
                HStack(alignment: .firstTextBaseline) {
                    Text("\(planned.filter { $0.status == .completed }.count)/\(store.profile.sessionsPerWeek)")
                        .font(.system(size: 38, weight: .black, design: .monospaced))
                    Text("séances terminées").font(.subheadline).foregroundStyle(muted)
                }
                ProgressView(value: Double(min(planned.filter { $0.status == .completed }.count, store.profile.sessionsPerWeek)), total: Double(max(1, store.profile.sessionsPerWeek)))
            }
            .kPanel()

            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "TES SÉANCES")
                if store.sessions.isEmpty {
                    Text("Aucune séance. Crée ton programme pour définir tes créneaux.").foregroundStyle(muted)
                }
                ForEach(store.sessions.sorted { $0.date < $1.date }) { session in
                    NavigationLink {
                        WorkoutDetail(sessionID: session.id)
                    } label: {
                        HStack(spacing: 14) {
                            VStack(spacing: 1) {
                                Text(session.date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "fr_FR"))).uppercased())
                                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                                    .foregroundStyle(acid)
                                Text(session.date.formatted(.dateTime.day()))
                                    .font(.system(size: 23, weight: .heavy, design: .monospaced))
                            }
                            .frame(width: 47)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title).font(.headline)
                                Text("\(hourLabel(session.date)) · \(session.durationMinutes) min · \(displayStatus(session))")
                                    .font(.caption).foregroundStyle(muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(muted)
                        }
                        .kPanel()
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Générer la prochaine semaine") { showNewPlan = true }
                .buttonStyle(ActionStyle(filled: false))
        }
        .confirmationDialog("Créer un programme à partir d’aujourd’hui ?", isPresented: $showNewPlan, titleVisibility: .visible) {
            Button("Générer les séances") { store.generatePlan() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("KAARIS applique ton objectif, ta fréquence et ton matériel enregistrés.")
        }
    }

    private func displayStatus(_ session: WorkoutSession) -> String {
        if session.status == .planned, session.date < .now { return "À confirmer" }
        return session.status.rawValue
    }
}

struct WorkoutDetail: View {
    @EnvironmentObject private var store: CoachStore
    let sessionID: UUID
    @State private var showDate = false
    @State private var newDate = Date.now
    @State private var showGymCheckIn = false
    @State private var dateConflict = false

    var body: some View {
        KPage {
            if let session = store.sessions.first(where: { $0.id == sessionID }) {
                SectionLabel(text: "\(dateLabel(session.date)) · \(hourLabel(session.date))")
                KTitle(text: session.title.uppercased())
                Text("\(session.focus) · \(session.durationMinutes) min").foregroundStyle(muted)

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(text: "ÉCHAUFFEMENT")
                    Text("Commence par quelques minutes de mouvement facile et une série légère du premier exercice.")
                        .font(.subheadline)
                    ForEach(session.exercises) { exercise in
                        Divider()
                        VStack(alignment: .leading, spacing: 5) {
                            Text(exercise.name).font(.headline)
                            Text("\(exercise.sets) séries · \(exercise.reps) · repos \(exercise.restSeconds) s")
                                .font(.subheadline).foregroundStyle(muted)
                        }
                    }
                }
                .kPanel()

                if session.status == .planned {
                    Button("J’y suis") { store.updateStatus(.checkedIn, for: sessionID) }
                        .buttonStyle(ActionStyle())
                    Button("Vérifier ma proximité") { showGymCheckIn = true }
                        .buttonStyle(ActionStyle(filled: false))
                }
                if session.status == .checkedIn || session.status == .planned {
                    Button("Séance terminée") { store.updateStatus(.completed, for: sessionID) }
                        .buttonStyle(ActionStyle(filled: session.status == .checkedIn))
                    HStack {
                        Button("Reporter") {
                            newDate = max(.now, session.date)
                            showDate = true
                        }.buttonStyle(ActionStyle(filled: false))
                        Button("Passer") { store.updateStatus(.skipped, for: sessionID) }
                            .buttonStyle(ActionStyle(filled: false))
                    }
                } else {
                    Label(session.status.rawValue, systemImage: session.status == .completed ? "checkmark.circle" : "forward.end")
                        .foregroundStyle(acid)
                }
            } else {
                Text("Séance indisponible.")
            }
        }
        .navigationTitle("Séance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .sheet(isPresented: $showGymCheckIn) {
            GymCheckInSheet { store.updateStatus(.checkedIn, for: sessionID) }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDate) {
            KPage {
                KTitle(text: "REPORTER")
                DatePicker("Nouveau créneau", selection: $newDate, in: Date.now...)
                Button("Enregistrer") {
                    if store.reschedule(sessionID, to: newDate) {
                        showDate = false
                    } else {
                        dateConflict = true
                    }
                }
                .buttonStyle(ActionStyle())
                if dateConflict { Text("Choisis un créneau futur sans chevauchement.").foregroundStyle(muted) }
            }
            .presentationDetents([.medium])
        }
    }
}

struct CoachScreen: View {
    @EnvironmentObject private var store: CoachStore
    @State private var speaker = AVSpeechSynthesizer()
    @State private var showCall = false

    var body: some View {
        KPage {
            VStack(alignment: .leading, spacing: 3) {
                SectionLabel(text: "POINTAGE")
                KTitle(text: "ON FAIT LE POINT.")
            }
            ZStack(alignment: .bottomLeading) {
                CoachPortrait(height: 290)
                LinearGradient(colors: [.clear, .black.opacity(0.91)], startPoint: .center, endPoint: .bottom)
                Text("Ta séance, tu en es où ?")
                    .font(.system(.title2).weight(.heavy))
                    .padding(18)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            Button {
                showCall = true
            } label: {
                Label("Lancer le check-in vocal", systemImage: "waveform")
            }
            .buttonStyle(ActionStyle())

            if let session = store.sessions
                .filter({ $0.status == .planned || $0.status == .checkedIn })
                .min(by: { abs($0.date.timeIntervalSinceNow) < abs($1.date.timeIntervalSinceNow) }) {
                NavigationLink {
                    WorkoutDetail(sessionID: session.id)
                } label: {
                    Label("Mettre à jour ma séance", systemImage: "checkmark.circle")
                }
                .buttonStyle(ActionStyle(filled: false))
            }

            NavigationLink {
                FuelScreen()
            } label: {
                Label("Repères sport et nutrition", systemImage: "book")
            }
            .buttonStyle(ActionStyle(filled: false))
        }
        .sheet(isPresented: $showCall, onDismiss: { speaker.stopSpeaking(at: .immediate) }) {
            KPage {
                SectionLabel(text: "CHECK-IN VOCAL KAARIS")
                KTitle(text: "TU EN ES OÙ ?")
                Text("Es-tu allé à ta séance ? Qu’est-ce qui t’aiderait pour la prochaine ?")
                    .font(.title3.weight(.semibold))
                Button {
                    let message = AVSpeechUtterance(string: "On fait le point. Es-tu allé à ta séance ? Qu’est-ce qui t’aiderait pour la prochaine ?")
                    message.voice = AVSpeechSynthesisVoice(language: "fr-FR")
                    message.rate = 0.47
                    speaker.speak(message)
                } label: {
                    Label("Écouter le coach", systemImage: "speaker.wave.2")
                }.buttonStyle(ActionStyle())
                Button("Fermer") { showCall = false }.buttonStyle(ActionStyle(filled: false))
            }
            .presentationDetents([.medium])
        }
    }
}

struct FuelScreen: View {
    var body: some View {
        KPage {
            KTitle(text: "LES BASES.")
            tip("Gagner du muscle", "Entraîne chaque groupe régulièrement. Note tes répétitions et augmente la charge progressivement quand le geste reste solide. Mange assez et varie les sources de protéines.", "https://acsm.org/resistance-training-guidelines-update-2026/")
            tip("Perdre du poids", "Si la perte de poids correspond à ta situation, travaille sur des habitudes durables et garde des exercices de renforcement. Le suivi du poids est facultatif.", "https://www.nice.org.uk/guidance/ng246/chapter/Physical-activity-and-diet")
            tip("Manger au quotidien", "Construis tes repas avec une variété d’aliments que tu aimes. Alterne légumes, fruits, féculents complets et sources de protéines. L’eau reste la boisson de référence.", "https://www.mangerbouger.fr/manger-mieux/a-tout-age-et-a-chaque-etape-de-la-vie/les-recommandations-alimentaires-pour-les-adultes")
        }
        .navigationTitle("Repères")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func tip(_ title: String, _ content: String, _ source: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.weight(.bold))
            Text(content).foregroundStyle(muted)
            if let url = URL(string: source) { Link("Consulter la source", destination: url) }
        }
        .kPanel()
    }
}
