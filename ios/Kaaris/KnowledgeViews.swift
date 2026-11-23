import SwiftUI

struct KnowledgeCatalogue: Decodable {
    let version: Int
    let reviewedOn: String
    let articles: [KnowledgeArticle]

    static let bundled: KnowledgeCatalogue? = {
        let name = "kaaris-knowledge"
        guard let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Knowledge")
                ?? Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalogue = try? JSONDecoder().decode(Self.self, from: data),
              catalogue.version == 1,
              !catalogue.articles.isEmpty,
              Set(catalogue.articles.map(\.id)).count == catalogue.articles.count else { return nil }
        return catalogue
    }()

    var revisionLabel: String {
        guard let date = try? Date("\(reviewedOn)T12:00:00Z", strategy: .iso8601) else { return reviewedOn }
        return date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "fr_FR")))
    }
}

struct KnowledgeArticle: Decodable, Identifiable {
    struct Section: Decodable {
        let title: String
        let text: String
    }

    struct Source: Decodable {
        let title: String
        let url: String

        var httpsURL: URL? {
            guard let address = URL(string: url), address.scheme == "https",
                  address.host != nil, address.user == nil, address.password == nil else { return nil }
            return address
        }
    }

    let id: String
    let title: String
    let category: String
    let summary: String
    let sections: [Section]
    let sources: [Source]

    func matches(_ terms: [String]) -> Bool {
        let content = ([title, category, summary] + sections.flatMap { [$0.title, $0.text] })
            .joined(separator: " ")
        return terms.allSatisfy { content.localizedStandardContains($0) }
    }
}

struct KnowledgeScreen: View {
    @State private var query = ""
    @State private var category: String?

    var body: some View {
        KPage {
            KTitle(text: "SPORT & NUTRITION")
            if let catalogue = KnowledgeCatalogue.bundled {
                searchBar
                categoryPicker(catalogue.articles)
                articleList(catalogue.articles)
                Text("Fiches revues le \(catalogue.revisionLabel).")
                    .font(.footnote).foregroundStyle(muted)
            } else {
                Text("Les fiches ne sont pas disponibles dans cette version.")
                    .foregroundStyle(muted).kPanel()
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(acid).accessibilityHidden(true)
            TextField("Chercher un sujet", text: $query)
                .autocorrectionDisabled().submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .kPanel()
    }

    private func categoryPicker(_ articles: [KnowledgeArticle]) -> some View {
        let categories = Array(Set(articles.map(\.category))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                categoryButton("Tout", value: nil)
                ForEach(categories, id: \.self) { name in
                    categoryButton(name, value: name)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func categoryButton(_ name: String, value: String?) -> some View {
        let selected = category == value
        return Button {
            category = value
        } label: {
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? ink : .white)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(selected ? acid : panel, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func articleList(_ articles: [KnowledgeArticle]) -> some View {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        let visible = articles.filter { (category == nil || $0.category == category) && $0.matches(terms) }
        if visible.isEmpty {
            Text("Aucune fiche pour cette recherche.").foregroundStyle(muted).kPanel()
        } else {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(visible) { article in
                    NavigationLink {
                        KnowledgeArticleScreen(article: article)
                    } label: {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                SectionLabel(text: article.category)
                                Text(article.title).font(.headline).foregroundStyle(.white)
                                Text(article.summary).font(.subheadline).foregroundStyle(muted).lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.subheadline.weight(.semibold)).foregroundStyle(acid)
                                .accessibilityHidden(true)
                        }
                        .kPanel()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct KnowledgeArticleScreen: View {
    let article: KnowledgeArticle

    var body: some View {
        KPage {
            SectionLabel(text: article.category)
            KTitle(text: article.title)
            Text(article.summary).font(.title3.weight(.semibold))

            ForEach(Array(article.sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title).font(.headline)
                    Text(section.text).font(.body).foregroundStyle(muted)
                }
                .kPanel()
            }
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: "SOURCES")
                ForEach(Array(article.sources.enumerated()), id: \.offset) { _, source in
                    if let url = source.httpsURL {
                        Link(destination: url) {
                            Label(source.title, systemImage: "arrow.up.right").foregroundStyle(acid)
                        }
                    }
                }
            }
            .kPanel()
        }
        .toolbar(.visible, for: .navigationBar)
    }
}
