import SwiftUI

struct NutritionSetupFields: View {
    @Binding var profile: CoachProfile

    private var settings: Binding<NutritionProfile> { $profile.nutritionSettings }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Des repères journaliers estimés à partir de ton profil. Tes mesures et ton journal restent sur cet iPhone, dans ton compte KAARIS.")
                .font(.subheadline).foregroundStyle(muted)
            OptionalNumberField(label: "Âge (ans)", value: Binding(
                get: { settings.wrappedValue.age.map(Double.init) },
                set: { settings.wrappedValue.age = $0.map(Int.init) }
            ), range: 18...100, allowsDecimal: false)
            OptionalNumberField(label: "Taille (cm)", value: settings.heightCM, range: 100...250)
            OptionalNumberField(label: "Poids (kg)", value: settings.weightKG, range: 30...300)
            Picker("Profil de référence", selection: settings.reference) {
                Text("À renseigner").tag(nil as NutritionReference?)
                ForEach(NutritionReference.allCases) { reference in
                    Text(reference.rawValue).tag(Optional(reference))
                }
            }
            Text("Ce choix sert à la formule énergétique et aux repères qui varient selon le sexe.")
                .font(.caption).foregroundStyle(muted)
            Picker("Activité habituelle", selection: settings.activity) {
                Text("À renseigner").tag(nil as NutritionActivity?)
                ForEach(NutritionActivity.allCases) { activity in
                    Text(activity.rawValue).tag(Optional(activity))
                }
            }
            Text("Pense à l’ensemble de ta semaine, déplacements, travail et entraînements compris.")
                .font(.caption).foregroundStyle(muted)
            Picker("Objectif nutrition", selection: settings.objective) {
                ForEach(NutritionObjective.allCases) { objective in Text(objective.rawValue).tag(objective) }
            }
            Toggle("Grossesse, allaitement ou besoins nutritionnels particuliers", isOn: settings.specialNeeds)
            if settings.wrappedValue.specialNeeds {
                Text("Pour ces situations, utilise les repères de ton professionnel de santé. Le carnet et les recettes restent accessibles.")
                    .font(.caption).foregroundStyle(muted)
            } else if let targets = settings.wrappedValue.targets {
                Label("Estimation prête · \(nutritionNumber(targets.energyKcal, rounded: true)) kcal/jour", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(acid)
            } else if settings.wrappedValue.age != nil && settings.wrappedValue.heightCM != nil &&
                        settings.wrappedValue.weightKG != nil && settings.wrappedValue.reference != nil &&
                        settings.wrappedValue.activity != nil {
                Text("Ce profil est hors des conditions utilisées pour cette estimation.")
                    .font(.caption).foregroundStyle(muted)
            }
        }
        .font(.subheadline)
        .kPanel()
    }
}

struct NutritionScreen: View {
    private enum Sheet: Identifiable {
        case profile
        case food
        case recipes
        case edit(NutritionEntry)

        var id: String {
            switch self {
            case .profile: "profile"
            case .food: "food"
            case .recipes: "recipes"
            case .edit(let entry): entry.id.uuidString
            }
        }
    }

    @EnvironmentObject private var store: CoachStore
    @State private var date = Date.now
    @State private var sheet: Sheet?
    @State private var expandedMicros = false

    private var dayKey: String { NutritionEntry.dayKey(for: date) }
    private var dayEntries: [NutritionEntry] { store.nutritionEntries.filter { $0.day == dayKey } }
    private var targets: NutritionTargets? { store.profile.nutritionSettings.targets }

    var body: some View {
        let intake = NutritionIntake(ingredients: dayEntries.flatMap(\.ingredients))
        KPage {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "Repas et apports")
                KTitle(text: "NUTRITION")
            }
            DatePicker("Jour du carnet", selection: $date, in: ...Date.now, displayedComponents: .date)
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("nutritionDay")
            summary(intake: intake)

