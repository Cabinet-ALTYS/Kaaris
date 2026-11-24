import SwiftUI

struct ExerciseMediaLibrary: View {
    private struct Entry: Identifiable {
        let name: String
        let media: ExerciseMediaAvailability

        var id: String { name }
    }

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "Tous"
        case avatars = "Avatars"
        case diagrams = "Schémas"

        var id: Self { self }

        func includes(_ media: ExerciseMediaAvailability) -> Bool {
            switch self {
            case .all: true
            case .avatars: media == .avatarVideo
            case .diagrams: media.isDiagram
            }
        }
    }

    private static let entries = ExerciseGuide.names.map {
        Entry(name: $0, media: ExerciseMediaAvailability.forExercise(named: $0))
    }

    @State private var query = ""
    @State private var filter = Filter.all

    var body: some View {
        let entries = Self.entries
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let results = entries.filter {
            filter.includes($0.media) && (search.isEmpty || $0.name.localizedStandardContains(search))
        }
        KPage {
            Text("\(entries.count) exercices · \(entries.filter { $0.media.isVideo }.count) vidéos")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(muted)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(muted)
                        .accessibilityHidden(true)
                    TextField("Rechercher un exercice", text: $query)
                        .submitLabel(.search)
                        .accessibilityIdentifier("exercise.media.search")
                    if !query.isEmpty {
                        Button("Effacer la recherche", systemImage: "xmark.circle.fill") { query = "" }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(muted)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .frame(minHeight: 44)
                .padding(.horizontal, 12)
                .background(panel, in: RoundedRectangle(cornerRadius: 13))

                Picker("Type de démonstration", selection: $filter) {
                    ForEach(Filter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("exercise.media.filter")
            }

            if results.isEmpty {
                Label("Aucun exercice trouvé", systemImage: "magnifyingglass")
                    .foregroundStyle(muted)
                    .kPanel()
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(results) { entry in
                        NavigationLink {
                            ExerciseGuideScreen(exerciseName: entry.name)
                        } label: {
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(entry.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    ExerciseMediaBadge(availability: entry.media)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(muted)
                                    .accessibilityHidden(true)
                            }
                            .multilineTextAlignment(.leading)
                            .kPanel()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .navigationTitle("Bibliothèque d’exercices")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .scrollDismissesKeyboard(.interactively)
    }
}

struct ExerciseMediaBadge: View {
    let availability: ExerciseMediaAvailability

    init(availability: ExerciseMediaAvailability) {
        self.availability = availability
    }

    init(exerciseName: String) {
        availability = .forExercise(named: exerciseName)
    }

    var body: some View {
        Label(availability.label, systemImage: availability.systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(availability.isVideo ? acid : muted)
    }
}
