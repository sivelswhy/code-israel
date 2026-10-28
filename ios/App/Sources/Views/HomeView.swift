import CodeIsraelKit
import SwiftUI

struct HomeView: View {
    let start: (Series) -> Void
    @Environment(AppModel.self) private var app
    /// A past exam being reviewed.
    @State private var reviewed: Series?
    @State private var reviewedAnswers: [Int?] = []

    var body: some View {
        Group {
            #if os(macOS)
            HomeDashboard(start: start) { series, answers in
                reviewedAnswers = answers
                reviewed = series
            }
            #else
            listBody
            #endif
        }
        .navigationTitle("Code de la route")
        #if os(macOS)
        .toolbarBackground(Color.groupedBackground, for: .windowToolbar)
        #endif
        .sheet(item: $reviewed) { series in
            NavigationStack {
                ResultsView(series: series, answers: reviewedAnswers) { next in
                    reviewed = nil
                    start(next)
                }
            }
        }
    }

    /// The iPhone home: a grouped list.
    @ViewBuilder private var listBody: some View {
        @Bindable var app = app
        let m = app.mastery
        let today = app.progress.answeredToday()
        let days = app.progress.streak()
        let share = { (n: Int) in m.total > 0 ? Double(n) / Double(m.total) : 0 }

        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Examen théorique · Israël").font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                    Text("\(m.total) questions officielles, expliquées en français avec le texte de loi.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Picker("Permis", selection: $app.license) {
                        ForEach(License.active, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 6)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
            }

            Section {
                HStack(spacing: 20) {
                    Rings(rings: [
                        .init(value: share(m.mastered), color: .ringGreen),
                        .init(value: share(m.seen), color: .ringBlue),
                        .init(value: min(1, Double(today) / Double(ExamRules.dailyGoal)), color: .ringOrange),
                    ])
                    VStack(alignment: .leading, spacing: 8) {
                        RingLegend(title: "Maîtrisées", value: m.mastered, total: m.total, color: .ringGreen)
                        RingLegend(title: "Déjà vues", value: m.seen, total: m.total, color: .ringBlue)
                        RingLegend(title: "Aujourd’hui", value: today, total: ExamRules.dailyGoal, color: .ringOrange)
                    }
                }
                .padding(.vertical, 6)
                if days > 0 {
                    Label("\(days) jour\(days > 1 ? "s" : "") d’affilée", systemImage: "flame.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ringOrange)
                }
            }

            Section {
                Button {
                    start(Series(mode: .exam, title: "Examen blanc", questions: drawExam(app.pool)))
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "stopwatch.fill").font(.title2).foregroundStyle(.white)
                            .frame(width: 48, height: 48).background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Examen blanc").font(.headline).foregroundStyle(.primary)
                            Text("\(ExamRules.size) questions · \(ExamRules.minutes) min · \(ExamRules.maxErrors) erreurs max.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .disabled(app.pool.isEmpty)
                if !app.exams.isEmpty {
                    HStack(spacing: 8) {
                        Text("Derniers examens").font(.footnote).foregroundStyle(.secondary)
                        ForEach(Array(app.exams.suffix(5).reversed().enumerated()), id: \.offset) { _, e in
                            let chip = Text("\(ExamRules.size - e.errors)/\(ExamRules.size)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill((e.passed ? Color.ringGreen : Color.signRed).opacity(0.15)))
                                .foregroundStyle(e.passed ? Color.ringGreen : Color.signRed)
                            if let r = app.review(e) {
                                Button {
                                    reviewedAnswers = r.answers
                                    reviewed = Series(mode: .exam, title: "Examen blanc", questions: r.questions)
                                } label: { chip }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Revoir l’examen du \(e.date.formatted(date: .long, time: .omitted))")
                            } else {
                                chip
                            }
                        }
                    }
                }
            }

            Section("S’entraîner par thème") {
                ForEach(Category.allCases, id: \.self) { cat in
                    let qs = app.pool.filter { $0.cat == cat }
                    let done = qs.filter { app.progress.stats[$0.id]?.last == true }.count
                    Button {
                        start(Series(mode: .practice, title: cat.label, questions: Array(qs.shuffled().prefix(ExamRules.practiceSize))))
                    } label: {
                        HStack(spacing: 14) {
                            ThemeGlyph(category: cat)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cat.label).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                Text(cat.hint).font(.footnote).foregroundStyle(.secondary)
                                ProgressView(value: qs.isEmpty ? 0 : Double(done) / Double(qs.count)).tint(.ringGreen)
                            }
                            Text("\(done)/\(qs.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(qs.isEmpty)
                }
            }

            Section("Réviser") {
                ReviseRow(title: "Mes erreurs", hint: "Les questions ratées à la dernière tentative", icon: "xmark.circle.fill", color: .signRed, count: m.mistakes.count) {
                    start(Series(mode: .practice, title: "Mes erreurs", questions: Array(m.mistakes.shuffled().prefix(ExamRules.practiceSize))))
                }
                ReviseRow(title: "Mes favoris", hint: "Les questions que vous avez marquées d’une étoile", icon: "star.fill", color: .ringOrange, count: app.favorites.count) {
                    start(Series(mode: .practice, title: "Mes favoris", questions: Array(app.favorites.shuffled().prefix(ExamRules.practiceSize))))
                }
                ReviseRow(title: "Jamais vues", hint: "Couvrir toute la banque, petit à petit", icon: "plus.circle.fill", color: .ringBlue, count: m.unseen.count) {
                    start(Series(mode: .practice, title: "Jamais vues", questions: Array(m.unseen.shuffled().prefix(ExamRules.practiceSize))))
                }
            }

            Section {
                NavigationLink {
                    SourcesView()
                } label: {
                    Label("Sources officielles et licence", systemImage: "info.circle")
                }
            } footer: {
                Text("Questions et images : ministère des Transports d’Israël, via data.gov.il (CC BY). Application non officielle.")
            }
        }
    }
}

struct RingLegend: View {
    let title: String
    let value: Int
    let total: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(color)
            (Text("\(value)").font(.title3.weight(.semibold).monospacedDigit()) + Text("/\(total)").font(.footnote).foregroundStyle(.secondary))
        }
        .accessibilityElement(children: .combine)
    }
}

struct ReviseRow: View {
    let title: String
    let hint: String
    let icon: String
    let color: Color
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(hint).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .disabled(count == 0)
    }
}
