import AVKit
import SwiftUI

struct ExerciseGuide {
    let motion: ExerciseMotion
    let equipment: ExerciseEquipmentDiagram
    let setup: String
    let action: String
    let breathing: String
    let commonMistake: String
    let progression: String

    init(
        _ motion: ExerciseMotion,
        _ equipment: ExerciseEquipmentDiagram,
        setup: String,
        action: String,
        breathing: String,
        commonMistake: String,
        progression: String
    ) {
        self.motion = motion
        self.equipment = equipment
        self.setup = setup
        self.action = action
        self.breathing = breathing
        self.commonMistake = commonMistake
        self.progression = progression
    }

    static func find(_ name: String) -> Self? { catalog[name] }

    private static let catalog: [String: Self] = [
        "Presse à cuisses": .init(.legPress, .legPress,
            setup: "Règle le siège et les sécurités avec la charge au minimum. Pose les pieds à plat sur le plateau, environ à largeur des hanches.",
            action: "Descends le plateau en pliant hanches et genoux tant que le bassin reste contre le dossier. Repousse par tout le pied. Garde les genoux dans la direction des orteils.",
            breathing: "Inspire à la descente. Souffle en repoussant le plateau.",
            commonMistake: "Décoller le bassin en bas ou claquer les genoux en haut.",
            progression: "Teste les sécurités à vide. Ajoute le plus petit palier disponible quand toutes les répétitions sont régulières."),
        "Goblet squat": .init(.gobletSquat, .goblet,
            setup: "Tiens un haltère léger à deux mains contre la poitrine. Choisis un écartement confortable avec les pieds entièrement au sol.",
            action: "Plie les hanches et les genoux ensemble. Descends jusqu’à une profondeur stable, puis repousse le sol sans perdre l’appui du pied.",
            breathing: "Inspire en descendant. Souffle en remontant.",
            commonMistake: "Éloigner l’haltère du buste ou laisser les talons monter.",
            progression: "Trouve d’abord une profondeur répétable. Ajoute ensuite des répétitions dans la plage prévue avant d’augmenter la charge."),
        "Squat au poids du corps": .init(.squat, .floor,
            setup: "Place les pieds à une largeur confortable, pointes légèrement ouvertes si besoin. Garde les pieds en entier au sol.",
            action: "Plie les hanches et les genoux pour descendre entre les pieds. Remonte en gardant les genoux orientés comme les orteils.",
            breathing: "Inspire à la descente. Souffle en remontant.",
            commonMistake: "Chercher la profondeur au prix d’une perte d’équilibre.",
            progression: "Commence par effleurer une chaise stable si nécessaire. Abaisse ensuite légèrement le repère ou ajoute des répétitions."),
        "Développé à la machine": .init(.chestPress, .chestPress,
            setup: "Règle le siège pour placer les poignées autour du milieu de la poitrine. Garde le dos posé et les pieds au sol.",
            action: "Pousse les poignées devant toi avec les poignets alignés. Ramène-les doucement jusqu’à une amplitude confortable, coudes légèrement sous la ligne des épaules.",
            breathing: "Souffle en poussant. Inspire au retour.",
            commonMistake: "Hausser les épaules, creuser le bas du dos ou laisser revenir les poids d’un coup.",
            progression: "Maîtrise la phase de retour avec une charge légère avant de monter d’un palier."),
        "Développé haltères au sol": .init(.floorPress, .dumbbell,
            setup: "Allonge-toi sur le dos, genoux pliés et pieds à plat. Place un haltère léger dans chaque main au-dessus des coudes.",
            action: "Abaisse les bras avec les coudes légèrement près du buste jusqu’à effleurer le sol. Repousse les haltères au-dessus de la poitrine.",
            breathing: "Inspire à la descente. Souffle lors de la montée.",
            commonMistake: "Rebondir sur les coudes ou écarter les bras au maximum.",
            progression: "Commence avec une prise neutre et des charges que tu peux installer et poser seul en sécurité."),
        "Pompes inclinées": .init(.inclinePushUp, .bench,
            setup: "Pose les mains un peu plus larges que les épaules sur un support fixe et assez haut. Recule les pieds pour aligner tête, bassin et talons.",
            action: "Approche la poitrine du support en pliant les coudes. Repousse en gardant le bassin solidaire du buste.",
            breathing: "Inspire en fléchissant les bras. Souffle en repoussant.",
            commonMistake: "Laisser les hanches s’affaisser ou choisir une surface mobile.",
            progression: "Commence sur un support haut et stable. Baisse-le un peu quand tu contrôles la série."),
        "Tirage horizontal assis": .init(.seatedRow, .seatedRow,
            setup: "Assieds-toi face à la poulie. Pose les pieds sur les appuis et tiens la poignée, tronc stable et genoux légèrement pliés.",
            action: "Tire vers le bas des côtes en ramenant les coudes près du corps. Allonge les bras au retour en gardant le buste stable.",
            breathing: "Souffle en tirant. Inspire au retour.",
            commonMistake: "Se pencher fortement en arrière pour déplacer la charge.",
            progression: "Réduis le poids si ton buste oscille ou si les épaules remontent."),
        "Rowing haltère unilatéral": .init(.bentRow, .dumbbell,
            setup: "Pose la main libre sur un support stable. Fléchis un peu les genoux et incline le buste en reculant les hanches. Laisse l’haltère sous l’épaule.",
            action: "Ramène le coude vers la hanche. Redescends lentement sans tourner le bassin. Fais les deux côtés.",
            breathing: "Souffle en tirant. Inspire en redescendant.",
            commonMistake: "Ouvrir tout le buste pour aller chercher plus haut.",
            progression: "Utilise le même nombre de répétitions propres des deux côtés et une charge adaptée au côté le moins à l’aise."),
        "Tirage des coudes au sol": .init(.proneRow, .floor,
            setup: "Allonge-toi sur le ventre, regard vers le sol. Garde le bassin posé et tends les bras devant toi dans une amplitude confortable.",
            action: "Ramène les coudes vers les côtes et rapproche doucement les omoplates. Tends de nouveau les bras sans soulever le bas du dos.",
            breathing: "Souffle quand tu ramènes les coudes. Inspire au retour.",
            commonMistake: "Relever fortement la tête ou prendre appui en cambrant.",
            progression: "Marque une seconde à la fin du tirage avant d’allonger la série."),
        "Gainage ventral": .init(.plank, .floor,
            setup: "Pose les avant-bras, coudes sous les épaules. Commence avec les genoux au sol si besoin.",
            action: "Tends les jambes si tu peux maintenir tête, bassin et talons alignés. Reste immobile dans cette position le temps prévu.",
            breathing: "Respire régulièrement pendant toute la tenue.",
            commonMistake: "Retenir son souffle, creuser les lombaires ou repousser le bassin trop haut.",
            progression: "Accumule des tenues courtes bien alignées. Allonge chaque tenue seulement si tu gardes la position et la respiration."),
        "Soulevé de terre roumain avec haltères": .init(.hinge, .dumbbell,
            setup: "Debout, haltères devant les cuisses, pieds à largeur des hanches et genoux légèrement fléchis.",
            action: "Recule les hanches et laisse les haltères glisser près des jambes. Arrête la descente quand l’arrière des cuisses est en tension et que le dos reste stable. Redresse-toi par les hanches.",
            breathing: "Inspire avant ou pendant la descente. Souffle en remontant.",
            commonMistake: "Chercher à toucher le sol, éloigner les poids ou arrondir le dos pour gagner de l’amplitude.",
            progression: "Répète le recul de hanches sans charge avant d’essayer des haltères légers."),
        "Bascule du bassin, dos neutre": .init(.hinge, .floor,
            setup: "Debout, genoux souples. Place les mains sur les plis des hanches si cela t’aide à sentir le mouvement.",
            action: "Envoie les hanches vers l’arrière et incline le buste avec le dos stable. Reviens debout en ramenant les hanches.",
            breathing: "Inspire en reculant. Souffle en te redressant.",
            commonMistake: "Transformer la bascule en squat profond ou arrondir les épaules.",
            progression: "Place un mur derrière toi et touche-le doucement avec les fesses. Éloigne-toi un peu quand le mouvement devient naturel."),
        "Tirage vertical poitrine": .init(.pulldown, .pulldown,
            setup: "Assieds-toi, cuisses maintenues par les coussins. Attrape la barre avec une largeur de prise confortable.",
            action: "Ramène les coudes vers le bas et la barre vers le haut de la poitrine. Rallonge les bras sous contrôle.",
            breathing: "Souffle en tirant. Inspire à la remontée.",
            commonMistake: "Tirer derrière la nuque ou se balancer pour descendre la barre.",
            progression: "Vise d’abord une trajectoire stable et une amplitude confortable. Ajuste la hauteur des cale-cuisses avant la charge."),
        "Pull-over haltère au sol": .init(.pullover, .dumbbell,
            setup: "Allonge-toi, pieds au sol. Tiens un haltère léger à deux mains au-dessus de la poitrine, coudes légèrement fléchis.",
            action: "Amène doucement les bras derrière la tête jusqu’à une amplitude confortable. Ramène le poids au-dessus de la poitrine avec les coudes légèrement fléchis.",
            breathing: "Inspire quand le poids part vers l’arrière. Souffle quand tu le ramènes.",
            commonMistake: "Forcer l’extension des épaules, cambrer fortement ou descendre un poids difficile à contrôler.",
            progression: "Commence avec un objet léger et une petite amplitude. Augmente un seul paramètre à la fois."),
        "Y-T-W au sol": .init(.ytW, .floor,
            setup: "Allonge-toi sur le ventre, front proche du sol, jambes détendues et pouces orientés vers le haut dans les positions confortables.",
            action: "Soulève légèrement les bras en diagonale pour le Y. Repose-les, ouvre les bras sur les côtés pour le T, puis plie les coudes pour le W. Garde les épaules loin des oreilles.",
            breathing: "Souffle à chaque petite levée. Inspire en reposant les bras.",
            commonMistake: "Chercher à monter haut en relevant la tête ou la poitrine.",
            progression: "Travaille les trois positions séparément avant d’enchaîner la séquence. Commence sans charge."),
        "Développé épaules à la machine": .init(.overheadPress, .shoulderPress,
            setup: "Règle le siège pour démarrer les poignées près de la hauteur des épaules. Pieds et dos restent stables.",
            action: "Pousse au-dessus de la tête dans une amplitude confortable. Redescends les poignées doucement vers leur position de départ.",
            breathing: "Souffle à la poussée. Inspire pendant la descente.",
            commonMistake: "Accentuer la cambrure pour finir ou laisser les poids retomber.",
            progression: "Maîtrise une charge légère et une course régulière. Change de variante si la trajectoire fixe te gêne."),
        "Développé épaules avec haltères": .init(.overheadPress, .dumbbell,
            setup: "Assieds-toi sur un siège stable. Pieds au sol, haltères près des épaules, avant-bras presque verticaux.",
            action: "Pousse les haltères au-dessus de la tête sans chercher à les entrechoquer. Redescends lentement à la hauteur de départ.",
            breathing: "Souffle quand tu montes les haltères. Inspire au retour.",
            commonMistake: "Sortir fortement les côtes ou descendre dans une zone douloureuse.",
            progression: "Essaie une prise neutre et des haltères faciles à installer si tu débutes."),
        "Glissés des bras au mur": .init(.wallSlide, .wall,
            setup: "Place-toi dos à un mur, pieds un peu avancés si nécessaire. Mets les bras en W à une hauteur confortable.",
            action: "Fais glisser les bras vers le haut sans forcer le contact des poignets avec le mur. Reviens lentement.",
            breathing: "Respire normalement et souffle doucement en montant les bras.",
            commonMistake: "Creuser le dos pour forcer les mains à toucher le mur.",
            progression: "Gagne de la hauteur progressivement tant que la cage thoracique reste stable."),
        "Curl biceps à la poulie": .init(.curl, .cableCurl,
            setup: "Place la poulie en bas et saisis la poignée. Debout, genoux souples, poignets droits.",
            action: "Plie les coudes pour monter la poignée. Redescends sous contrôle, coudes près du corps.",
            breathing: "Souffle en pliant les bras. Inspire en allongeant les bras.",
            commonMistake: "Donner un élan avec le dos ou laisser la charge repartir d’un coup.",
            progression: "Recule légèrement si le câble frotte. Charge davantage quand le buste reste stable du début à la fin."),
        "Curl biceps avec haltères": .init(.curl, .dumbbell,
            setup: "Debout, haltères de chaque côté, épaules détendues. Place les paumes vers l’avant ou garde une prise neutre.",
            action: "Plie les coudes sans déplacer les épaules. Redescends lentement jusqu’à une extension confortable.",
            breathing: "Souffle à la montée. Inspire à la descente.",
            commonMistake: "Se balancer ou plier les poignets pour terminer la répétition.",
            progression: "Travaille un bras à la fois si cela facilite le contrôle. Choisis la charge selon le côté le moins à l’aise."),
        "Pompes au mur, prise serrée": .init(.wallPushUp, .wall,
            setup: "Pose les mains sur un mur stable à hauteur de poitrine, environ à largeur d’épaules. Recule légèrement les pieds.",
            action: "Approche la poitrine du mur en pliant les coudes vers l’arrière. Repousse en gardant le buste et les hanches alignés.",
            breathing: "Inspire en allant vers le mur. Souffle en repoussant.",
            commonMistake: "Coller les mains au point de gêner les poignets ou sortir les coudes sur les côtés.",
            progression: "Éloigne un peu les pieds si l’appui reste stable. Un support incliné fixe est l’étape suivante."),
        "Fentes arrière": .init(.reverseLunge, .floor,
            setup: "Debout, pieds à largeur de hanches. Fixe un point devant toi pour garder l’équilibre.",
            action: "Recule un pied et plie les deux genoux. Garde le pied avant à plat et pousse dessus pour revenir. Alterne les côtés.",
            breathing: "Inspire en descendant. Souffle au retour debout.",
            commonMistake: "Poser les pieds sur une même ligne étroite ou pousser surtout avec le pied arrière.",
            progression: "Commence avec un petit pas et une amplitude courte. Augmente l’amplitude si le retour reste stable."),
        "Fentes arrière avec haltères": .init(.reverseLunge, .dumbbell,
            setup: "Choisis deux haltères suffisamment légers pour garder l’équilibre. Laisse les bras le long du corps.",
            action: "Fais un pas en arrière, plie les deux jambes puis repousse avec le pied avant. Garde les genoux dans la direction des orteils.",
            breathing: "Inspire au pas arrière. Souffle en remontant.",
            commonMistake: "Se précipiter en bas ou tourner le buste pour tenir la charge.",
            progression: "Maîtrise les fentes sans charge avant de prendre les haltères."),
        "Fentes arrière avec appui": .init(.reverseLunge, .lowSupport,
            setup: "Place-toi près d’un mur ou d’un montant fixe. Prends un appui léger de la main sans te suspendre.",
            action: "Recule un pied et descends à une profondeur stable. Garde le pied avant à plat et pousse dessus pour revenir.",
            breathing: "Inspire à la descente. Souffle en remontant.",
            commonMistake: "Tirer sur l’appui pour remonter ou croiser le pied arrière derrière le pied avant.",
            progression: "Diminue l’aide de la main progressivement. Garde l’appui accessible si l’équilibre varie."),
        "Mollets debout": .init(.calfRaise, .floor,
            setup: "Pieds à plat, environ à largeur de hanches. Tiens-toi debout avec les genoux souples.",
            action: "Monte les talons en appuyant sur l’avant des deux pieds. Marque une courte pause. Redescends jusqu’au sol sous contrôle.",
            breathing: "Souffle en montant. Inspire au retour.",
            commonMistake: "Rebondir sur les chevilles ou rouler sur les bords des pieds.",
            progression: "Maîtrise l’aller-retour au sol. Ajoute ensuite des répétitions ou une charge légère."),
        "Mollets debout avec haltères": .init(.calfRaise, .dumbbell,
            setup: "Tiens des haltères légers le long du corps, sur un sol plat. Garde les pieds parallèles dans une position confortable.",
            action: "Décolle les talons, marque un temps en haut, puis repose-les lentement.",
            breathing: "Souffle à la montée. Inspire à la descente.",
            commonMistake: "Ajouter des poids quand l’équilibre est instable ou accélérer en fin de série.",
            progression: "Reviens au poids du corps avec un appui si tu oscilles. Monte la charge par petits paliers."),
        "Mollets debout avec appui": .init(.calfRaise, .lowSupport,
            setup: "Tiens un support fixe du bout des doigts. Pieds au sol et genoux souples.",
            action: "Monte les talons, puis abaisse-les sans rebond. Le support sert seulement à garder l’équilibre.",
            breathing: "Souffle en montant. Inspire en redescendant.",
            commonMistake: "Pousser avec les bras pour décoller les talons.",
            progression: "Garde une montée régulière et diminue d’abord l’appui de la main."),
        "Hip thrust guidé": .init(.hipThrust, .hipMachine,
            setup: "Règle le dossier et le coussin de la machine selon son mode d’emploi. Place le coussin au pli des hanches et les pieds à plat.",
            action: "Pousse dans le sol pour monter les hanches jusqu’à aligner le buste et les cuisses. Redescends sous contrôle.",
            breathing: "Souffle à la montée. Inspire en redescendant.",
            commonMistake: "Prolonger le mouvement en cambrant le bas du dos ou perdre l’appui des pieds.",
            progression: "Essaie d’abord à vide et vérifie la sécurité de la machine. Augmente un seul palier à la fois."),
        "Pont fessier avec haltère": .init(.gluteBridge, .hipDumbbell,
            setup: "Allonge-toi dos au sol, genoux pliés. Maintiens un haltère léger et stable au pli des hanches, avec une protection si besoin.",
            action: "Pousse dans le sol et serre les fessiers pour aligner bassin et cuisses avec le buste. Redescends sans laisser tomber la charge.",
            breathing: "Souffle en soulevant les hanches. Inspire au retour.",
            commonMistake: "Faire glisser l’haltère sur le ventre ou accentuer la cambrure en haut.",
            progression: "Vérifie que tu peux installer et retirer l’haltère seul en sécurité. Le pont sans charge reste une variante."),
        "Pont fessier au sol": .init(.gluteBridge, .floor,
            setup: "Allonge-toi dos au sol, genoux pliés et pieds à plat. Laisse les bras au sol.",
            action: "Pousse avec les pieds et décolle les hanches jusqu’à former une ligne entre épaules, bassin et genoux. Redescends lentement.",
            breathing: "Souffle en montant. Inspire en descendant.",
            commonMistake: "Monter trop haut en creusant le dos ou laisser les genoux se rapprocher.",
            progression: "Marque une seconde en haut avant d’ajouter des répétitions."),
        "Vélo ou tapis, allure modérée": .init(.walk, .treadmill,
            setup: "Le schéma montre le tapis. Démarre à basse vitesse et repère son arrêt de sécurité. À vélo, règle la selle pour garder le genou légèrement plié quand la pédale est en bas.",
            action: "Augmente l’allure progressivement jusqu’à respirer plus vite tout en restant capable de parler. Ralentis en fin de séance.",
            breathing: "Respire naturellement. Adapte l’allure si parler devient difficile.",
            commonMistake: "Démarrer vite ou s’accrocher aux poignées pour tenir une allure trop élevée.",
            progression: "Ajoute d’abord quelques minutes à une intensité maîtrisée. Modifie ensuite la vitesse ou la résistance."),
        "Marche rapide, allure modérée": .init(.walk, .floor,
            setup: "Choisis un terrain régulier et une paire confortable. Commence à un rythme facile.",
            action: "Accélère jusqu’à sentir l’effort tout en pouvant parler en phrases. Reste détendu et laisse les bras accompagner les pas.",
            breathing: "Respire librement. Si tu peines à parler, réduis l’allure.",
            commonMistake: "Allonger exagérément le pas ou accélérer dès les premières secondes.",
            progression: "Allonge la marche par petits blocs avant d’ajouter un dénivelé."),
        "Marche, allure facile": .init(.walk, .floor,
            setup: "Prends un trajet simple et une allure permettant de parler sans effort.",
            action: "Avance avec des pas naturels et réguliers. Relâche les épaules.",
            breathing: "Respire librement et garde une allure confortable.",
            commonMistake: "Transformer la récupération en séance rapide.",
            progression: "Prolonge de quelques minutes si tu te sens disponible, sans objectif de vitesse."),
        "Retour au calme, allure facile": .init(.walk, .floor,
            setup: "À la fin de la séance, conserve quelques minutes pour réduire progressivement l’effort.",
            action: "Ralentis par étapes et marche ou pédale à une allure facile.",
            breathing: "Respire naturellement et attends que le souffle revienne à un rythme confortable.",
            commonMistake: "Garder le rythme soutenu jusqu’au dernier instant.",
            progression: "Ajuste la durée au retour de ton confort. Le but est de redescendre en intensité."),
        "Mobilité douce des hanches et des épaules": .init(.wallSlide, .wall,
            setup: "Prends appui sur un mur si besoin. Le schéma montre les épaules. Pour les hanches, commence debout avec les genoux souples.",
            action: "Monte et redescends les bras sans forcer. Pour les hanches, fais de petits cercles lents dans les deux sens en gardant les pieds au sol.",
            breathing: "Respire librement sur toute l’amplitude.",
            commonMistake: "Forcer un mouvement en butée ou retenir la respiration.",
            progression: "Explore une amplitude un peu plus grande seulement si elle reste confortable.")
    ]
}

