import CodeIsraelKit
import SwiftUI

/// Practical help around the exam: the steps in Israel, and a French ↔ Hebrew glossary of the terms of the road code.
struct GuideView: View {
    private let guide = GuideContent.load()

    var body: some View {
        List {
            Section {
                NavigationLink { GlossaryView() } label: { Label("Glossaire français ↔ hébreu", systemImage: "character.book.closed") }
                NavigationLink { SourcesView() } label: { Label("Sources officielles et licence", systemImage: "info.circle") }
            }
            if let guide {
                ForEach(guide.sections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.items, id: \.self) { Text($0).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                    }
                }
                Section {
                    ForEach(guide.links, id: \.url) { link in
                        if let url = URL(string: link.url) { Link(link.label, destination: url) }
                    }
                } header: {
                    Text("Pour aller plus loin")
                } footer: {
                    Text(guide.note)
                }
            }
        }
        .navigationTitle("Guide")
    }
}

struct GuideContent: Decodable {
    struct Section: Decodable { let title: String; let items: [String] }
    struct Link: Decodable { let label: String; let url: String }
    let sections: [Section]
    let links: [Link]
    let note: String

    static func load() -> GuideContent? {
        Bundle.main.url(forResource: "guide", withExtension: "json", subdirectory: "Data")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(GuideContent.self, from: $0) }
    }
}

/// Everyday words of the road code, in French and in Hebrew, to read the official texts and the signs.
struct GlossaryView: View {
    struct TermGroup: Decodable { let title: String; let terms: [Term] }
    struct Term: Decodable, Hashable { let fr: String; let he: String }

    @State private var query = ""
    private let groups: [TermGroup] = {
        Bundle.main.url(forResource: "glossary", withExtension: "json", subdirectory: "Data")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode([TermGroup].self, from: $0) } ?? []
    }()

    var body: some View {
        let n = query.trimmingCharacters(in: .whitespaces).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        List {
            ForEach(groups, id: \.title) { group in
                let terms = group.terms.filter { n.isEmpty || $0.fr.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).contains(n) || $0.he.contains(n) }
                if !terms.isEmpty {
                    Section(group.title) {
                        ForEach(terms, id: \.self) { term in
                            HStack {
                                Text(term.fr)
                                Spacer(minLength: 12)
                                Text(term.he).font(.title3).environment(\.layoutDirection, .rightToLeft)
                                    .accessibilityLabel("En hébreu : \(term.he)")
                            }
                        }
                    }
                }
            }
            Section {} footer: {
                Text("Traductions indicatives. Le texte officiel de l’examen et de la loi est en hébreu : c’est lui qui fait foi.")
            }
        }
        .navigationTitle("Glossaire")
        .searchable(text: $query, prompt: "Un mot, en français ou en hébreu")
    }
}
