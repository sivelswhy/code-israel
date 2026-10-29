import Charts
import CodeIsraelKit
import SwiftUI

/// "Am I ready?": the estimated chance of passing a mock exam, the weakest themes, the exam date and the history of mock exams.
/// An estimate from the learner's answers, never a promise.
struct ReadinessCard: View {
    /// Starts a new series from the history of exams ("Nouvel examen"). Nil where no series can be started.
    var startSeries: ((Series) -> Void)?
    /// Starts a series on a weak theme.
    let practice: (Category) -> Void
    @Environment(AppModel.self) private var app
    @State private var editingDate = false

    var body: some View {
        let r = app.readiness
        VStack(alignment: .leading, spacing: 14) {
            Text("Préparation à l’examen").font(.headline)
            HStack(spacing: 16) {
                gauge(r)
                VStack(alignment: .leading, spacing: 4) {
                    Text(verdict(r)).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    Text(detail(r)).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)

            if r.enoughData {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(r.weakest.prefix(2), id: \.category) { t in
                        Button { practice(t.category) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: t.category.icon).foregroundStyle(t.category.color).frame(width: 22)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(t.category.label).font(.footnote.weight(.semibold)).foregroundStyle(.primary)
                                    ProgressView(value: t.chance).tint(t.category.color)
                                }
                                Text("\(percent(t.chance))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Travailler \(t.category.label), réussite estimée \(percent(t.chance))")
                    }
                }
            }

            let streak = app.examPassStreak
            Label(streak == 0 ? "Réussissez 3 examens blancs de suite avant le jour J." : "\(streak) examen\(streak > 1 ? "s" : "") blanc\(streak > 1 ? "s" : "") réussi\(streak > 1 ? "s" : "") d’affilée · visez 3",
                  systemImage: streak >= 3 ? "checkmark.seal.fill" : "flag.checkered")
                .font(.footnote).foregroundStyle(streak >= 3 ? Color.ringGreen : .secondary)

            examHistory
            if !app.exams.isEmpty {
                NavigationLink { ExamHistoryView(start: startSeries) } label: {
                    HStack {
                        Label("Mes examens blancs (\(app.exams.count))", systemImage: "list.bullet.rectangle")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .font(.subheadline.weight(.semibold))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Divider()
            examDate
        }
        .card()
        .sheet(isPresented: $editingDate) { ExamDateSheet().environment(app) }
    }

    private func percent(_ p: Double) -> String { "\(min(99, max(0, Int((p * 100).rounded())))) %" }

    private func gauge(_ r: Readiness) -> some View {
        Rings(rings: [.init(value: r.enoughData ? r.passChance : r.coverage, color: r.enoughData ? gaugeColor(r.passChance) : .ringBlue)], size: 84, stroke: 12)
            .overlay {
                Text(r.enoughData ? percent(r.passChance) : "–").font(.headline.monospacedDigit())
            }
    }

    private func gaugeColor(_ p: Double) -> Color { p >= 0.8 ? .ringGreen : p >= 0.5 ? .ringOrange : .signRed }

    private func verdict(_ r: Readiness) -> String {
        guard r.enoughData else { return "Estimation bientôt disponible" }
        return r.passChance >= 0.8 ? "Niveau très bon" : r.passChance >= 0.5 ? "Niveau correct, à consolider" : "Niveau à renforcer"
    }

    private func detail(_ r: Readiness) -> String {
        guard r.enoughData else {
            return "Répondez à des questions : l’estimation apparaît quand \(percent(Preparation.minimumCoverage)) de la banque a été vue (\(percent(r.coverage)) pour l’instant)."
        }
        return "Chance estimée de réussir un examen blanc (\(ExamRules.maxErrors) erreurs au plus). C’est une estimation d’après vos réponses, pas une garantie."
    }

    /// Bars of the last mock exams, with the pass mark.
    @ViewBuilder private var examHistory: some View {
        let exams = Array(app.exams.suffix(10))
        if exams.count >= 2 {
            VStack(alignment: .leading, spacing: 4) {
                Text("Mes derniers examens blancs").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                Chart {
                    ForEach(Array(exams.enumerated()), id: \.offset) { i, e in
                        BarMark(x: .value("Examen", i + 1), y: .value("Bonnes réponses", ExamRules.size - e.errors))
                            .foregroundStyle(e.passed ? Color.ringGreen : Color.signRed)
                    }
                    RuleMark(y: .value("Seuil", ExamRules.size - ExamRules.maxErrors))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(.secondary)
                }
                .chartYScale(domain: 0...ExamRules.size)
                .chartXAxis(.hidden)
                .frame(height: 80)
                .accessibilityLabel("Résultats des derniers examens blancs")
                .accessibilityValue(exams.map { "\(ExamRules.size - $0.errors) sur \(ExamRules.size)" }.joined(separator: ", "))
            }
        }
    }

    @ViewBuilder private var examDate: some View {
        if let plan = app.examPlan {
            VStack(alignment: .leading, spacing: 6) {
                if plan.isPast {
                    Label("La date de votre examen est passée.", systemImage: "calendar.badge.exclamationmark").font(.subheadline.weight(.semibold))
                } else {
                    Label(plan.daysLeft == 0 ? "Votre examen est aujourd’hui. Bon courage !" : "Examen dans \(plan.daysLeft) jour\(plan.daysLeft > 1 ? "s" : "")", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                    Text(plan.toLearn == 0 ? "Tout est acquis : gardez le rythme avec un examen blanc de temps en temps."
                         : "Il reste \(plan.toLearn) question\(plan.toLearn > 1 ? "s" : "") à apprendre ou à consolider : environ \(plan.perDay) par jour.")
                        .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Button("Changer la date") { editingDate = true }.font(.footnote)
            }
        } else {
            Button { editingDate = true } label: { Label("Définir la date de mon examen", systemImage: "calendar.badge.plus") }
                .font(.subheadline.weight(.semibold))
        }
    }
}

/// Picks the date of the exam, or removes it.
struct ExamDateSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date de l’examen", selection: $date, in: Date.now..., displayedComponents: .date)
                    #if !os(macOS)
                    .datePickerStyle(.graphical)
                    #endif
                Text("L’app calcule combien de questions apprendre chaque jour, et le rappel quotidien annonce le compte à rebours.")
                    .font(.footnote).foregroundStyle(.secondary)
                if app.progress.examDate != nil {
                    Button("Retirer la date", role: .destructive) { app.setExamDate(nil); dismiss() }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Mon examen")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Enregistrer") { app.setExamDate(date); dismiss() } }
            }
        }
        .frame(minWidth: 320, minHeight: 320)
        .onAppear {
            if let saved = app.progress.examDate.flatMap({ Self.parse($0) }), saved >= .now { date = saved }
        }
    }

    private static func parse(_ day: String) -> Date? {
        let p = day.split(separator: "-").compactMap { Int($0) }
        return p.count == 3 ? Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2])) : nil
    }
}