struct ExerciseGuideScreen: View {
    let exercise: WorkoutExercise
    @State private var restEndsAt: Date?

    var body: some View {
        KPage {
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.system(.largeTitle).weight(.heavy))
                    .accessibilityAddTraits(.isHeader)
                Text(exercise.summaryText)
                    .font(.subheadline)
                    .foregroundStyle(muted)
            }
            if exercise.restSeconds > 0 {
                restTimer
            }
            if let guide = ExerciseGuide.find(exercise.name) {
                if let film = ExerciseFilmAsset.catalogue[exercise.name], let url = film.resourceURL {
                    ExerciseFilm(asset: film, url: url)
                } else {
                    ExerciseMotionView(motion: guide.motion, equipment: guide.equipment)
                }
                VStack(alignment: .leading, spacing: 16) {
                    instruction("Installation", guide.setup)
                    instruction("Mouvement", guide.action)
                    instruction("Respiration", guide.breathing)
                    instruction("À éviter", guide.commonMistake)
                    instruction("Progression", guide.progression)
                }
                .kPanel()

                instruction(
                    "Écoute tes sensations",
                    "Commence léger ou avec une petite amplitude. Arrête le mouvement si une douleur nouvelle ou inhabituelle apparaît."
                )
            } else {
                instruction(
                    "Fiche indisponible",
                    "Cet exercice vient d’une ancienne version du programme. Fais-toi montrer le geste avant de le charger."
                )
            }
        }
        .navigationTitle("Exercice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var restTimer: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int(ceil(restEndsAt?.timeIntervalSince(context.date) ?? 0)))
            let active = remaining > 0 && restEndsAt != nil
            VStack(alignment: .leading, spacing: 8) {
                if active {
                    let minutes = remaining / 60
                    let seconds = remaining % 60
                    Text("\(minutes):\(seconds.formatted(.number.precision(.integerLength(2))))")
                        .font(.title2.weight(.bold).monospacedDigit())
                        .accessibilityLabel("Repos restant")
                        .accessibilityValue("\(remaining) secondes")
                    Button("Arrêter le repos") { restEndsAt = nil }
                        .buttonStyle(ActionStyle(filled: false))
                } else {
                    if restEndsAt != nil {
                        Text("Repos terminé").font(.subheadline.weight(.semibold))
                    }
                    Button {
                        restEndsAt = .now.addingTimeInterval(Double(exercise.restSeconds))
                    } label: {
                        Label("Démarrer le repos · \(exercise.restSeconds) s", systemImage: "timer")
                    }
                    .buttonStyle(ActionStyle(filled: false))
                }
            }
        }
    }

    private func instruction(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            Text(text).foregroundStyle(muted)
        }
    }
}

