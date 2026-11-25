import Foundation

enum NutritionMeal: String, CaseIterable, Codable, Identifiable {
    case breakfast = "Petit-déjeuner"
    case lunch = "Déjeuner"
    case dinner = "Dîner"
    case snack = "Collation"

    var id: Self { self }
}

struct NutritionFood: Decodable, Identifiable {
    let id: String
    let name: String
    let per100: [String: Double]
}

struct NutritionIngredient: Codable, Equatable {
    let foodID: String
    let grams: Double

    static let allowedGrams = 0.1...3_000.0
}

struct NutritionEntry: Codable, Equatable, Identifiable {
    var id = UUID()
    let day: String
    let meal: NutritionMeal
    let name: String
    let ingredients: [NutritionIngredient]

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = calendar.timeZone
        let parts = local.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

struct NutritionCatalog {
    static let shared: Self = {
        let bundle = Bundle.main
        let url = bundle.url(forResource: "kaaris-ciqual-2025", withExtension: "json", subdirectory: "Nutrition")
            ?? bundle.url(forResource: "kaaris-ciqual-2025", withExtension: "json")
        let foods = url.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([NutritionFood].self, from: $0) } ?? []
        return Self(foods: foods)
    }()

    private let index: [String: NutritionFood]
    private let searchItems: [(food: NutritionFood, name: String)]

    init(foods: [NutritionFood]) {
        index = Dictionary(foods.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        searchItems = foods.map { ($0, Self.normalize($0.name)) }
    }

    var isEmpty: Bool { index.isEmpty }

    func food(_ id: String) -> NutritionFood? { index[id] }

    func search(_ query: String) -> [NutritionFood] {
        let text = Self.normalize(query).trimmingCharacters(in: .whitespacesAndNewlines)
        let terms = text.split(whereSeparator: \.isWhitespace)
        guard !terms.isEmpty else { return [] }
        let matches = searchItems.filter { item in
            terms.allSatisfy { term in
                item.name.contains(term) ||
                    (term.count > 3 && term.hasSuffix("s") && item.name.contains(term.dropLast()))
            }
        }
        let ordered = matches.sorted { lhs, rhs in
            let firstStarts = lhs.name.hasPrefix(text)
            let secondStarts = rhs.name.hasPrefix(text)
            if firstStarts != secondStarts { return firstStarts }
            return lhs.name < rhs.name
        }
        return ordered.prefix(40).map(\.food)
    }

    private static func normalize(_ string: String) -> String {
        string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "fr_FR"))
            .replacingOccurrences(of: "œ", with: "oe")
            .replacingOccurrences(of: "’", with: "'")
    }
}

struct NutritionEstimate {
    let amount: Double?
    let complete: Bool
}

struct NutritionIntake {
    private let ingredientCount: Int
    private var quantities: [String: Double] = [:]
    private var counts: [String: Int] = [:]

    init(ingredients: [NutritionIngredient], catalog: NutritionCatalog = .shared) {
        ingredientCount = ingredients.count
        for ingredient in ingredients {
            guard NutritionIngredient.allowedGrams.contains(ingredient.grams),
                  let food = catalog.food(ingredient.foodID) else { continue }
            for (key, per100g) in food.per100 {
                quantities[key, default: 0] += per100g * ingredient.grams / 100
                counts[key, default: 0] += 1
            }
        }
    }

    subscript(key: String) -> NutritionEstimate {
        NutritionEstimate(amount: quantities[key], complete: ingredientCount > 0 && counts[key] == ingredientCount)
    }

    var hasIngredients: Bool { ingredientCount > 0 }
}

extension NutritionNutrient {
    var catalogKey: String {
        switch self {
        case .calcium: "calcium"
        case .iron: "iron"
        case .magnesium: "magnesium"
        case .zinc: "zinc"
        case .iodine: "iodine"
        case .potassium: "potassium"
        case .selenium: "selenium"
        case .vitaminA: "vitaminA"
        case .vitaminC: "vitaminC"
        case .vitaminD: "vitaminD"
        case .vitaminE: "vitaminE"
        case .vitaminK: "vitaminK"
        case .vitaminB1: "vitaminB1"
        case .vitaminB2: "vitaminB2"
        case .vitaminB3: "vitaminB3"
        case .vitaminB5: "vitaminB5"
        case .vitaminB6: "vitaminB6"
        case .vitaminB8: "vitaminB8"
        case .vitaminB9: "vitaminB9"
        case .vitaminB12: "vitaminB12"
        case .phosphorus: "phosphorus"
        case .sodium: "sodium"
        }
    }
}