            HStack(spacing: 8) {
                Button { sheet = .food } label: { Label("Ajouter un aliment", systemImage: "plus") }
                    .buttonStyle(ActionStyle())
                Button { sheet = .recipes } label: { Label("Recettes", systemImage: "book") }
                    .buttonStyle(ActionStyle(filled: false))
            }
            journal
            micros(intake: intake)
            Link(destination: URL(string: "https://doi.org/10.57745/RDMHWY")!) {
                Label("Source des aliments · Anses, Ciqual 2025", systemImage: "arrow.up.right")
                    .font(.caption).foregroundStyle(muted)
            }
        }
        .sheet(item: $sheet) { item in
            NavigationStack {
                switch item {
                case .profile:
                    NutritionProfileSheet(profile: $store.profile)
                case .food:
                    NutritionEntrySheet(day: dayKey, save: store.saveNutritionEntry)
                case .recipes:
                    NutritionRecipesSheet(day: dayKey, intake: intake, targets: targets, save: store.saveNutritionEntry)
                case .edit(let entry):
                    NutritionEntrySheet(day: entry.day, existing: entry, save: store.saveNutritionEntry)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func summary(intake: NutritionIntake) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                SectionLabel(text: "Bilan du jour")
                Spacer()
                Button("Mon profil") { sheet = .profile }
                    .font(.footnote.weight(.semibold))
                    .tint(acid)
            }
            if targets == nil && !intake.hasIngredients {
                Text("Renseigne ton profil pour estimer tes apports journaliers.")
                    .font(.subheadline).foregroundStyle(muted)
            } else {
                NutritionAmountRow("Énergie", "kcal", estimate: intake["energyKcal"], target: targets?.energyKcal)
                NutritionAmountRow("Protéines", "g", estimate: intake["proteinG"], target: targets?.proteinG)
                NutritionAmountRow("Glucides", "g", estimate: intake["carbsG"], target: targets?.carbsG)
                NutritionAmountRow("Lipides", "g", estimate: intake["fatG"], target: targets?.fatG)
                NutritionAmountRow("Fibres", "g", estimate: intake["fiberG"], target: targets?.fiberG)
            }
            if intake.hasIngredients {
                Text("Les quantités affichées concernent les aliments saisis. Un total partiel peut sous-estimer l’apport.")
                    .font(.caption).foregroundStyle(muted)
            } else if targets != nil {
                Text("Ajoute tes portions pour les comparer à tes repères.")
                    .font(.caption).foregroundStyle(muted)
            }
        }
        .kPanel()
    }

    private var journal: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(text: "Carnet de repas")
            if dayEntries.isEmpty {
                Text("Aucun aliment enregistré ce jour.")
                    .font(.subheadline).foregroundStyle(muted)
            }
            ForEach(NutritionMeal.allCases) { meal in
                let entries = dayEntries.filter { $0.meal == meal }
                if !entries.isEmpty {
                    Text(meal.rawValue).font(.headline)
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.name).font(.subheadline.weight(.semibold))
                                let weight = entry.ingredients.map(\.grams).reduce(0, +)
                                Text("\(nutritionNumber(weight)) g")
                                    .font(.caption).foregroundStyle(muted)
                            }
                            Spacer()
                            Menu {
                                Button("Modifier", systemImage: "pencil") { sheet = .edit(entry) }
                                Button("Retirer du carnet", systemImage: "trash", role: .destructive) {
                                    store.removeNutritionEntry(entry.id)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle").font(.title3).frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Actions pour \(entry.name)")
                        }
                    }
                }
            }
        }
        .kPanel()
    }

    private func micros(intake: NutritionIntake) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expandedMicros.toggle() }
            } label: {
                HStack {
                    Text("Vitamines et minéraux")
                    Spacer()
                    Image(systemName: expandedMicros ? "chevron.down" : "chevron.right")
                        .foregroundStyle(acid)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(expandedMicros ? "Ouvert" : "Fermé")
            if expandedMicros {
                Text("Ces repères s’interprètent sur la durée. Une journée de carnet ne permet pas d’identifier une carence.")
                    .font(.caption).foregroundStyle(muted)
                ForEach(NutritionNutrient.allCases) { nutrient in
                    let reference = targets?.micro.first { $0.nutrient == nutrient }
                    let recorded = intake[nutrient.catalogKey]
                    let estimate = NutritionEstimate(
                        amount: recorded.amount,
                        complete: recorded.complete && nutrient != .vitaminB3
                    )
                    NutritionAmountRow(nutrient.rawValue, nutrient.unit, estimate: estimate, target: reference?.amount,
                                       isLimit: reference?.isUpperLimit == true)
                }
                Text("Ciqual ne renseigne pas la biotine (B8). Pour la B3, le carnet reprend la niacine renseignée, sans contribution du tryptophane.")
                    .font(.caption).foregroundStyle(muted)
            }
        }
        .font(.subheadline.weight(.semibold))
        .kPanel()
    }
}

private struct NutritionAmountRow: View {
    let name: String
    let unit: String
    let estimate: NutritionEstimate
    let target: Double?
    let isLimit: Bool

