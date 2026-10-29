import CodeIsraelKit
import SwiftUI

struct ResultsView: View {
    let series: Series
    let answers: [Int?]
    /// Starts the next series. Nil when the results are shown where no series can be started (the Parcours): no button then.
    let start: ((Series) -> Void)?
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    private var wrong: [(question: Question, answer: Int?)] {
        zip(series.questions, answers).filter { $0.1 != $0.0.c }.map { ($0.0, $0.1) }
    }

    var body: some View {
        let score = series.questions.count - wrong.count
        let passed = series.mode == .exam && wrong.count <= ExamRules.maxErrors
        let good = series.mode == .practice || passed

        List {
            Section {
                VStack(spacing: 14) {
                    Text(series.mode == .exam ? "Examen blanc" : "Bilan").font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                    ZStack {
                        Rings(rings: [.init(value: series.questions.isEmpty ? 0 : Double(score) / Double(series.questions.count), color: good ? .ringGreen : .signRed)], size: 150, stroke: 16)
                        (Text("\(score)").font(.system(size: 44, weight: .bold, design: .rounded)) + Text("/\(series.questions.count)").font(.title3).foregroundStyle(.secondary))
                    }
                    Group {
                        if series.mode == .exam {
                            Text(passed
                                ? "Réussi : \(wrong.count) erreur\(wrong.count > 1 ? "s" : ""), la limite est de \(ExamRules.maxErrors)."
                                : "Échoué : \(wrong.count) erreurs, il en faut \(ExamRules.maxErrors) au maximum.")
                                .foregroundStyle(passed ? Color.ringGreen : Color.signRed)
                        } else {
                            Text(wrong.isEmpty ? "Sans faute." : "\(wrong.count) question(s) à revoir ci-dessous.").foregroundStyle(.secondary)
                        }
                    }
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    HStack {
                        Button("Accueil") { dismiss() }.buttonStyle(.bordered)
                        if let start, series.mode == .exam || !wrong.isEmpty {
                            Button(series.mode == .exam ? "Nouvel examen" : "Refaire les erreurs") {
                                let next = series.mode == .exam
                                    ? Series(mode: .exam, title: "Examen blanc", questions: drawExam(app.pool))
                                    : Series(mode: .practice, title: "Questions manquées", questions: wrong.map(\.question))
                                dismiss()
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(450))
                                    start(next)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .sensoryFeedback(good ? .success : .error, trigger: true)
            }

            if !wrong.isEmpty {
                Section("Corrections") {
                    ForEach(wrong, id: \.question.id) { item in
                        VStack(alignment: .leading, spacing: 10) {
                            Text("n° \(item.question.id)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Text(item.question.q).font(.headline)
                            if let img = item.question.img { QuestionPicture(id: img) }
                            if let a = item.answer {
                                Label { Text(item.question.a[a]) } icon: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.signRed) }
                            } else {
                                Label("Sans réponse", systemImage: "questionmark.circle").foregroundStyle(.secondary)
                            }
                            Label { Text(item.question.correct) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.ringGreen) }
                            ExplanationView(question: item.question, chosen: item.answer)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Résultats")
        .inlineTitle()
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
        }
    }
}
