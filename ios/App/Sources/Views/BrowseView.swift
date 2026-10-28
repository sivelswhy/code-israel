import CodeIsraelKit
import SwiftUI

/// Every question of the license with its answer, searchable.
struct BrowseView: View {
    @State private var query = ""
    @State private var category: Category?
    @Environment(AppModel.self) private var app

    private static func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    private var results: [Question] {
        let n = Self.normalize(query.trimmingCharacters(in: .whitespaces))
        return app.pool.filter { q in
            (category == nil || q.cat == category) &&
                (n.isEmpty || q.id.contains(n) || Self.normalize(q.q).contains(n) || q.a.contains { Self.normalize($0).contains(n) })
        }
    }

    @ViewBuilder private func row(_ q: Question) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let s = app.progress.stats[q.id] {
                Circle().fill(s.last ? Color.ringGreen : Color.signRed).frame(width: 8, height: 8).padding(.top, 6)
                    .accessibilityLabel(s.last ? "Réussie" : "Ratée")
            } else {
                Circle().fill(.clear).frame(width: 8, height: 8)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(q.q).lineLimit(3)
                Text("n° \(q.id) · \(q.correct)").font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    private var categoryPicker: some View {
        Picker("Thème", selection: $category) {
            Text("Tout").tag(Category?.none)
            ForEach(Category.allCases, id: \.self) { Text($0.label.components(separatedBy: " ").first!).tag(Category?.some($0)) }
        }
        #if os(macOS)
        .pickerStyle(.menu)
        #else
        .pickerStyle(.segmented)
        #endif
    }

    var body: some View {
        #if os(macOS)
        macBody
        #else
        listBody
        #endif
    }

    #if os(macOS)
    @State private var selected: Question?

    /// On the Mac: the list on the left, the chosen question on the right.
    private var macBody: some View {
        let results = results
        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack { Text("Thème").foregroundStyle(.secondary); categoryPicker.labelsHidden(); Spacer() }.padding(12)
                List(results, selection: $selected) { q in
                    row(q).tag(q)
                }
                .listStyle(.inset)
                Text("\(results.count) résultat(s)").font(.footnote).foregroundStyle(.secondary).padding(8)
            }
            .frame(width: 380)
            Divider()
            Group {
                if let q = selected {
                    QuestionDetail(question: q).id(q.id)
                } else {
                    ContentUnavailableView("Choisissez une question", systemImage: "list.bullet.rectangle", description: Text("Sa réponse, son explication et le texte de loi s’affichent ici."))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.groupedBackground)
        .navigationTitle("Toutes les questions")
        .searchable(text: $query, prompt: "Rechercher un mot ou un numéro")
    }
    #endif

    @ViewBuilder private var listBody: some View {
        let results = results
        List {
            Section {
                categoryPicker
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("\(results.count) résultat(s)")
            }
            ForEach(results) { q in
                NavigationLink(value: q) { row(q) }
            }
        }
        .navigationTitle("Toutes les questions")
        .searchable(text: $query, prompt: "Rechercher un mot ou un numéro")
        .navigationDestination(for: Question.self) { QuestionDetail(question: $0) }
    }
}

struct QuestionDetail: View {
    let question: Question
    @Environment(AppModel.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("n° \(question.id) · \(question.cat.label)").font(.footnote).foregroundStyle(.secondary)
                Text(question.q).font(.title3.weight(.semibold))
                if let img = question.img { QuestionPicture(id: img) }
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(question.a.enumerated()), id: \.offset) { i, a in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: i == question.c ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(i == question.c ? Color.ringGreen : .secondary)
                            AnswerText(question: question, text: a, revealMeaning: true)
                                .foregroundStyle(i == question.c ? .primary : .secondary)
                        }
                    }
                }
                ExplanationView(question: question, startsOpen: true)
                HebrewOriginal(question: question, revealed: true)
            }
            .padding()
        }
        .background(Color.groupedBackground)
        .inlineTitle()
    }
}
