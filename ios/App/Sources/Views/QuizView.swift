import CodeIsraelKit
import SwiftUI

/// A series from the first question to its results.
struct QuizFlow: View {
    let series: Series
    let start: (Series) -> Void
    @State private var answers: [Int?]?

    var body: some View {
        NavigationStack {
            if let answers {
                ResultsView(series: series, answers: answers, start: start)
            } else {
                QuizView(series: series) { answers = $0 }
            }
        }
    }
}

struct QuizView: View {
    let series: Series
    let finish: ([Int?]) -> Void

    @State private var index = 0
    @State private var answers: [Int?]
    /// Answer order of each question, shuffled once.
    @State private var orders: [[Int]]
    @State private var confirmQuit = false
    @State private var confirmFinish = false
    @State private var end = Date.now.addingTimeInterval(TimeInterval(ExamRules.minutes * 60))
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    init(series: Series, finish: @escaping ([Int?]) -> Void) {
        self.series = series
        self.finish = finish
        _answers = State(initialValue: series.questions.map { _ in nil })
        _orders = State(initialValue: series.questions.map { Array($0.a.indices).shuffled() })
    }

    private var exam: Bool { series.mode == .exam }
    private var question: Question { series.questions[index] }
    private var chosen: Int? { answers[index] }
    private var revealed: Bool { !exam && chosen != nil }
    private var last: Bool { index == series.questions.count - 1 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ProgressView(value: Double(index + 1), total: Double(series.questions.count))
                        .tint(.accentColor)
                        .id("top")
                    HStack {
                        Text("Question \(index + 1) sur \(series.questions.count) · n° \(question.id)")
                            .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            app.toggleFavorite(question)
                        } label: {
                            Image(systemName: app.isFavorite(question) ? "star.fill" : "star")
                                .foregroundStyle(app.isFavorite(question) ? Color.ringOrange : .secondary)
                        }
                        .accessibilityLabel(app.isFavorite(question) ? "Retirer des favoris" : "Ajouter aux favoris")
                    }
                    Text(question.q).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    if let img = question.img { QuestionPicture(id: img) }

                    VStack(spacing: 10) {
                        ForEach(Array(orders[index].enumerated()), id: \.element) { n, ai in
                            AnswerButton(
                                letter: ["A", "B", "C", "D"][n],
                                question: question,
                                text: question.a[ai],
                                state: state(of: ai)
                            ) { choose(ai) }
                        }
                    }

                    if revealed {
                        ExplanationView(question: question, chosen: chosen, startsOpen: chosen != question.c)
                            .transition(.opacity)
                    }
                    HebrewOriginal(question: question, revealed: revealed)
                }
                .padding()
                .id(index)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .onChange(of: index) { proxy.scrollTo("top", anchor: .top) }
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) { actions }
        .navigationTitle(series.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Quitter") {
                    if answers.contains(where: { $0 != nil }) { confirmQuit = true } else { dismiss() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if exam { ExamTimer(end: end, onTimeout: submit) } else {
                    Text("\(index + 1)/\(series.questions.count)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog("Quitter cette série ?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Quitter", role: .destructive) { dismiss() }
        }
        .alert("Terminer l’examen ?", isPresented: $confirmFinish) {
            Button("Terminer", role: .destructive, action: submit)
            Button("Continuer", role: .cancel) {}
        } message: {
            Text("\(answers.filter { $0 == nil }.count) question(s) sans réponse.")
        }
        .interactiveDismissDisabled()
    }

    private func state(of answer: Int) -> AnswerButton.State {
        if revealed {
            if answer == question.c { return .correct }
            return answer == chosen ? .wrong : .dimmed
        }
        return answer == chosen ? .selected : .normal
    }

    private func choose(_ answer: Int) {
        guard !revealed else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) { answers[index] = answer }
        if !exam {
            app.record(question, chosen: answer)
            Haptics.answer(answer == question.c)
        }
    }

    private func go(_ to: Int) {
        withAnimation(.spring(duration: 0.35, bounce: 0)) { index = to }
    }

    private func submit() {
        if exam { app.recordExam(series.questions, answers: answers) }
        finish(answers)
    }

    @ViewBuilder private var actions: some View {
        VStack(spacing: 10) {
            if exam {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(series.questions.indices, id: \.self) { i in
                                Button("\(i + 1)") { go(i) }
                                    .font(.caption.monospacedDigit().weight(i == index ? .bold : .regular))
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(answers[i] != nil ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill)))
                                    .overlay(Circle().stroke(i == index ? Color.accentColor : .clear, lineWidth: 2))
                                    .buttonStyle(.plain)
                                    .id(i)
                                    .accessibilityLabel("Question \(i + 1)\(answers[i] != nil ? ", répondue" : "")")
                            }
                        }
                        .padding(.horizontal)
                    }
                    .onChange(of: index) { withAnimation { proxy.scrollTo(index, anchor: .center) } }
                }
                HStack {
                    Button("Précédente") { go(index - 1) }
                        .buttonStyle(.bordered).disabled(index == 0)
                    Spacer()
                    if last {
                        Button("Terminer") {
                            if answers.contains(where: { $0 == nil }) { confirmFinish = true } else { submit() }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Suivante") { go(index + 1) }.buttonStyle(.borderedProminent)
                    }
                }
                .controlSize(.large)
                .padding(.horizontal)
            } else {
                Button {
                    if last { submit() } else { go(index + 1) }
                } label: {
                    Text(last ? "Voir le bilan" : "Continuer").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!revealed)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 10)
        .background(.bar)
    }
}

