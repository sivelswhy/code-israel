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

    var body: some View {
        let results = results
        List {
            Section {
                Picker("Thème", selection: $category) {
                    Text("Tout").tag(Category?.none)
                    ForEach(Category.allCases, id: \.self) { Text($0.label.components(separatedBy: " ").first!).tag(Category?.some($0)) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("\(results.count) résultat(s)")
            }
            ForEach(results) { q in
                NavigationLink(value: q) {
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
