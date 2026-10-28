#if os(macOS)
import CodeIsraelKit
import SwiftUI

/// The Mac home: cards on a grid that fills the window, instead of the iPhone's narrow list.
struct HomeDashboard: View {
    let start: (Series) -> Void
    /// Opens a past exam with the answers given.
    let review: (Series, [Int?]) -> Void
    @Environment(AppModel.self) private var app

    private let columns = [GridItem(.adaptive(minimum: 280), spacing: 14, alignment: .top)]
    /// Four themes: two by two rather than three and one left alone.
    private let themeColumns = [GridItem(.flexible(), spacing: 14, alignment: .top), GridItem(.flexible(), spacing: 14, alignment: .top)]

    var body: some View {
        let m = app.mastery
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(m)
                HStack(alignment: .top, spacing: 14) {
                    progressCard(m)
                    examCard
                }
                .fixedSize(horizontal: false, vertical: true)
                ReadinessCard { cat in start(Series(mode: .practice, title: "Points faibles : \(cat.label)", questions: app.weakest(in: cat))) }
                section("S’entraîner par thème") {
                    LazyVGrid(columns: themeColumns, spacing: 14) {
                        ForEach(Category.allCases, id: \.self) { themeCard($0) }
                    }
                }
                section("Réviser") {
                    LazyVGrid(columns: columns, spacing: 14) {
                        reviseCard("Mes erreurs", "Les questions ratées à la dernière tentative", "xmark.circle.fill", .signRed, m.mistakes)
                        reviseCard("Mes favoris", "Les questions marquées d’une étoile", "star.fill", .ringOrange, app.favorites)
                        reviseCard("Pièges", "Les questions où vous vous trompez le plus souvent", "exclamationmark.triangle.fill", .signRed, app.trapQuestions)
                        reviseCard("Jamais vues", "Couvrir toute la banque, petit à petit", "plus.circle.fill", .ringBlue, m.unseen)
                    }
                }
                footer
            }
            .padding(24)
        }
        .background(Color.groupedBackground)
    }

    private func header(_ m: Mastery) -> some View {
        @Bindable var app = app
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Examen théorique · Israël").font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                Text("\(m.total) questions officielles, expliquées en français avec le texte de loi.")
                    .font(.title3).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                ModeSwitcher().frame(width: 230)
                Picker("Permis", selection: $app.license) {
                    ForEach(License.active, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 230)
            }
        }
    }

    private func progressCard(_ m: Mastery) -> some View {
        let today = app.progress.answeredToday()
        let days = app.progress.streak()
        let share = { (n: Int) in m.total > 0 ? Double(n) / Double(m.total) : 0 }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Ma progression").font(.headline)
            HStack(spacing: 24) {
                Rings(rings: [
                    .init(value: share(m.mastered), color: .ringGreen),
                    .init(value: share(m.seen), color: .ringBlue),
                    .init(value: min(1, Double(today) / Double(ExamRules.dailyGoal)), color: .ringOrange),
                ])
                VStack(alignment: .leading, spacing: 10) {
                    RingLegend(title: "Maîtrisées", value: m.mastered, total: m.total, color: .ringGreen)
                    RingLegend(title: "Déjà vues", value: m.seen, total: m.total, color: .ringBlue)
                    RingLegend(title: "Aujourd’hui", value: today, total: ExamRules.dailyGoal, color: .ringOrange)
                }
            }
            if days > 0 {
                Label("\(days) jour\(days > 1 ? "s" : "") d’affilée", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.ringOrange)
            }
        }
        .card(stretch: true)
    }

    private var examCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                start(Series(mode: .exam, title: "Examen blanc", questions: drawExam(app.pool)))
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "stopwatch.fill").font(.title).foregroundStyle(.white)
                        .frame(width: 56, height: 56).background(RoundedRectangle(cornerRadius: 14).fill(Color.accentColor))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Examen blanc").font(.title2.weight(.semibold)).foregroundStyle(.primary)
                        Text("\(ExamRules.size) questions · \(ExamRules.minutes) min · \(ExamRules.maxErrors) erreurs max.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(app.pool.isEmpty)

            if !app.exams.isEmpty {
                Divider()
                HStack(spacing: 8) {
                    Text("Derniers examens").font(.footnote).foregroundStyle(.secondary)
                    ForEach(Array(app.exams.suffix(5).reversed().enumerated()), id: \.offset) { _, e in
                        examChip(e)
                    }
                }
                Text("Cliquez sur un résultat pour revoir l’examen.").font(.caption).foregroundStyle(.tertiary)
            } else {
                Text("Les conditions de l’examen officiel : 30 questions tirées de la banque, 40 minutes.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card(stretch: true)
    }

    @ViewBuilder private func examChip(_ e: ExamRecord) -> some View {
        let color = e.passed ? Color.ringGreen : Color.signRed
        let chip = Text("\(ExamRules.size - e.errors)/\(ExamRules.size)")
            .font(.caption.monospacedDigit().weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
        if let r = app.review(e) {
            Button { review(Series(mode: .exam, title: "Examen blanc", questions: r.questions), r.answers) } label: { chip }
                .buttonStyle(.plain)
                .accessibilityLabel("Revoir l’examen du \(e.date.formatted(date: .long, time: .omitted))")
        } else {
            chip
        }
    }

    private func themeCard(_ cat: Category) -> some View {
        let qs = app.pool.filter { $0.cat == cat }
        let done = qs.filter { app.progress.stats[$0.id]?.last == true }.count
        return Button {
            start(Series(mode: .practice, title: cat.label, questions: Array(qs.shuffled().prefix(ExamRules.practiceSize))))
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ThemeGlyph(category: cat)
                VStack(alignment: .leading, spacing: 5) {
                    Text(cat.label).font(.headline).foregroundStyle(.primary)
                    Text(cat.hint).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    ProgressView(value: qs.isEmpty ? 0 : Double(done) / Double(qs.count)).tint(.ringGreen)
                    Text("\(done) sur \(qs.count) maîtrisées").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .card()
        }
        .buttonStyle(.plain)
        .disabled(qs.isEmpty)
    }

    private func reviseCard(_ title: String, _ hint: String, _ icon: String, _ color: Color, _ qs: [Question]) -> some View {
        ReviseRow(title: title, hint: hint, icon: icon, color: color, count: qs.count) {
            start(Series(mode: .practice, title: title, questions: Array(qs.shuffled().prefix(ExamRules.practiceSize))))
        }
        .buttonStyle(.plain)
        .card()
        .opacity(qs.isEmpty ? 0.55 : 1)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink { SourcesView() } label: {
                Label("Sources officielles et licence", systemImage: "info.circle")
            }
            Text("Questions et images : ministère des Transports d’Israël, via data.gov.il (CC BY). Application non officielle.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.weight(.semibold))
            content()
        }
    }
}

#endif
