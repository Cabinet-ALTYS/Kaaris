import Foundation

enum WorkoutRevisionFocus {
    case fullBody, upperBody, lowerBody, cardio, recovery
}

struct WorkoutRevisionRequest {
    enum Effort { case lighter, harder }

    var minutes: Int?
    var equipment: WorkoutEquipment?
    var focus: WorkoutRevisionFocus?
    var effort: Effort?
    var target: String?
    var replacement: String?

    init(_ message: String, currentMinutes: Int) throws {
        let text = Self.normalized(message)
        let tokens = Set(text.split(separator: " ").map(String.init))
        func has(_ phrase: String) -> Bool { (" " + text + " ").contains(" " + phrase + " ") }
        guard !["douleur", "blesse", "blessure", "mal au", "mal a la", "mal aux"].contains(where: has) else {
            throw WorkoutRevisionError.unsupported(
                "Pour une douleur ou une blessure, arrête le mouvement concerné. Décris le changement de séance que tu veux faire."
            )
        }
        if ["reporte", "reporter", "decale", "decaler", "repousse la seance"].contains(where: has) {
            throw WorkoutRevisionError.unsupported("Pour changer le créneau, ouvre la séance et touche « Reporter ».")
        }

        if let value = Self.duration(in: text) {
            guard (10...90).contains(value) else {
                throw WorkoutRevisionError.unsupported("Choisis une durée de 10 à 90 minutes.")
            }
            minutes = value
        } else if ["plus court", "plus courte", "raccourcis", "raccourcir", "moins long", "moins longue"].contains(where: has) {
            minutes = max(10, currentMinutes - 10)
        } else if ["plus long", "plus longue", "allonge", "prolonge", "plus de temps"].contains(where: has) {
            minutes = min(90, currentMinutes + 10)
        }

        if ["sans materiel", "sans equipement", "sans halteres", "poids du corps"].contains(where: has) {
            equipment = .bodyweight
        } else if ["avec halteres", "avec les halteres", "avec des halteres", "que des halteres", "juste des halteres"].contains(where: has)
                    || tokens == ["halteres"] {
            equipment = .dumbbells
        } else if ["en salle", "salle de sport", "avec les machines", "sur machine"].contains(where: has) {
            equipment = .gym
        }

        if let match = text.range(of: #"\b(?:remplace|remplacer|change|changer|retire|retirer|enleve|enlever|supprime|supprimer)\s+"#, options: .regularExpression) {
            let verb = text[match].trimmingCharacters(in: .whitespaces)
            let phrase = String(text[match.upperBound...])
            let names = phrase.components(separatedBy: " par ")
            target = names.first
            if names.count > 1 {
                replacement = names[1].components(separatedBy: " et ").first
            } else if ["remplace", "remplacer", "change", "changer"].contains(verb) {
                replacement = ""
            }
        } else if let match = text.range(of: #"\b(?:sans|pas de)\s+(?:le\s+|la\s+|les\s+)?(?:squat|squats|fente|fentes|gainage|pompes|presse|developpe|rowing|tirage|curl|hip thrust)\b"#, options: .regularExpression) {
            let phrase = String(text[match])
            target = phrase.hasPrefix("sans ") ? String(phrase.dropFirst(5)) : String(phrase.dropFirst(7))
        }

        if target == nil {
            if ["mobilite", "recuperation", "recuperer", "repos actif"].contains(where: has) {
                focus = .recovery
            } else if ["haut du corps", "haut seulement"].contains(where: has) {
                focus = .upperBody
            } else if !has("pas de jambes"), ["bas du corps", "jambes", "fessiers"].contains(where: has) {
                focus = .lowerBody
            } else if ["corps entier", "full body", "tout le corps"].contains(where: has) {
                focus = .fullBody
            } else if !has("sans cardio") && !has("pas de cardio") && ["cardio", "endurance", "marche rapide"].contains(where: has) {
                focus = .cardio
            }
        }

        if ["plus facile", "moins dur", "plus leger", "plus legere", "moins intense", "allege", "plus doux"].contains(where: has) {
            effort = .lighter
        } else if ["plus dur", "plus difficile", "plus intense", "plus de series"].contains(where: has) {
            effort = .harder
        }

        guard minutes != nil || equipment != nil || focus != nil || effort != nil || target != nil else {
            throw WorkoutRevisionError.unsupported(
                "Précise ce que tu changes. Par exemple « 25 minutes sans matériel », « haut du corps » ou « remplace le squat »."
            )
        }
    }

