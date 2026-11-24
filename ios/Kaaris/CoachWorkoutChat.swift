import SwiftUI

struct CoachWorkoutChat: View {
    var sessionID: UUID?

    @EnvironmentObject private var store: CoachStore
    @StateObject private var speech = CoachSpeech()
    @State private var selection: UUID?
    @State private var message = ""
    @State private var reply = ""
    @State private var draft: WorkoutRevision?
    @State private var usingVoice = false
    @State private var applied = false
    @FocusState private var typing: Bool

    private var sessions: [WorkoutSession] {
        store.sessions.filter { $0.canRevise && store.workoutLogs[$0.id] == nil }
    }

    private var session: WorkoutSession? {
        if let id = sessionID { return sessions.first { $0.id == id } }
        if let selection, let selected = sessions.first(where: { $0.id == selection }) { return selected }
        return sessions.first { $0.id == store.nextSession?.id } ?? sessions.first
    }

    private var microphoneActive: Bool {
        speech.recording || speech.permission == .requesting
    }

    var body: some View {
        ScrollViewReader { scroll in
            KPage {
                KTitle(text: "ADAPTE TA SÉANCE")
                if let session {
                    sessionPicker(session)
                    conversation(session)
                    if !reply.isEmpty { coachReply.id("coach-reply") }
                    if let draft { proposal(draft) }
                } else {
                    Text("Ouvre une séance prévue ou en cours pour demander une adaptation.")
                        .foregroundStyle(muted)
                }
            }
            .onChange(of: reply) { _, text in
                if !text.isEmpty { withAnimation { scroll.scrollTo("coach-reply", anchor: .top) } }
            }
        }
        .navigationTitle("Parler à KAARIS")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onChange(of: speech.transcript) { _, transcript in
            if usingVoice && !transcript.isEmpty { message = String(transcript.prefix(400)) }
        }
        .onDisappear { speech.cancel() }
    }

    private func sessionPicker(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if sessionID == nil {
                Picker("Séance à adapter", selection: Binding(
                    get: { session.id },
                    set: { id in
                        selection = id
                        speech.cancel()
                        draft = nil
                        reply = ""
                        message = ""
                        usingVoice = false
                        applied = false
                    })) {
                    ForEach(sessions) { candidate in
                        Text("\(candidate.title) · \(dateLabel(candidate.date)) · \(hourLabel(candidate.date))")
                            .tag(candidate.id)
                    }
                }
            } else {
                Text(session.title).font(.title3.bold())
            }
            Text("\(session.durationMinutes) min · \((session.equipment ?? store.profile.equipment).rawValue)")
                .font(.subheadline)
                .foregroundStyle(muted)
        }
        .kPanel()
    }

    private func conversation(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                typing = false
                if microphoneActive {
                    speech.stop()
                } else {
                    usingVoice = true
                    speech.start()
                }
            } label: {
                Label(microphoneActive ? "Arrêter l’écoute" : "Dicter une demande",
                      systemImage: microphoneActive ? "stop.circle.fill" : "mic.fill")
            }
            .buttonStyle(ActionStyle(filled: !microphoneActive))
            .disabled(speech.finishing)
            .accessibilityIdentifier("workout-coach-microphone")

            if speech.recording {
                Text("Je t’écoute…").foregroundStyle(acid).accessibilityAddTraits(.updatesFrequently)
            } else if speech.finishing {
                ProgressView("Transcription…")
            }
            if let error = speech.errorMessage {
                Text(error).font(.footnote).foregroundStyle(muted)
            }

            TextField("Demande une adaptation", text: $message, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(lineColor))
                .accessibilityIdentifier("workout-coach-input")
                .focused($typing)
                .disabled(microphoneActive || speech.finishing)
                .onChange(of: typing) { _, isTyping in
                    if isTyping { usingVoice = false }
                }

            Button(draft == nil ? "Proposer une adaptation" : "Affiner la proposition") {
                propose(message, for: session, aloud: usingVoice)
            }
            .buttonStyle(ActionStyle(filled: false))
            .accessibilityIdentifier("workout-coach-propose")
            .disabled(microphoneActive || speech.finishing || message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if draft == nil {
                ViewThatFits(in: .horizontal) {
                    HStack { examples(for: session) }
                    VStack(alignment: .leading) { examples(for: session) }
                }
                .disabled(microphoneActive || speech.finishing)
            }
        }
    }

    @ViewBuilder
    private func examples(for session: WorkoutSession) -> some View {
        ForEach(["25 minutes", "Sans matériel", "Plus facile"], id: \.self) { example in
            Button(example) { propose(example, for: session, aloud: false) }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }

    private var coachReply: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: applied ? "SÉANCE MISE À JOUR" : "KAARIS")
            Text(reply).accessibilityIdentifier("workout-coach-reply")
            Button {
                if speech.speaking { speech.stopSpeaking() } else { speech.speak(reply) }
            } label: {
                Label(speech.speaking ? "Arrêter la réponse" : "Écouter la réponse",
                      systemImage: speech.speaking ? "stop.circle" : "speaker.wave.2")
            }
            .font(.footnote.weight(.semibold))
            .disabled(microphoneActive || speech.finishing)
            Text(CoachSpeech.dynamicVoiceName).font(.caption).foregroundStyle(muted)
        }
        .kPanel()
    }

    private func proposal(_ revision: WorkoutRevision) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "PROPOSITION")
            Text(revision.revised.title).font(.headline)
            Text("\(revision.original.durationMinutes) min → \(revision.revised.durationMinutes) min · \((revision.revised.equipment ?? store.profile.equipment).rawValue)")
                .font(.subheadline).foregroundStyle(muted)
            ForEach(revision.revised.exercises) { exercise in
                VStack(alignment: .leading, spacing: 3) {
                    Text(exercise.name).font(.subheadline.bold())
                    Text(exercise.summaryText).font(.footnote).foregroundStyle(muted)
                }
            }
            Button("Appliquer à cette séance") { apply(revision) }
                .buttonStyle(ActionStyle())
                .accessibilityIdentifier("workout-coach-apply")
            Button("Annuler la proposition") {
                speech.cancel()
                draft = nil
                reply = ""
                usingVoice = false
            }
            .buttonStyle(ActionStyle(filled: false))
        }
        .kPanel()
        .disabled(microphoneActive || speech.finishing)
    }

    private func propose(_ query: String, for session: WorkoutSession, aloud: Bool) {
        typing = false
        applied = false
        speech.stopSpeaking()
        do {
            let baseline = draft?.original ?? session
            if baseline != session {
                draft = nil
                throw WorkoutRevisionError.stale
            }
            let working = draft?.revised ?? session
            let request = try WorkoutRevisionRequest(String(query.prefix(400)), currentMinutes: working.durationMinutes)
            let revised = try WorkoutPlan.adapt(working, for: store.profile, request: request)
            let proposal = WorkoutRevision(original: baseline, revised: revised)
            do {
                try store.validateWorkoutRevision(proposal)
            } catch WorkoutRevisionError.noChange {
                draft = nil
                throw WorkoutRevisionError.noChange
            }
            draft = proposal
            reply = proposal.reply
            message = ""
            usingVoice = false
        } catch {
            reply = error.localizedDescription
        }
        if aloud { speech.speak(reply) }
    }

    private func apply(_ revision: WorkoutRevision) {
        do {
            try store.applyWorkoutRevision(revision)
            draft = nil
            message = ""
            usingVoice = false
            applied = true
            reply = "Ta séance de \(revision.revised.durationMinutes) minutes est prête dans ton plan."
        } catch {
            reply = error.localizedDescription
        }
        speech.speak(reply)
    }
}
