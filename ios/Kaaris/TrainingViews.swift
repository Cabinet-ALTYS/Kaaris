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
                    Text(session.exercises.contains(where: { $0.restSeconds > 0 })
                         ? "Fais quelques minutes de mouvement facile, puis une série légère du premier exercice."
                         : "Commence à allure facile et augmente progressivement si tu es à l’aise.")
                        .font(.subheadline)
                    ForEach(session.exercises) { exercise in
                        Divider()
                        NavigationLink {
                            ExerciseGuideScreen(exercise: exercise)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(exercise.name).font(.headline)
                                    Text(exercise.summaryText)
                                        .font(.subheadline).foregroundStyle(muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(acid)
                                    .accessibilityHidden(true)
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Ouvre la démonstration et les conseils techniques")
                    }
                }
                .kPanel()

                if session.exercises.contains(where: { $0.restSeconds > 0 }) {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "EFFORT ET PROGRESSION")
                        Text(store.profile.level == .beginner
                             ? "Garde environ trois répétitions propres en réserve à la fin de chaque série."
                             : "Garde environ deux répétitions propres en réserve à la fin de chaque série.")
                        Text("Quand toutes tes séries atteignent le haut de la fourchette avec une bonne technique lors de deux séances, augmente légèrement la charge ou choisis une variante un peu plus difficile.")
                            .foregroundStyle(muted)
                    }
                    .font(.subheadline)
                    .kPanel()
                }

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
    @EnvironmentObject private var connection: KaarisConnection
    @State private var speaker = AVSpeechSynthesizer()
    @State private var showCall = false
    @State private var request: Task<Void, Never>?
    @State private var awaitingCoach = false
    @State private var modelReply: String?
    @State private var usedLocalReply = false

    private let localQuestion = "Es-tu allé à ta séance ? Qu’est-ce qui t’aiderait pour la prochaine ?"

    private var onlineContext: CoachOnlineCheckIn? {
        guard !store.isDemo, connection.coachConfigured, connection.isSignedIn,
              store.preferences.onlineCoachConsented else { return nil }
        return CoachOnlineCheckIn(preferences: store.preferences)
    }

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
        .sheet(isPresented: $showCall, onDismiss: {
            clearOnlineReply()
            speaker.stopSpeaking(at: .immediate)
        }) {
            KPage {
                SectionLabel(text: "CHECK-IN VOCAL KAARIS")
                KTitle(text: "TU EN ES OÙ ?")
                if modelReply != nil {
                    Text("Variante choisie par Gemma")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(acid)
                } else if usedLocalReply {
                    Text("Message local")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(muted)
                }
                Text(modelReply ?? localQuestion)
                    .font(.title3.weight(.semibold))
                Button {
                    let message = AVSpeechUtterance(string: "On fait le point. \(modelReply ?? localQuestion)")
                    message.voice = AVSpeechSynthesisVoice(language: "fr-FR")
                    message.rate = 0.47
                    speaker.speak(message)
                } label: {
                    Label("Écouter le coach", systemImage: "speaker.wave.2")
                }.buttonStyle(ActionStyle())
                if onlineContext != nil {
                    Button {
                        askOnlineCoach()
                    } label: {
                        if awaitingCoach {
                            ProgressView().accessibilityLabel("Réponse du coach en cours")
                        } else {
                            Label("Demander au coach en ligne", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(ActionStyle(filled: false))
                    .disabled(awaitingCoach)
                }
                Button("Fermer") { showCall = false }.buttonStyle(ActionStyle(filled: false))
            }
            .presentationDetents([.medium])
        }
        .onChange(of: onlineContext) { _, _ in clearOnlineReply() }
    }

    private func askOnlineCoach() {
        guard let context = onlineContext, !awaitingCoach else { return }
        clearOnlineReply()
        awaitingCoach = true
        request = Task {
            guard !Task.isCancelled, onlineContext == context else { return }
            let reply = await connection.coachCheckIn(context, consented: store.preferences.onlineCoachConsented)
            guard !Task.isCancelled, onlineContext == context, showCall else { return }
            modelReply = reply
            usedLocalReply = reply == nil
            awaitingCoach = false
            request = nil
        }
    }

    private func clearOnlineReply() {
        request?.cancel()
        if modelReply != nil { speaker.stopSpeaking(at: .immediate) }
        request = nil
        awaitingCoach = false
        modelReply = nil
        usedLocalReply = false
    }
}

struct FuelScreen: View {
    @EnvironmentObject private var store: CoachStore

    var body: some View {
        KPage {
            KTitle(text: "SPORT ET NUTRITION")
            goalTip
            tip(
                "Progresser en salle",
                "Commence léger et garde deux ou trois répétitions possibles en fin de série. Quand tu atteins le haut de la fourchette deux fois avec le geste bien maîtrisé, essaie le plus petit palier de charge.",
                "https://acsm.org/resistance-training-guidelines-update-2026/"
            )
            tip(
                "Avant et après la séance",
                "Prends de l’eau et, si tu as faim avant de partir, un aliment que tu digères bien. Après, reprends un repas habituel avec une source de protéines, des féculents selon ton appétit et des légumes.",
                "https://pubmed.ncbi.nlm.nih.gov/26920240/"
            )
            tip(
                "Quand la semaine est chargée",
                "Prépare deux repas faciles à refaire. Par exemple, du riz avec tofu et légumes ou des œufs avec pain complet et salade. Pour la récupération, garde un jour libre ou choisis une marche facile.",
                "https://www.mangerbouger.fr/manger-mieux/a-tout-age-et-a-chaque-etape-de-la-vie/les-recommandations-alimentaires-pour-les-adultes"
            )
        }
        .navigationTitle("Repères")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var goalTip: some View {
        switch store.profile.goal {
        case .buildMuscle, .getStronger:
            tip(
                store.profile.goal.rawValue,
                "Mange suffisamment pour soutenir l’entraînement. Choisis des sources de protéines que tu peux garder dans ta routine, comme les œufs, le yaourt, le poisson, le tofu ou les légumes secs.",
                "https://pubmed.ncbi.nlm.nih.gov/28698222/"
            )
        case .loseWeight:
            tip(
                store.profile.goal.rawValue,
                "Garde le renforcement et choisis une habitude que tu peux tenir. Tu peux préparer un repas pour les jours pressés ou remplacer une boisson sucrée par de l’eau. Observe aussi ton énergie et ta régularité.",
                "https://www.nice.org.uk/guidance/ng246/chapter/Physical-activity-and-diet"
            )
        case .getFitter:
            tip(
                store.profile.goal.rawValue,
                "Alterne le renforcement et les mouvements faciles comme la marche. Choisis une première habitude simple, par exemple prévoir une gourde ou ajouter un fruit à un repas.",
                "https://www.who.int/europe/news-room/fact-sheets/item/physical-activity"
            )
        }
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
