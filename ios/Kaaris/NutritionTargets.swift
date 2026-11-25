import Foundation

enum NutritionReference: String, Codable, CaseIterable, Identifiable {
    case female = "Femme"
    case male = "Homme"

    var id: Self { self }
}

enum NutritionActivity: String, Codable, CaseIterable, Identifiable {
    case sedentary = "Faible"
    case light = "Légère"
    case moderate = "Modérée"
    case high = "Élevée"

    var id: Self { self }

    // Niveaux d’activité physique de l’EFSA pour la dépense totale.
    // https://doi.org/10.2903/j.efsa.2013.3005
    fileprivate var multiplier: Double {
        switch self {
        case .sedentary: 1.4
        case .light: 1.6
        case .moderate: 1.8
        case .high: 2.0
        }
    }
}

enum NutritionObjective: String, Codable, CaseIterable, Identifiable {
    case maintain = "Maintien"
    case loseWeight = "Perte de poids"
    case gainMuscle = "Prise de muscle"

    var id: Self { self }
}

struct NutritionProfile: Codable, Equatable {
    var age: Int? = nil
    var heightCM: Double? = nil
    var weightKG: Double? = nil
    var reference: NutritionReference? = nil
    var activity: NutritionActivity? = nil
    var objective: NutritionObjective = .maintain
    var specialNeeds: Bool = false

    var targets: NutritionTargets? {
        guard !specialNeeds,
              let age, (18...100).contains(age),
              let heightCM, (100...250).contains(heightCM),
              let weightKG, (30...300).contains(weightKG),
              let reference, let activity else { return nil }

        let heightM = heightCM / 100
        let bodyMassIndex = weightKG / (heightM * heightM)
        guard bodyMassIndex >= 18.5, objective != .loseWeight || bodyMassIndex >= 20 else { return nil }

        // Dépense de repos estimée par Mifflin–St Jeor, étudiée chez des adultes
        // en bonne santé. On ajoute le niveau déclaré, sans promettre un résultat individuel.
        // https://pubmed.ncbi.nlm.nih.gov/2305711/
        let referenceConstant = reference == .female ? -161.0 : 5.0
        let restingEnergy = 10 * weightKG + 6.25 * heightCM - 5 * Double(age) + referenceConstant
        let maintenance = restingEnergy * activity.multiplier
        guard maintenance >= 1_200 else { return nil }

        // Écarts prudents choisis pour cette estimation, sans protocole de régime.
        // https://pubmed.ncbi.nlm.nih.gov/37914977/
        let energy: Double
        switch objective {
        case .maintain: energy = maintenance
        case .loseWeight: energy = max(1_200, maintenance - min(maintenance * 0.10, 250))
        case .gainMuscle: energy = maintenance + min(maintenance * 0.05, 200)
        }

        // Les repères généraux ANSES sont de 10 à 20 % en protéines, 35 à 40 %
        // en lipides, 40 à 55 % en glucides et 30 g de fibres. La consommation
        // protéique plus élevée est une estimation pour le renforcement régulier.
        // https://anses.fr/fr/system/files/NUT2012SA0103Ra-1.pdf
        // https://pubmed.ncbi.nlm.nih.gov/28698222/
        let exercisesRegularly = activity == .moderate || activity == .high
        let proteinPerKG: Double
        switch activity {
        case .sedentary: proteinPerKG = age >= 65 ? 1.0 : 0.83
        case .light: proteinPerKG = 1.2
        case .moderate, .high: proteinPerKG = objective == .maintain ? 1.4 : 1.6
        }
        let proteinShare: Double = exercisesRegularly ? 0.25 : 0.20
        let proteinEnergy = min(energy * proteinShare, max(energy * 0.10, proteinPerKG * weightKG * 4))
        let fatEnergy = energy * 0.35
        return NutritionTargets(
            energyKcal: energy,
            proteinG: proteinEnergy / 4,
            carbsG: (energy - proteinEnergy - fatEnergy) / 4,
            fatG: fatEnergy / 9,
            fiberG: 30,
            micro: NutritionNutrient.allCases.map {
                NutritionMicroTarget(nutrient: $0, amount: $0.dailyReference(age: age, reference: reference))
            }
        )
    }
}

struct NutritionTargets: Equatable {
    let energyKcal: Double
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let fiberG: Double
    let micro: [NutritionMicroTarget]
}

struct NutritionMicroTarget: Identifiable, Equatable {
    let nutrient: NutritionNutrient
    let amount: Double

    var id: NutritionNutrient { nutrient }

    // Plafond de santé publique, distinct d’un apport à atteindre.
    var isUpperLimit: Bool { nutrient == .sodium }
}

enum NutritionNutrient: String, Codable, CaseIterable, Identifiable {
    case calcium = "Calcium"
    case iron = "Fer"
    case magnesium = "Magnésium"
    case zinc = "Zinc"
    case iodine = "Iode"
    case potassium = "Potassium"
    case selenium = "Sélénium"
    case vitaminA = "Vitamine A"
    case vitaminC = "Vitamine C"
    case vitaminD = "Vitamine D"
    case vitaminE = "Vitamine E"
    case vitaminK = "Vitamine K1"
    case vitaminB1 = "Vitamine B1"
    case vitaminB2 = "Vitamine B2"
    case vitaminB3 = "Vitamine B3"
    case vitaminB5 = "Vitamine B5"
    case vitaminB6 = "Vitamine B6"
    case vitaminB8 = "Vitamine B8"
    case vitaminB9 = "Vitamine B9"
    case vitaminB12 = "Vitamine B12"
    case phosphorus = "Phosphore"
    case sodium = "Sodium"

    var id: Self { self }

    var unit: String {
        switch self {
        case .vitaminA: "µg ER"
        case .vitaminB3: "mg EN"
        case .vitaminB9: "µg EFA"
        case .iodine, .selenium, .vitaminD, .vitaminK, .vitaminB8, .vitaminB12: "µg"
        default: "mg"
        }
    }

    // RNP ou AS ANSES pour les adultes en bonne santé. Les valeurs relatives à
    // l’énergie (B1 et B3) prennent ici un exemple fixe à 2 000 kcal par jour.
    // https://www.anses.fr/fr/article/references-nutritionnelles-vitamines-mineraux
    fileprivate func dailyReference(age: Int, reference: NutritionReference) -> Double {
        let isFemale = reference == .female
        let referenceEnergyMJ = 2_000.0 * 0.004184
        return switch self {
        case .calcium: age < 25 ? 1_000 : 950
        case .iron: 11 // Pertes menstruelles faibles à modérées. L’ANSES distingue 16 mg si pertes élevées.
        case .magnesium: isFemale ? 300 : 380
        case .zinc: isFemale ? 9.3 : 11.7 // Pour une alimentation à 600 mg de phytates par jour.
        case .iodine: 150
        case .potassium: 3_500
        case .selenium: 70
        case .vitaminA: isFemale ? 650 : 750
        case .vitaminC: 110
        case .vitaminD: 15
        case .vitaminE: isFemale ? 9 : 10
        case .vitaminK: 79
        case .vitaminB1: 0.1 * referenceEnergyMJ
        case .vitaminB2: 1.6
        case .vitaminB3: 1.6 * referenceEnergyMJ
        case .vitaminB5: isFemale ? 5 : 6
        case .vitaminB6: isFemale ? 1.6 : 1.7
        case .vitaminB8: 40
        case .vitaminB9: 330
        case .vitaminB12: 4
        case .phosphorus: 550
        case .sodium: 2_000 // L’OMS recommande de rester sous 2 000 mg par jour.
        }
    }
}