    init(_ name: String, _ unit: String, estimate: NutritionEstimate, target: Double?, isLimit: Bool = false) {
        self.name = name
        self.unit = unit
        self.estimate = estimate
        self.target = target
        self.isLimit = isLimit
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name).font(.subheadline)
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                if let amount = estimate.amount {
                    Text("\(nutritionNumber(amount)) \(unit)").font(.subheadline.monospacedDigit().weight(.semibold))
                    if !estimate.complete {
                        Text("Total partiel").font(.caption).foregroundStyle(muted)
                    }
                }
                if let target {
                    Text("\(isLimit ? "Limite" : "Repère") \(nutritionNumber(target, rounded: unit == "kcal")) \(unit)")
                        .font(.caption).foregroundStyle(muted)
                }
                if estimate.amount == nil {
                    Text("Aucune valeur saisie").font(.caption).foregroundStyle(muted)
                } else if let amount = estimate.amount, let target, isLimit, amount >= target {
                    Text("Limite atteinte dans le carnet").font(.caption).foregroundStyle(muted)
                }
            }
            .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct NutritionProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var profile: CoachProfile

    var body: some View {
        KPage { NutritionSetupFields(profile: $profile) }
            .navigationTitle("Profil nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Terminé") { dismiss() } } }
    }
}

