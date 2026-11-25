import SwiftUI
import UIKit

struct OnboardingScreen: View {
    @EnvironmentObject private var store: CoachStore
    @State private var isAdult = false
    @State private var step = 0
    @State private var wantsReminders = false
    @State private var finishing = false

    var body: some View {
        KPage {
            BrandMark()

            if step == 0 {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "TON COACH SPORTIF")
                    KTitle(text: "TU L’AS DIT.\nTU LE FAIS.")
                }

                CoachPortrait(height: 278).clipShape(RoundedRectangle(cornerRadius: 20))
                Text("Construis tes séances, fixe tes créneaux et fais le point avec le coach.")
                    .foregroundStyle(muted)

                Toggle("Je confirme avoir 18 ans ou plus", isOn: $isAdult)
                    .font(.subheadline.weight(.semibold))

                Button("Définir mon objectif") { step = 1 }
                    .buttonStyle(ActionStyle())
                    .disabled(!isAdult)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    SectionLabel(text: "TON PROGRAMME")
                    KTitle(text: "ON PART D’OÙ ?")
                }
                ProfileFields(profile: $store.profile)
                Toggle("J’accepte un langage cru du coach", isOn: $store.preferences.bluntConsent)
                    .font(.subheadline.weight(.semibold))
                Toggle("Je veux recevoir les relances de mes séances", isOn: $wantsReminders)
                    .font(.subheadline.weight(.semibold))
                Button("Créer mes séances") {
                    guard wantsReminders else {
                        store.finishOnboarding()
                        return
                    }
                    finishing = true
                    Task {
                        await store.requestNotifications()
                        store.finishOnboarding()
                        finishing = false
                    }
                }
                .buttonStyle(ActionStyle())
                .disabled(finishing)
                Button("Retour") { step = 0 }.buttonStyle(ActionStyle(filled: false))
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

struct ProfileFields: View {
    @Binding var profile: CoachProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Picker("Objectif", selection: $profile.goal) {
                ForEach(FitnessGoal.allCases) { goal in Text(goal.rawValue).tag(goal) }
            }
            Picker("Niveau", selection: $profile.level) {
                ForEach(FitnessLevel.allCases) { level in Text(level.rawValue).tag(level) }
            }
            Picker("Matériel", selection: $profile.equipment) {
                ForEach(WorkoutEquipment.allCases) { equipment in Text(equipment.rawValue).tag(equipment) }
            }
            Stepper("\(profile.sessionsPerWeek) séances par semaine", value: $profile.sessionsPerWeek, in: 2...6)
                .accessibilityIdentifier("weeklyFrequency")
            Stepper("\(profile.sessionMinutes) min par séance", value: $profile.sessionMinutes, in: 20...90, step: 5)
            Picker("Heure préférée", selection: $profile.preferredHour) {
                ForEach(6...23, id: \.self) { Text(String(format: "%02d h", $0)).tag($0) }
            }
        }
        .font(.subheadline.weight(.medium))
        .kPanel()

        DisclosureGroup("Habitudes et mesures (facultatif)") {
            VStack(spacing: 16) {
                Text("Ces champs sont enregistrés sur cet iPhone. Tu peux les laisser vides ou effacer leur valeur.")
                    .font(.caption).foregroundStyle(muted).frame(maxWidth: .infinity, alignment: .leading)
                number("Taille (cm)", value: $profile.heightCM, range: 50...300)
                number("Poids (kg)", value: $profile.weightKG, range: 20...700)
                integer("Temps d’écran (min/jour)", value: $profile.screenMinutes, range: 0...1440)
                integer("Cigarettes (par jour)", value: $profile.cigarettesPerDay, range: 0...500)
                integer("Alcool (verres/semaine)", value: $profile.alcoholServingsPerWeek, range: 0...500)
                TextField("Tabac et autres consommations", text: $profile.smokingNotes, axis: .vertical)
                TextField("Habitudes à travailler", text: $profile.habitNotes, axis: .vertical)
            }
            .padding(.top, 12)
            .foregroundStyle(.white)
        }
        .font(.subheadline.weight(.semibold))
        .kPanel()
    }

    private func number(_ label: String, value: Binding<Double?>, range: ClosedRange<Double>) -> some View {
        OptionalNumberField(label: label, value: value, range: range)
    }

    private func integer(_ label: String, value: Binding<Int?>, range: ClosedRange<Int>) -> some View {
        OptionalNumberField(label: label, value: Binding(
            get: { value.wrappedValue.map(Double.init) },
            set: { value.wrappedValue = $0.map(Int.init) }
        ), range: Double(range.lowerBound)...Double(range.upperBound), allowsDecimal: false)
    }
}

