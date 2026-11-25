import Foundation

struct NutritionRecipe: Identifiable {
    let id: String
    let name: String
    let meal: NutritionMeal
    let minutes: Int
    let vegetarian: Bool
    let ingredients: [NutritionIngredient]
    let instructions: [String]

    // Les fiches correspondent à une portion. Le catalogue conserve l’état dans
    // lequel l’aliment est pesé, cru, cuit ou égoutté.
    func portion(_ servings: Double) -> [NutritionIngredient] {
        guard servings.isFinite, servings > 0 else { return [] }
        let scaled = ingredients.map { NutritionIngredient(foodID: $0.foodID, grams: $0.grams * servings) }
        return scaled.allSatisfy { NutritionIngredient.allowedGrams.contains($0.grams) } ? scaled : []
    }

    static let all: [NutritionRecipe] = [
        NutritionRecipe(
            id: "fromage-blanc-avoine-framboise",
            name: "Bol de fromage blanc, avoine et framboises",
            meal: .breakfast,
            minutes: 5,
            vegetarian: true,
            ingredients: [
                NutritionIngredient(foodID: "19646", grams: 180), // Fromage blanc nature
                NutritionIngredient(foodID: "32140", grams: 40), // Flocons d’avoine secs
                NutritionIngredient(foodID: "13015", grams: 125), // Framboises fraîches
                NutritionIngredient(foodID: "15005", grams: 15) // Cerneaux de noix
            ],
            instructions: [
                "Mélange les flocons d’avoine secs au fromage blanc dans un bol.",
                "Rince et égoutte les framboises, puis ajoute-les entières.",
                "Concasse les noix et répartis-les sur le bol."
            ]
        ),
        NutritionRecipe(
            id: "tartines-oeuf-avocat-kiwi",
            name: "Tartines œuf et avocat, kiwi",
            meal: .breakfast,
            minutes: 15,
            vegetarian: true,
            ingredients: [
                NutritionIngredient(foodID: "7110", grams: 70), // Pain complet
                NutritionIngredient(foodID: "22010", grams: 100), // Œufs durs écalés
                NutritionIngredient(foodID: "13004", grams: 70), // Chair d’avocat
                NutritionIngredient(foodID: "13021", grams: 100) // Chair de kiwi
            ],
            instructions: [
                "Plonge les œufs dans l’eau bouillante et cuis-les 10 minutes. Refroidis-les sous l’eau froide, écale-les et pèse-les.",
                "Grille le pain complet. Écrase l’avocat à la fourchette, étale-le sur le pain et garnis avec les œufs coupés en rondelles.",
                "Épluche le kiwi et sers-le en quartiers à côté."
            ]
        ),
        NutritionRecipe(
            id: "porridge-banane-cacahuete",
            name: "Porridge banane et cacahuète",
            meal: .breakfast,
            minutes: 10,
            vegetarian: true,
            ingredients: [
                NutritionIngredient(foodID: "32140", grams: 50), // Flocons d’avoine secs
                NutritionIngredient(foodID: "19041", grams: 200), // Lait demi-écrémé
                NutritionIngredient(foodID: "13005", grams: 100), // Chair de banane
                NutritionIngredient(foodID: "15202", grams: 15) // Pâte d’arachide
            ],
            instructions: [
                "Pèse les flocons secs et verse-les avec le lait dans une casserole.",
                "Chauffe à feu doux 5 à 7 minutes en remuant, jusqu’à épaississement.",
                "Transvase dans un bol et ajoute la banane en rondelles et la pâte d’arachide."
            ]
        ),
        NutritionRecipe(
            id: "lentilles-quinoa-crudites",
            name: "Salade de lentilles, quinoa et crudités",
            meal: .lunch,
            minutes: 12,
            vegetarian: true,
            ingredients: [
                NutritionIngredient(foodID: "20587", grams: 160), // Lentilles vertes cuites
                NutritionIngredient(foodID: "9341", grams: 110), // Quinoa cuit
                NutritionIngredient(foodID: "20276", grams: 130), // Tomate crue
                NutritionIngredient(foodID: "20019", grams: 100), // Concombre cru
                NutritionIngredient(foodID: "17270", grams: 10), // Huile d’olive
                NutritionIngredient(foodID: "2007", grams: 15) // Jus de citron pressé
            ],
            instructions: [
                "Pèse les lentilles et le quinoa déjà cuits et refroidis.",
                "Rince la tomate et le concombre. Coupe-les en dés et ajoute-les aux lentilles et au quinoa.",
                "Bats le jus de citron avec l’huile d’olive, puis verse sur la salade et mélange."
            ]
        ),
        NutritionRecipe(
            id: "poulet-riz-complet-brocoli",
            name: "Bol de poulet, riz complet et brocoli",
            meal: .lunch,
            minutes: 15,
            vegetarian: false,
            ingredients: [
                NutritionIngredient(foodID: "36018", grams: 130), // Poulet grillé, poids cuit
                NutritionIngredient(foodID: "9103", grams: 150), // Riz complet cuit
                NutritionIngredient(foodID: "20304", grams: 180), // Brocoli vapeur
                NutritionIngredient(foodID: "17270", grams: 10), // Huile d’olive
                NutritionIngredient(foodID: "2007", grams: 12) // Jus de citron pressé
            ],
            instructions: [
                "Pars de riz complet et de filet de poulet grillé déjà cuits. Pèse-les et coupe le poulet en lamelles.",
                "Cuis les bouquets de brocoli à la vapeur 6 à 8 minutes et pèse-les après cuisson.",
                "Réchauffe le poulet et le riz à cœur. Dispose-les avec le brocoli et ajoute l’huile d’olive et le jus de citron."
            ]
        ),
        NutritionRecipe(
            id: "wrap-haricot-rouge-crudites",
            name: "Wraps aux haricots rouges et crudités",
            meal: .lunch,
            minutes: 15,
            vegetarian: true,
            ingredients: [
                NutritionIngredient(foodID: "7815", grams: 80), // Tortillas de blé
                NutritionIngredient(foodID: "20524", grams: 120), // Haricots rouges en conserve égouttés
                NutritionIngredient(foodID: "20276", grams: 100), // Tomate crue
                NutritionIngredient(foodID: "20087", grams: 75), // Poivron rouge cru
                NutritionIngredient(foodID: "19646", grams: 70), // Fromage blanc nature
                NutritionIngredient(foodID: "2007", grams: 10) // Jus de citron pressé
            ],
            instructions: [
                "Rince et égoutte les haricots en conserve avant de les peser. Écrase-les avec le fromage blanc et le jus de citron.",
                "Rince le poivron et la tomate. Retire les graines du poivron et taille les deux légumes en lamelles.",
                "Réchauffe brièvement les tortillas à la poêle. Étale les haricots au centre, ajoute les crudités, replie les côtés et roule."
            ]
        ),
        NutritionRecipe(
            id: "saumon-patate-douce-haricots",
            name: "Saumon rôti, patate douce et haricots verts",
            meal: .dinner,
            minutes: 35,
            vegetarian: false,
            ingredients: [
                NutritionIngredient(foodID: "26230", grams: 130), // Saumon d’élevage cuit au four
                NutritionIngredient(foodID: "4102", grams: 180), // Patate douce cuite
                NutritionIngredient(foodID: "20320", grams: 160), // Haricots verts bouillis
                NutritionIngredient(foodID: "17270", grams: 6), // Huile d’olive
                NutritionIngredient(foodID: "2007", grams: 15) // Jus de citron pressé
            ],
            instructions: [
                "Préchauffe le four à 200 °C. Coupe la patate douce en petits cubes, mélange-la avec l’huile et enfourne-la 25 minutes.",
                "Mets le saumon à cuire dans un plat séparé pendant les 12 à 15 dernières minutes, jusqu’à 65 °C à cœur. Poursuis la cuisson si nécessaire.",
                "Fais cuire les haricots verts dans l’eau bouillante 8 à 10 minutes, puis égoutte-les.",
                "Pèse le poisson et les légumes après cuisson. Dresse l’assiette et ajoute le jus de citron."
            ]
        ),
        NutritionRecipe(
            id: "tofu-boulgour-legumes",
            name: "Poêlée de tofu, boulgour et légumes",
            meal: .dinner,
            minutes: 22,
            vegetarian: true,
            ingredients: [
                NutritionIngredient(foodID: "20904", grams: 150), // Tofu nature
                NutritionIngredient(foodID: "9691", grams: 160), // Boulgour cuit
                NutritionIngredient(foodID: "20087", grams: 110), // Poivron rouge pesé cru
                NutritionIngredient(foodID: "20009", grams: 100), // Carotte pesée crue
                NutritionIngredient(foodID: "17270", grams: 8), // Huile d’olive
                NutritionIngredient(foodID: "2007", grams: 15) // Jus de citron pressé
            ],
            instructions: [
                "Pèse le boulgour déjà cuit. Éponge et coupe le tofu en dés. Pèse le poivron et la carotte crus, puis taille-les en bâtonnets fins.",
                "Fais dorer le tofu à feu moyen dans l’huile 6 à 8 minutes en le retournant. Ajoute les légumes et poursuis 5 à 7 minutes en remuant.",
                "Ajoute le boulgour, réchauffe-le à cœur en mélangeant, puis arrose de jus de citron hors du feu."
            ]
        ),
        NutritionRecipe(
            id: "curry-pois-chiches-epinards",
            name: "Curry de pois chiches, épinards et quinoa",
            meal: .dinner,
            minutes: 20,
            vegetarian: true,
            ingredients: [
                NutritionIngredient(foodID: "20532", grams: 160), // Pois chiches en conserve égouttés
                NutritionIngredient(foodID: "9341", grams: 140), // Quinoa cuit
                NutritionIngredient(foodID: "20336", grams: 150), // Épinards bouillis
                NutritionIngredient(foodID: "20170", grams: 140), // Purée de tomates
                NutritionIngredient(foodID: "20239", grams: 40), // Oignon jaune pesé cru
                NutritionIngredient(foodID: "17270", grams: 8), // Huile d’olive
                NutritionIngredient(foodID: "11005", grams: 2) // Curry en poudre
            ],
            instructions: [
                "Pars de quinoa et d’épinards déjà cuits. Rince et égoutte les pois chiches avant de les peser.",
                "Émince l’oignon, fais-le revenir 3 minutes dans l’huile, puis remue avec le curry et la purée de tomates.",
                "Ajoute les pois chiches et les épinards. Laisse mijoter 8 à 10 minutes. Réchauffe le quinoa à cœur et sers-le avec le curry."
            ]
        ),
        NutritionRecipe(
            id: "tartines-sardines-carotte",
            name: "Tartines de sardines au citron et crudités",
            meal: .dinner,
            minutes: 12,
            vegetarian: false,
            ingredients: [
                NutritionIngredient(foodID: "26040", grams: 100), // Sardines à l’huile d’olive égouttées
                NutritionIngredient(foodID: "7110", grams: 80), // Pain complet
                NutritionIngredient(foodID: "20276", grams: 120), // Tomate crue
                NutritionIngredient(foodID: "20009", grams: 80), // Carotte crue
                NutritionIngredient(foodID: "2007", grams: 15) // Jus de citron pressé
            ],
            instructions: [
                "Égoutte les sardines avant de les peser, puis écrase-les à la fourchette avec le jus de citron.",
                "Rince puis tranche la tomate. Pèle et râpe la carotte.",
                "Grille le pain complet, garnis-le de sardines et de tomate. Sers la carotte râpée à côté."
            ]
        ),
        NutritionRecipe(
            id: "poire-fromage-blanc-amandes",
            name: "Poire, fromage blanc et amandes",
            meal: .snack,
            minutes: 5,
            vegetarian: true,
            ingredients: [
                NutritionIngredient(foodID: "13037", grams: 150), // Poire avec peau
                NutritionIngredient(foodID: "19646", grams: 150), // Fromage blanc nature
                NutritionIngredient(foodID: "15000", grams: 15) // Amandes non salées
            ],
            instructions: [
                "Rince la poire. Retire le trognon, pèse les morceaux avec la peau, puis coupe-les en dés.",
                "Dépose les dés sur le fromage blanc et ajoute les amandes grossièrement concassées."
            ]
        ),
        NutritionRecipe(
            id: "houmous-tartine-carotte",
            name: "Tartine de houmous et bâtonnets de carotte",
            meal: .snack,
            minutes: 6,
            vegetarian: true,
            ingredients: [
                NutritionIngredient(foodID: "25621", grams: 65), // Houmous
                NutritionIngredient(foodID: "7110", grams: 40), // Pain complet
                NutritionIngredient(foodID: "20009", grams: 100) // Carotte crue
            ],
            instructions: [
                "Épluche la carotte et coupe-la en bâtonnets.",
                "Grille le pain complet et étale le houmous. Sers les bâtonnets à côté."
            ]
        )
    ]
}