private struct NutritionEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var meal: NutritionMeal
    @State private var query = ""
    @State private var selected: NutritionFood?
    @State private var quantities: [Double?]
    let day: String
    let existing: NutritionEntry?
    let save: (NutritionEntry) -> Void

    init(day: String, existing: NutritionEntry? = nil, save: @escaping (NutritionEntry) -> Void) {
        self.day = day
        self.existing = existing
        self.save = save
        _meal = State(initialValue: existing?.meal ?? .lunch)
        _quantities = State(initialValue: existing?.ingredients.map { Optional($0.grams) } ?? [nil])
    }

    private var canSave: Bool {
        (existing != nil || selected != nil) && quantities.allSatisfy { $0 != nil }
    }

    var body: some View {
        KPage {
            Picker("Repas", selection: $meal) {
                ForEach(NutritionMeal.allCases) { meal in Text(meal.rawValue).tag(meal) }
            }
            if let existing {
                Text(existing.name).font(.headline)
                ForEach(existing.ingredients.indices, id: \.self) { index in
                    let name = NutritionCatalog.shared.food(existing.ingredients[index].foodID)?.name ?? "Ingrédient"
                    portionField(name, index: index)
                }
            } else if let selected {
                Text(selected.name).font(.headline)
                portionField("Portion consommée", index: 0)
                Button("Changer d’aliment") { self.selected = nil }
                    .font(.subheadline)
            } else {
                foodSearch
            }
            if selected != nil || existing != nil {
                Text("Pèse la partie consommée. Choisis l’entrée crue, cuite ou égouttée qui correspond à ta portion.")
                    .font(.caption).foregroundStyle(muted)
                Button("Enregistrer la portion", action: submit)
                    .buttonStyle(ActionStyle())
                    .disabled(!canSave)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(existing == nil ? "Ajouter un aliment" : "Modifier le repas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
    }

    private var foodSearch: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Chercher dans Ciqual", text: $query)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("ciqualSearch")
                .kPanel()
            if NutritionCatalog.shared.isEmpty {
                Text("Le catalogue Ciqual n’a pas pu être chargé.").foregroundStyle(muted)
            } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Exemples : poulet grillé, riz complet cuit, lentilles vertes.")
                    .font(.subheadline).foregroundStyle(muted)
            } else {
                let results = NutritionCatalog.shared.search(query)
                if results.isEmpty {
                    Text("Aucun résultat pour cette recherche.").foregroundStyle(muted)
                }
                ForEach(results) { food in
                    Button {
                        selected = food
                        quantities = [100]
                    } label: {
                        HStack {
                            Text(food.name).multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "plus.circle").foregroundStyle(acid)
                        }
                        .font(.subheadline)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func portionField(_ name: String, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.subheadline)
            OptionalNumberField(label: "Quantité en grammes", value: $quantities[index], range: NutritionIngredient.allowedGrams)
        }
        .kPanel()
    }

    private func submit() {
        guard canSave else { return }
        let codes = existing?.ingredients.map(\.foodID) ?? [selected?.id].compactMap { $0 }
        let grams = quantities.compactMap { $0 }
        guard let name = existing?.name ?? selected?.name, codes.count == grams.count else { return }
        let ingredients = zip(codes, grams).map { NutritionIngredient(foodID: $0.0, grams: $0.1) }
        save(NutritionEntry(id: existing?.id ?? UUID(), day: day, meal: meal, name: name, ingredients: ingredients))
        dismiss()
    }
}

private struct NutritionRecipesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMeal = NutritionMeal.lunch
    @State private var vegetarian = false
    let day: String
    let intake: NutritionIntake
    let targets: NutritionTargets?
    let save: (NutritionEntry) -> Void

    var body: some View {
        KPage {
            Text("Assemble une source de protéines, des végétaux, un féculent selon ta faim et un peu de matière grasse.")
                .font(.subheadline).foregroundStyle(muted)
            Picker("Repas", selection: $selectedMeal) {
                ForEach(NutritionMeal.allCases) { meal in Text(meal.rawValue).tag(meal) }
            }
            Toggle("Végétarien", isOn: $vegetarian)
            let recipes = suggestedRecipes
            if priorities.contains(where: { $0.remaining > 0 }) {
                Text("Les idées qui contribuent aux repères de protéines et de fibres passent en premier.")
                    .font(.caption).foregroundStyle(muted)
            }
            if recipes.isEmpty {
                Text("Aucune recette pour ce filtre.").font(.subheadline).foregroundStyle(muted)
            }
            ForEach(recipes) { recipe in
                NavigationLink {
                    NutritionRecipeDetail(recipe: recipe, day: day, save: save, close: { dismiss() })
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(recipe.name, systemImage: "fork.knife").font(.subheadline.weight(.semibold))
                        let kcal = NutritionIntake(ingredients: recipe.ingredients)["energyKcal"]
                        if let amount = kcal.amount, kcal.complete {
                            Text("\(recipe.minutes) min · env. \(nutritionNumber(amount, rounded: true)) kcal par portion")
                                .font(.caption).foregroundStyle(muted)
                        } else {
                            Text("\(recipe.minutes) min").font(.caption).foregroundStyle(muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .kPanel()
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Idées de repas")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
    }

    private var priorities: [(key: String, remaining: Double)] {
        guard let targets else { return [] }
        return [("proteinG", targets.proteinG), ("fiberG", targets.fiberG)].compactMap { key, reference in
            let estimate = intake[key]
            guard !intake.hasIngredients || estimate.complete else { return nil }
            return (key, max(0, reference - (estimate.amount ?? 0)))
        }
    }

    private var suggestedRecipes: [NutritionRecipe] {
        let candidates = NutritionRecipe.all.filter { $0.meal == selectedMeal && (!vegetarian || $0.vegetarian) }
        let remaining = priorities.filter { $0.remaining > 0 }
        guard !remaining.isEmpty else { return candidates }
        return candidates.map { recipe in
            let nutrients = NutritionIntake(ingredients: recipe.ingredients)
            let score = remaining.reduce(0.0) { score, priority in
                let estimate = nutrients[priority.key]
                guard estimate.complete, let amount = estimate.amount else { return score }
                return score + min(1, amount / priority.remaining)
            }
            return (recipe: recipe, score: score)
        }
        .sorted { lhs, rhs in lhs.score > rhs.score }
        .map(\.recipe)
    }
}

private struct NutritionRecipeDetail: View {
    let recipe: NutritionRecipe
    let day: String
    let save: (NutritionEntry) -> Void
    let close: () -> Void
    @State private var servings = 1.0

    var body: some View {
        let ingredients = recipe.portion(servings)
        KPage {
            Text(recipe.name).font(.title.weight(.black))
            Stepper("\(nutritionNumber(servings)) portion(s)", value: $servings, in: 0.5...4, step: 0.5)
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "Ingrédients")
                ForEach(Array(ingredients.enumerated()), id: \.offset) { _, ingredient in
                    if let food = NutritionCatalog.shared.food(ingredient.foodID) {
                        Text("\(nutritionNumber(ingredient.grams)) g · \(food.name)")
                            .font(.subheadline)
                    }
                }
            }
            .kPanel()
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "Préparation")
                ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                    Text("\(index + 1). \(instruction)").font(.subheadline)
                }
            }
            .kPanel()
            Button("Enregistrer dans ce repas") {
                save(NutritionEntry(day: day, meal: recipe.meal, name: recipe.name, ingredients: ingredients))
                close()
            }
            .buttonStyle(ActionStyle())
            .disabled(ingredients.isEmpty || ingredients.contains { NutritionCatalog.shared.food($0.foodID) == nil })
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func nutritionNumber(_ value: Double, rounded: Bool = false) -> String {
    value.formatted(.number.precision(.fractionLength(0...(rounded ? 0 : 2))).locale(Locale(identifier: "fr_FR")))
}