private struct OptionalNumberField: View {
    let label: String
    @Binding var value: Double?
    let range: ClosedRange<Double>
    var allowsDecimal = true
    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(label, text: $input)
                .keyboardType(allowsDecimal ? .decimalPad : .numberPad)
                .focused($focused)
                .onAppear { input = value.map { $0.formatted(.number.locale(Locale(identifier: "fr_FR"))) } ?? "" }
                .onChange(of: input) { _, text in
                    if text.isEmpty {
                        value = nil
                    } else if let parsed, range.contains(parsed) {
                        value = parsed
                    } else {
                        value = nil
                    }
                }
            if focused && !input.isEmpty && value == nil {
                Text("Valeur attendue entre \(range.lowerBound.formatted()) et \(range.upperBound.formatted()).")
                    .font(.caption).foregroundStyle(muted)
            }
        }
    }

    private var parsed: Double? {
        let raw = input.filter { !$0.isWhitespace }.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(raw), amount.isFinite, allowsDecimal || amount.rounded() == amount else { return nil }
        return amount
    }
}

struct SettingsScreen: View {
    @EnvironmentObject private var store: CoachStore
    @EnvironmentObject private var connection: KaarisConnection
    @Environment(\.openURL) private var openURL
    @State private var checkingNotifications = false
    @State private var notificationFeedback: String?

    var body: some View {
        KPage {
            VStack(alignment: .leading, spacing: 3) {
                SectionLabel(text: "SUR MESURE")
                KTitle(text: "À TON RYTHME.")
            }

            VStack(alignment: .leading, spacing: 5) {
                SectionLabel(text: "APERÇU DU COACH")
                Text(store.preferences.previewMessage).font(.title3.weight(.heavy)).fixedSize(horizontal: false, vertical: true)
            }
            .kPanel()

            VStack(alignment: .leading, spacing: 16) {
                slider("Langage", labels: ["Neutre", "Direct", "Familier", "Grossier", "Très grossier"],
                       value: $store.preferences.languageIntensity, maxValue: store.preferences.maxLanguageIntensity)
                Toggle("Autoriser le langage cru", isOn: $store.preferences.bluntConsent)
                    .font(.subheadline)
                Divider()
                slider("Relances par séance", labels: ["0 · Coupées", "1 · Avant", "2 · Pointage", "3 · Suivi", "4 · Préparation", "5 · Maximum"],
                       value: $store.preferences.reminderIntensity, maxValue: ReminderPlan.maxDailyReminders)
                Text("Cinq relances par jour au maximum.")
                    .font(.footnote).foregroundStyle(muted)
                Divider()
                slider("Pression sur l’ego", labels: ["Factuelle", "Objectif", "Défi", "Parole donnée"],
                       value: $store.preferences.egoPressure)
            }
            .kPanel()

            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "NOTIFICATIONS")
                Text(store.notificationDelivery.authorization.label)
                    .font(.headline)
                if store.isDemo {
                    Text("Le mode démo n’envoie aucune notification.")
                        .font(.footnote).foregroundStyle(muted)
                }
                if store.notificationDelivery.authorization.acceptsReminders {
                    deliveryDetails
                    queuedReminders
                }
                if store.preferences.remindersEnabled {
                    Button("Désactiver les relances") { store.preferences.remindersEnabled = false }
                        .buttonStyle(ActionStyle(filled: false))
                } else if store.notificationDelivery.authorization != .denied {
                    Button("Activer les relances") {
                        checkingNotifications = true
                        Task {
                            let enabled = await store.requestNotifications()
                            notificationFeedback = enabled ? nil : "Les relances restent désactivées."
                            checkingNotifications = false
                        }
                    }
                    .buttonStyle(ActionStyle(filled: false))
                    .disabled(store.isDemo || checkingNotifications)
                }

                if store.notificationDelivery.authorization == .denied || store.notificationDelivery.authorization.acceptsReminders {
                    Button("Ouvrir les réglages iOS") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .buttonStyle(ActionStyle(filled: false))
                }
                if store.notificationDelivery.authorization.acceptsReminders || store.notificationDelivery.authorization == .notRequested {
                    Button("Envoyer une notification de test") {
                        checkingNotifications = true
                        Task {
                            let sent = await store.sendTestNotification()
                            notificationFeedback = sent ? "Test en file iOS. Touche la notification pour essayer l’appel." : "iOS n’a pas accepté le test."
                            checkingNotifications = false
                        }
                    }
                    .buttonStyle(ActionStyle())
                    .disabled(checkingNotifications)
                }
                if let notificationFeedback {
                    Text(notificationFeedback).font(.footnote).foregroundStyle(muted)
                }
                Button("Essayer un appel maintenant") {
                    ReminderInbox.shared.destination = ReminderDestination(target: .test, sessionID: nil)
                }
                .buttonStyle(ActionStyle(filled: false))
                Text("Quand KAARIS est fermée, touche la notification de pointage pour ouvrir l’appel.")
                    .font(.footnote).foregroundStyle(muted)

                Toggle("Afficher le langage cru dans les notifications", isOn: Binding(
                    get: { store.preferences.bluntConsent && store.preferences.bluntNotificationConsent == true },
                    set: { store.preferences.bluntNotificationConsent = store.preferences.bluntConsent && $0 }
                ))
                .font(.subheadline)
                .disabled(!store.preferences.bluntConsent || store.isDemo)
                Text("Ce texte peut être visible sur ton écran verrouillé.")
                    .font(.footnote).foregroundStyle(muted)

                if !store.isDemo {
                    Button(pauseActive ? "Reprendre les relances" : "Mettre en pause 24 h") {
                        store.preferences.pausedUntil = pauseActive ? nil : Date.now.addingTimeInterval(86400)
                    }
                    .buttonStyle(ActionStyle(filled: false))

                    hourPicker("Début du silence", value: $store.preferences.quietStartHour)
                    hourPicker("Fin du silence", value: $store.preferences.quietEndHour)
                }
            }
            .kPanel()