private struct ExerciseFilmAsset: Decodable {
    let resource: String
    let width: Int
    let height: Int
    let credit: String
    let source: String?

    static let catalogue: [String: Self] = {
        guard let url = bundledURL("kaaris-exercise-videos", extension: "json"),
              let data = try? Data(contentsOf: url),
              let assets = try? JSONDecoder().decode([String: Self].self, from: data) else { return [:] }
        return assets.filter { _, asset in
            asset.width > 0 && asset.height > 0
                && asset.resource.range(of: "^[a-z0-9-]+$", options: .regularExpression) != nil
        }
    }()

    var resourceURL: URL? { Self.bundledURL(resource, extension: "mp4") }

    var sourceURL: URL? {
        guard let source, let url = URL(string: source), url.scheme == "https",
              url.host != nil, url.user == nil, url.password == nil else { return nil }
        return url
    }

    private static func bundledURL(_ name: String, extension ext: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "ExerciseVideos")
            ?? Bundle.main.url(forResource: name, withExtension: ext)
    }
}

private struct ExerciseFilm: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var player: AVPlayer?
    let asset: ExerciseFilmAsset
    let url: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "DÉMONSTRATION VIDÉO")
            VideoPlayer(player: player)
                .aspectRatio(CGFloat(asset.width) / CGFloat(asset.height), contentMode: .fit)
                .background(.black, in: RoundedRectangle(cornerRadius: 12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if let source = asset.sourceURL {
                Link(asset.credit, destination: source)
                    .font(.footnote).foregroundStyle(muted)
            } else {
                Text(asset.credit)
                    .font(.footnote).foregroundStyle(muted)
            }
        }
        .kPanel()
        .task { player = AVPlayer(url: url) }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { player?.pause() }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

extension WorkoutExercise {
    var summaryText: String {
        let series = sets == 1 ? "1 série" : "\(sets) séries"
        let rest = restSeconds > 0 ? " · repos \(restSeconds) s" : ""
        return "\(series) · \(reps)\(rest)"
    }
}
