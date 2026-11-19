import SwiftUI
import UIKit

struct OnboardingScreen: View {
    @EnvironmentObject private var store: CoachStore
    @State private var isAdult = false
    @State private var step = 0

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
                Button("Créer mes séances") { store.finishOnboarding() }.buttonStyle(ActionStyle())
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
    @Environment(\.openURL) private var openURL
    @State private var notifyDenied = false

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
                slider("Langage", labels: ["Neutre", "Direct", "Familier", "Grossier"],
                       value: $store.preferences.languageIntensity, maxValue: store.preferences.maxLanguageIntensity)
                Toggle("Autoriser le langage cru", isOn: $store.preferences.bluntConsent)
                    .font(.subheadline)
                Divider()
                slider("Relances par séance", labels: ["0 · Coupées", "1 · Avant", "2 · Avec pointage", "3 · Avec suivi"],
                       value: $store.preferences.reminderIntensity)
                Divider()
                slider("Pression sur l’ego", labels: ["Factuelle", "Objectif", "Défi", "Parole donnée"],
                       value: $store.preferences.egoPressure)
            }
            .kPanel()

            VStack(alignment: .leading, spacing: 12) {
                SectionLabel(text: "NOTIFICATIONS")
                if store.preferences.remindersEnabled {
                    Button("Désactiver les notifications") { store.preferences.remindersEnabled = false }
                        .buttonStyle(ActionStyle(filled: false))
                } else {
                    Button("Activer les notifications") {
                        Task {
                            let enabled = await store.requestNotifications()
                            store.preferences.remindersEnabled = enabled
                            notifyDenied = !enabled
                        }
                    }
                    .buttonStyle(ActionStyle(filled: false))
                }

                Button(pauseActive ? "Reprendre les relances" : "Mettre en pause 24 h") {
                    store.preferences.pausedUntil = pauseActive ? nil : Date.now.addingTimeInterval(86400)
                }
                .buttonStyle(ActionStyle(filled: false))

                hourPicker("Début du silence", value: $store.preferences.quietStartHour)
                hourPicker("Fin du silence", value: $store.preferences.quietEndHour)
            }
            .kPanel()

            NavigationLink { AgendaScreen() } label: { Label("Google Agenda", systemImage: "calendar") }
                .buttonStyle(ActionStyle(filled: false))

            SectionLabel(text: "OBJECTIF ET PROFIL")
            ProfileFields(profile: $store.profile)
        }
        .alert("Notifications désactivées dans iOS", isPresented: $notifyDenied) {
            Button("Ouvrir les réglages iOS") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            Button("Fermer", role: .cancel) {}
        }
    }

    private var pauseActive: Bool { (store.preferences.pausedUntil ?? .distantPast) > .now }

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