            if !store.isDemo {
                VStack(alignment: .leading, spacing: 10) {
                    SectionLabel(text: "COMPTE")
                    if let email = connection.accountEmail {
                        Text(email).font(.subheadline).textSelection(.enabled)
                    }
                    if connection.faceIDEnabled {
                        Label("Face ID activé", systemImage: "faceid")
                            .font(.subheadline)
                    }
                    Button("Se déconnecter") { Task { await connection.logout() } }
                        .buttonStyle(ActionStyle(filled: false))
                    if let notice = connection.authNotice {
                        Text(notice).font(.footnote).foregroundStyle(muted)
                    }
                }
                .kPanel()
            }
            NavigationLink { AgendaScreen() } label: { Label("Google Agenda", systemImage: "calendar") }
                .buttonStyle(ActionStyle(filled: false))

            if !store.isDemo && connection.coachConfigured {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Activer le coach en ligne", isOn: Binding(
                        get: { store.preferences.onlineCoachConsented },
                        set: { store.preferences.onlineCoachConsent = $0 }
                    ))
                    .disabled(!connection.isSignedIn)
                    Text("À ta demande, le coach en ligne reçoit le type de check-in et tes réglages de ton.")
                        .font(.footnote)
                        .foregroundStyle(muted)
                }
                .kPanel()
            }

            if !store.isDemo && connection.voiceConfigured {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Activer la voix ElevenLabs", isOn: Binding(
                        get: { store.preferences.elevenLabsVoiceConsent == true },
                        set: { store.preferences.elevenLabsVoiceConsent = $0 }
                    ))
                    .disabled(!connection.isSignedIn)
                    Text("Quand tu réponds à l’appel du coach ou que tu l’écoutes, des phrases prédéfinies sont envoyées à ElevenLabs pour générer la voix. Tes réponses restent dans l’app.")
                        .font(.footnote).foregroundStyle(muted)
                }
                .kPanel()
            }

            SectionLabel(text: "OBJECTIF ET PROFIL")
            ProfileFields(profile: $store.profile)

            NavigationLink {
                KPage {
                    KTitle(text: "Confidentialité")
                    Text("KAARIS garde sur cet appareil les informations de profil, le planning, les réponses de pointage et tes préférences.")
                    Text("Les relances sont programmées par iOS. Lorsque tu enregistres une salle ou demandes à vérifier ta proximité, ta position sert à une vérification sur l’appareil.")
                    Text("Tu peux gérer les autorisations et supprimer les données locales de cette installation depuis les réglages iOS.")
                    Link("Lire la politique de confidentialité", destination: URL(string: "https://github.com/Cabinet-ALTYS/Kaaris/blob/main/docs/CONFIDENTIALITE.md")!)
                        .buttonStyle(ActionStyle(filled: false))
                }
                .toolbar(.visible, for: .navigationBar)
            } label: {
                Label("Confidentialité", systemImage: "hand.raised")
            }
            .buttonStyle(ActionStyle(filled: false))
        }
        .task { await store.updateNotificationDelivery() }
    }

    private var pauseActive: Bool { (store.preferences.pausedUntil ?? .distantPast) > .now }

    private var deliveryDetails: some View {
        let delivery = store.notificationDelivery
        let banners = delivery.banners ? "Bannières : oui" : "Bannières : non"
        let lockScreen = delivery.lockScreen ? "Écran verrouillé : oui" : "Écran verrouillé : non"
        let center = delivery.notificationCenter ? "Centre de notifications : oui" : "Centre de notifications : non"
        let sound = delivery.sound ? "Son : oui" : "Son : non"
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(banners) · \(lockScreen)")
            Text("\(center) · \(sound)")
            if delivery.scheduledSummary { Text("Le résumé iOS peut différer l’affichage.") }
        }
        .font(.footnote).foregroundStyle(muted)
    }

    private var queuedReminders: some View {
        let delivery = store.notificationDelivery
        return VStack(alignment: .leading, spacing: 4) {
            if delivery.pendingCount == 0 {
                Text("Aucune relance en file iOS.").font(.subheadline.weight(.semibold))
                if let reason = emptyQueueReason {
                    Text(reason).font(.footnote).foregroundStyle(muted)
                }
            } else {
                Text("\(delivery.pendingCount) \(delivery.pendingCount == 1 ? "relance" : "relances") en file iOS.")
                    .font(.subheadline.weight(.semibold))
                if let date = delivery.nextReminderDate {
                    Text("Prochaine \(dateLabel(date)), à \(hourLabel(date)).")
                        .font(.footnote).foregroundStyle(muted)
                }
            }
        }
    }

    private var emptyQueueReason: String? {
        let preferences = store.preferences
        if !preferences.remindersEnabled { return "Active les relances dans KAARIS." }
        if preferences.reminderIntensity == 0 { return "Le niveau de relance est à 0." }
        if let until = preferences.pausedUntil, pauseActive {
            return "Pause jusqu’au \(dateLabel(until)) à \(hourLabel(until))."
        }
        let now = Date.now
        if !store.sessions.contains(where: { $0.status == .planned && $0.date > now }) {
            return "Aucune séance future à relancer."
        }
        var withoutQuietHours = preferences
        withoutQuietHours.quietEndHour = withoutQuietHours.quietStartHour
        let alreadyDue = store.remindersAlreadyDue(at: now)
        if ReminderPlan.make(sessions: store.sessions, preferences: preferences, now: now, alreadyDue: alreadyDue).isEmpty,
           !ReminderPlan.make(sessions: store.sessions, preferences: withoutQuietHours, now: now, alreadyDue: alreadyDue).isEmpty {
            return "Les prochaines relances tombent pendant les heures de silence."
        }
        return nil
    }

    private func slider(_ title: String, labels: [String], value: Binding<Int>, maxValue: Int = 3) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(labels[min(maxValue, max(0, value.wrappedValue))])
                    .font(.system(.caption, design: .monospaced).weight(.semibold)).foregroundStyle(acid)
            }
            Slider(value: Binding(get: { Double(min(maxValue, value.wrappedValue)) }, set: { value.wrappedValue = Int($0.rounded()) }),
                   in: 0...Double(maxValue), step: 1)
                .accessibilityLabel(title)
                .accessibilityValue(labels[min(maxValue, max(0, value.wrappedValue))])
        }
    }

    private func hourPicker(_ title: String, value: Binding<Int>) -> some View {
        Picker(title, selection: value) {
            ForEach(0...23, id: \.self) { Text(String(format: "%02d h", $0)).tag($0) }
        }
        .font(.subheadline)
    }
}