struct AnswerButton: View {
    enum State { case normal, selected, correct, wrong, dimmed }

    let letter: String
    let question: Question
    let text: String
    let state: State
    let action: () -> Void
    @SwiftUI.State private var shake = 0.0

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Text(letter)
                    .font(.subheadline.weight(.bold))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(badge))
                    .foregroundStyle(state == .normal || state == .dimmed ? Color.primary : .white)
                AnswerText(question: question, text: text, revealMeaning: state == .correct || state == .wrong || state == .dimmed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                if state == .correct { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.ringGreen).font(.title3) }
                if state == .wrong { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.signRed).font(.title3) }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(stroke, lineWidth: 2))
            .opacity(state == .dimmed ? 0.55 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .modifier(Shake(amount: shake))
        .scaleEffect(state == .correct ? 1.02 : 1)
        .animation(.spring(duration: 0.4, bounce: 0.4), value: state)
        .onChange(of: state) { _, s in
            if s == .wrong { withAnimation(.linear(duration: 0.4)) { shake += 1 } }
        }
        .accessibilityAddTraits(state == .selected ? .isSelected : [])
        .accessibilityValue(state == .correct ? "Bonne réponse" : state == .wrong ? "Votre réponse, incorrecte" : "")
    }

    private var badge: Color {
        switch state {
        case .normal, .dimmed: Color(.tertiarySystemFill)
        case .selected: .accentColor
        case .correct: .ringGreen
        case .wrong: .signRed
        }
    }

    private var fill: Color {
        switch state {
        case .correct: Color.ringGreen.opacity(0.12)
        case .wrong: Color.signRed.opacity(0.1)
        case .selected: Color.accentColor.opacity(0.1)
        default: Color(.secondarySystemGroupedBackground)
        }
    }

    private var stroke: Color {
        switch state {
        case .correct: .ringGreen
        case .wrong: .signRed
        case .selected: .accentColor
        default: .clear
        }
    }
}

/// iOS-style horizontal shake for a wrong answer.
struct Shake: GeometryEffect {
    var amount: Double
    var animatableData: Double {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 7 * sin(amount * .pi * 4), y: 0))
    }
}

/// Time left in the exam; submits when it runs out.
struct ExamTimer: View {
    let end: Date
    let onTimeout: () -> Void
    @State private var fired = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = max(0, end.timeIntervalSince(context.date))
            Text(String(format: "%d:%02d", Int(left) / 60, Int(left) % 60))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(left < 300 ? Color.signRed : .primary)
                .accessibilityLabel("Temps restant")
                .onChange(of: left == 0) { _, done in
                    if done && !fired {
                        fired = true
                        onTimeout()
                    }
                }
        }
    }
}