    static func normalized(_ value: String) -> String {
        let plain = value.lowercased().folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "fr_FR"))
        return plain.replacingOccurrences(of: #"[^a-z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func duration(in text: String) -> Int? {
        let padded = " " + text + " "
        if padded.contains(" une heure et demie ") || padded.contains(" 1 h 30 ") { return 90 }
        if padded.contains(" une demi heure ") || padded.contains(" 30 mn ") { return 30 }
        if let range = text.range(of: #"\b[0-9]{1,2}\s*h\s*[0-9]{1,2}\b"#, options: .regularExpression) {
            let parts = text[range].split(separator: "h").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 2 { return parts[0] * 60 + parts[1] }
        }
        func number(before unit: String) -> Int? {
            guard let range = text.range(of: "\\b[0-9]{1,4}\\s*(?=(?:\(unit))\\b)", options: .regularExpression) else { return nil }
            return Int(text[range].trimmingCharacters(in: .whitespaces))
        }
        if let hour = number(before: "h|heures?") {
            guard hour <= 24 else { return 1440 }
            return hour * 60 + (number(before: "minutes?|mins?|mn") ?? 0)
        }
        if let minutes = number(before: "minutes?|mins?|mn") { return minutes }
        if padded.contains(" une heure ") { return 60 }
        let units = ["un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf"]
        let tens = [(20, "vingt"), (30, "trente"), (40, "quarante"), (50, "cinquante"), (60, "soixante"), (80, "quatre vingt")]
        let suffixes = [" minute ", " minutes ", " min ", " mn "]
        for (base, word) in tens {
            for (offset, unit) in units.enumerated() {
                if suffixes.contains(where: { padded.contains(" " + word + " " + unit + $0) || padded.contains(" " + word + " et " + unit + $0) }) {
                    return base + offset + 1
                }
            }
            if suffixes.contains(where: { padded.contains(" " + word + $0) }) { return base }
        }
        let common = [(10, "dix"), (12, "douze"), (15, "quinze"), (70, "soixante dix"), (75, "soixante quinze"), (90, "quatre vingt dix")]
        return common.first(where: { entry in suffixes.contains { padded.contains(" " + entry.1 + $0) } })?.0
    }

    static func matchingExercise(_ phrase: String, in names: [String]) -> [String] {
        let query = normalized(phrase).replacingOccurrences(of: #"^(?:le|la|les|du|des|de|un|une|d|l)\s+"#, with: "", options: .regularExpression)
        guard !query.isEmpty else { return [] }
        if let exact = names.first(where: { normalized($0) == query }) { return [exact] }
        let words = Set(query.split(separator: " ").map { $0.hasSuffix("s") && $0.count > 4 ? String($0.dropLast()) : String($0) })
        return names.filter { name in
            let nameWords = Set(normalized(name).split(separator: " ").map { $0.hasSuffix("s") && $0.count > 4 ? String($0.dropLast()) : String($0) })
            return words.isSubset(of: nameWords)
        }
    }
}

enum WorkoutRevisionError: LocalizedError {
    case unsupported(String), noChange, inactive, stale, conflict

    var errorDescription: String? {
        switch self {
        case .unsupported(let message): message
        case .noChange: "La séance correspond déjà à cette demande. Essaie une autre durée ou précise le changement."
        case .inactive: "Cette séance ne peut plus être modifiée ici."
        case .stale: "La séance a changé depuis la proposition. Demande une nouvelle adaptation."
        case .conflict: "La nouvelle durée chevauche une autre séance. Choisis une durée plus courte ou reporte la séance."
        }
    }
}

struct WorkoutRevision {
    let original: WorkoutSession
    let revised: WorkoutSession

    var reply: String {
        let equipment: String
        switch revised.equipment {
        case .gym: equipment = " en salle"
        case .dumbbells: equipment = " avec des haltères"
        case .bodyweight: equipment = " sans matériel"
        case nil: equipment = ""
        }
        let namesBefore = Set(original.exercises.map(\.name))
        let added = revised.exercises.first { !namesBefore.contains($0.name) }
        let detail = added.map { " Au programme, \($0.name.lowercased())." } ?? ""
        return "Je te propose \(revised.durationMinutes) minutes\(equipment).\(detail) Tu peux encore affiner avant d’appliquer."
    }
}