/// Opens a pre-filled public issue on GitHub to report a mistake in a question or its translation.
struct ReportLink: View {
    let question: Question

    private var url: URL? {
        var c = URLComponents(string: "https://github.com/sivelswhy/code-israel/issues/new")
        c?.queryItems = [
            URLQueryItem(name: "title", value: "Erreur dans la question \(question.id)"),
            URLQueryItem(name: "body", value: "Question n° \(question.id)\\n\\n> \(question.q)\\n\\nCe qui n’est pas correct (traduction, réponse, explication, image…) :\\n"),
        ]
        return c?.url
    }

    var body: some View {
        if let url {
            Link(destination: url) { Label("Signaler une erreur dans cette question", systemImage: "flag") }
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Every mock exam of the current license, the latest first: a tap shows its questions and the answers given again.
struct ExamHistoryView: View {
    var start: ((Series) -> Void)?
    @Environment(AppModel.self) private var app
    @State private var reviewed: Series?
    @State private var reviewedAnswers: [Int?] = []

    var body: some View {
        let exams = Array(app.exams.reversed())
        let passed = exams.filter(\.passed).count
        let best = exams.map { ExamRules.size - $0.errors }.max() ?? 0
        List {
            Section {
                HStack(spacing: 0) {
                    stat("\(exams.count)", "examen\(exams.count > 1 ? "s" : "")")
                    stat("\(passed)", "réussi\(passed > 1 ? "s" : "")")
                    stat("\(best)/\(ExamRules.size)", "meilleur score")
                }
                .padding(.vertical, 4)
            }
            Section("Du plus récent au plus ancien") {
                ForEach(Array(exams.enumerated()), id: \.offset) { _, e in row(e) }
            }
            if exams.contains(where: { !$0.canReview }) {
                Section {} footer: {
                    Text("Seuls les derniers examens gardent le détail de leurs questions : pour les plus anciens, on ne voit que le score.")
                }
            }
        }
        .navigationTitle("Mes examens blancs")
        .sheet(item: $reviewed) { series in
            NavigationStack {
                ResultsView(series: series, answers: reviewedAnswers) { next in
                    reviewed = nil
                    start?(next)
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { reviewed = nil } } }
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.bold).monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func row(_ e: ExamRecord) -> some View {
        let color = e.passed ? Color.ringGreen : Color.signRed
        let content = HStack(spacing: 12) {
            Text("\(ExamRules.size - e.errors)/\(ExamRules.size)")
                .font(.headline.monospacedDigit())
                .frame(width: 64).padding(.vertical, 6)
                .background(Capsule().fill(color.opacity(0.15))).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.passed ? "Réussi" : "Raté").font(.subheadline.weight(.semibold))
                Text("\(e.errors) erreur\(e.errors > 1 ? "s" : "") · \(e.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        if let r = app.review(e) {
            Button {
                reviewedAnswers = r.answers
                reviewed = Series(mode: .exam, title: "Examen blanc", questions: r.questions)
            } label: {
                HStack { content; Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary) }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Revoir l’examen du \(e.date.formatted(date: .long, time: .shortened)), \(ExamRules.size - e.errors) sur \(ExamRules.size)")
        } else {
            content
        }
    }
}
