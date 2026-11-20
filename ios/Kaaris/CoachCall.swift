import AVFoundation
import SwiftUI

struct CoachCallInvitation: Identifiable {
    let id = UUID()
    let sessionID: UUID?
    let isTest: Bool
}

struct CoachCallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var connection: KaarisConnection
    @EnvironmentObject private var store: CoachStore
    @State private var step = Step.invitation
    @State private var speaker = AVSpeechSynthesizer()
    @State private var player: AVAudioPlayer?
    @State private var voiceRequest: Task<Void, Never>?
    @State private var meal = ""

    let invitation: CoachCallInvitation

    private var session: WorkoutSession? {
        guard let id = invitation.sessionID else { return nil }
        return store.sessions.first { $0.id == id }
    }

    private var workoutQuestion: String {
        session?.status == .checkedIn ? "Est-ce que tu as terminé ta séance ?" : "Tu es à la salle ou tu as déjà fini ta séance ?"
    }

    private var nutritionQuestion: String { "Qu’est-ce que tu as mangé aujourd’hui ?" }
    private var closingLine: String { "On se retrouve au prochain pointage." }

    private var remoteVoiceEnabled: Bool {
        !store.isDemo && connection.voiceConfigured && connection.isSignedIn && store.preferences.elevenLabsVoiceConsent == true
    }

    var body: some View {
        KPage {
            BrandMark()
            SectionLabel(text: invitation.isTest ? "Appel simulé de test" : "Appel simulé KAARIS")
            switch step {
            case .invitation: incoming
            case .workout: workout
            case .nutrition: nutrition
            case .closing: closing
            }
        }
        .presentationDetents([.large])
        .scrollDismissesKeyboard(.interactively)
        .onDisappear(perform: stopAudio)
        .onChange(of: remoteVoiceEnabled) { _, enabled in
            if !enabled { stopAudio() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stopAudio() }
        }
    }

    private var incoming: some View {
        Group {
            CoachPortrait(height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            KTitle(text: "LE COACH T’APPELLE.")
            if invitation.isTest {
                Text("Ce parcours utilise une séance fictive.")
                    .foregroundStyle(muted)
            } else if let session {
                Text("\(session.title) · \(dateLabel(session.date)) · \(hourLabel(session.date))")
                    .foregroundStyle(muted)
            }
            Button("Répondre") {
                step = .workout
                play(.greeting, fallback: "\(store.preferences.coachMessage(variant: 1)) \(workoutQuestion)")
            }
            .buttonStyle(ActionStyle())
            Button("Refuser") { dismiss() }
                .buttonStyle(ActionStyle(filled: false))
        }
    }

    private var workout: some View {
        Group {
            KTitle(text: "TA SÉANCE")
            Text(workoutQuestion).font(.title3.weight(.semibold))
            if session?.status != .checkedIn {
                Button("Je suis sur place") { answerWorkout(.checkedIn) }
                    .buttonStyle(ActionStyle())
            }
            Button("J’ai terminé") { answerWorkout(.completed) }
                .buttonStyle(ActionStyle())
            Button("Pas encore") { answerWorkout(nil) }
                .buttonStyle(ActionStyle(filled: false))
            listen(.workout, text: workoutQuestion)
        }
    }

    private var nutrition: some View {
        Group {
            KTitle(text: "TES REPAS")
            Text(nutritionQuestion).font(.title3.weight(.semibold))
            TextField("Décris un repas si tu veux", text: $meal, axis: .vertical)
                .lineLimit(2...4)
                .kPanel()
            Button("Terminer le pointage", action: finishQuestions).buttonStyle(ActionStyle())
            Button("Passer") {
                meal = ""
                finishQuestions()
            }
            .buttonStyle(ActionStyle(filled: false))
            listen(.nutrition, text: nutritionQuestion)
        }
    }

    private var closing: some View {
        Group {
            KTitle(text: "POINTAGE TERMINÉ.")
            Text(closingLine).foregroundStyle(muted)
            let foodNote = meal.trimmingCharacters(in: .whitespacesAndNewlines)
            if !foodNote.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(text: "Ton repas")
                    Text(foodNote)
                }
                .kPanel()
            }
            Button("Fermer") { dismiss() }.buttonStyle(ActionStyle())
            listen(.closing, text: closingLine)
        }
    }

    private func listen(_ phase: CoachVoicePhase, text: String) -> some View {
        Button {
            play(phase, fallback: text)
        } label: {
            Label("Écouter le coach", systemImage: "speaker.wave.2")
        }
        .buttonStyle(ActionStyle(filled: false))
    }

    private func answerWorkout(_ result: WorkoutStatus?) {
        if let result, let session, !invitation.isTest,
           session.status == .planned || session.status == .checkedIn {
            store.updateStatus(result, for: session.id)
        }
        step = .nutrition
        play(.nutrition, fallback: nutritionQuestion)
    }

    private func finishQuestions() {
        step = .closing
        play(.closing, fallback: closingLine)
    }

    private func play(_ phase: CoachVoicePhase, fallback: String) {
        stopAudio()
        guard scenePhase == .active else { return }
        guard remoteVoiceEnabled else {
            speakLocally(fallback)
            return
        }

        let preferences = store.preferences
        voiceRequest = Task {
            let data = await connection.voiceCheckIn(phase: phase, preferences: preferences)
            guard !Task.isCancelled, remoteVoiceEnabled, scenePhase == .active else { return }
            if let data, let audio = try? AVAudioPlayer(data: data), audio.play() {
                player = audio
            } else {
                speakLocally(fallback)
            }
            voiceRequest = nil
        }
    }

    private func speakLocally(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "fr-FR")
        utterance.rate = 0.47
        speaker.speak(utterance)
    }

    private func stopAudio() {
        voiceRequest?.cancel()
        voiceRequest = nil
        player?.stop()
        player = nil
        speaker.stopSpeaking(at: .immediate)
    }

    private enum Step { case invitation, workout, nutrition, closing }
}
