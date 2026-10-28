import CodeIsraelKit
import SwiftUI

/// One lesson of the Parcours, or a review: answer, check, see why, continue. A wrong question comes back at
/// the end of the lesson until it is answered right.
struct LessonView: View {
    let title: String
    /// Nil for a review, which belongs to no lesson.
    let lesson: Lesson?
    let questions: [Question]
    let close: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session: LessonSession
    /// Answer order of each question, shuffled once.
    @State private var orders: [String: [Int]]
    @State private var chosen: Int?
    @State private var checked = false
    @State private var confirmQuit = false
    @State private var outcome: SessionOutcome?
    /// For the speed bonus: when the current question appeared, and how long the answer took.
    @State private var shownAt = Date()
    @State private var seconds = 0.0
    /// A listening exercise hides the question until the learner asks to read it.
    @State private var textShown = false
    /// False for a free training: it counts as no daily review.
    let isReview: Bool
    /// `-lessonDemo feedback-right | feedback-wrong | complete` on the command line shows that state without
    /// saving anything: handy to check the screens.
    private let demo = UserDefaults.standard.string(forKey: "lessonDemo")

    init(title: String, lesson: Lesson?, questions: [Question], isReview: Bool = true, close: @escaping () -> Void) {
        self.title = title
        self.isReview = isReview
        self.lesson = lesson
        self.questions = questions
        self.close = close
        _session = State(initialValue: LessonSession(questionIDs: questions.map(\.id)))
        _orders = State(initialValue: Dictionary(uniqueKeysWithValues: questions.map { ($0.id, Array($0.a.indices).shuffled()) }))
    }

    private var question: Question? { session.current.flatMap { id in questions.first { $0.id == id } } }
    private var right: Bool { question.map { chosen == correctIndex($0) } ?? false }

    // MARK: Exercise kinds

    private var position: Int { question.flatMap { q in questions.firstIndex { $0.id == q.id } } ?? 0 }

    /// How the current question is asked: the plain choice, true or false, listening, or Hebrew to French.
    private var kind: ExerciseKind {
        guard let q = question else { return .choice }
        return ExercisePlanner.kind(position: position, firstAttempt: session.isFirstAttempt, hasHebrew: app.hebrew(q.id) != nil)
    }

    private func translations(_ q: Question) -> (options: [String], correct: Int) { ExercisePlanner.translations(for: q, in: app.pool) }

    /// Index of the right choice among the buttons shown.
    private func correctIndex(_ q: Question) -> Int {
        switch kind {
        case .trueFalse: ExercisePlanner.statement(for: q).isTrue ? 0 : 1
        case .hebrew: translations(q).correct
        case .choice, .listening: q.c
        }
    }

    private func choiceCount(_ q: Question) -> Int {
        switch kind {
        case .trueFalse: 2
        case .hebrew: translations(q).options.count
        case .choice, .listening: q.a.count
        }
    }

    /// The right answer in words, for the feedback.
    private func correctText(_ q: Question) -> String {
        switch kind {
        case .trueFalse: "\(ExercisePlanner.statement(for: q).isTrue ? "Vrai" : "Faux"). La bonne réponse est : \(q.correct)"
        case .hebrew: translations(q).options[translations(q).correct]
        case .choice, .listening: q.correct
        }
    }

    var body: some View {
        Group {
            if let outcome {
                LessonComplete(title: lesson == nil ? "Révision terminée !" : "Leçon terminée !", outcome: outcome, close: close)
            } else if let question {
                lessonBody(question)
            }
        }
        .background(Color.groupedBackground)
        .onAppear { runDemo() }
        .confirmationDialog("Quitter la leçon ?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Quitter", role: .destructive) { close() }
            Button("Continuer la leçon", role: .cancel) {}
        } message: {
            Text("Votre avancée dans cette leçon ne sera pas enregistrée, mais les réponses déjà données comptent dans vos statistiques.")
        }
    }

    private func lessonBody(_ q: Question) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { confirmQuit = true } label: { Image(systemName: "xmark").font(.headline).foregroundStyle(.secondary).frame(width: 32, height: 32) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Quitter la leçon")
                    .keyboardShortcut(.cancelAction)
                ProgressBar(value: session.progress, color: lesson?.category.color ?? .ringBlue)
                SoundToggle()
            }
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if session.queue.count == questions.count && session.mistakes == 0 && !checked {
                        TalkingMascot(mascot: .rouli, mood: .happy, size: 72, message: "C’est parti ! \(questions.count) questions.")
                    }
                    HStack {
                        Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                        Spacer()
                        Label(kindLabel, systemImage: kindIcon).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    questionHeader(q)
                    if let img = q.img { QuestionPicture(id: img) }
                    VStack(spacing: 10) {
                        ForEach(0..<choiceCount(q), id: \.self) { n in
                            let ai = answerIndex(n, q)
                            AnswerButton(letter: letter(n), question: q, text: choiceText(ai, q), state: state(of: ai, in: q)) {
                                guard !checked else { return }
                                chosen = ai
                                Sound.tap.play()
                            }
                            // On a keyboard, 1 to 4 pick an answer.
                            .keyboardShortcut(KeyEquivalent(Character("\(n + 1)")), modifiers: [])
                        }
                    }
                    .disabled(checked)
                }
                .padding(20)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }

            bottom(q)
        }
    }

    private var kindLabel: String {
        switch kind {
        case .choice: "Choix"
        case .trueFalse: "Vrai ou faux"
        case .listening: "Écoute"
        case .hebrew: "Hébreu"
        }
    }

    private var kindIcon: String {
        switch kind {
        case .choice: "list.bullet"
        case .trueFalse: "checkmark.circle"
        case .listening: "ear"
        case .hebrew: "character.book.closed"
        }
    }

    /// The order of the buttons: the shuffled answers for a choice, fixed for true or false and Hebrew.
    private func answerIndex(_ n: Int, _ q: Question) -> Int {
        switch kind {
        case .choice, .listening: (orders[q.id] ?? Array(q.a.indices))[n]
        case .trueFalse, .hebrew: n
        }
    }

    private func letter(_ n: Int) -> String {
        kind == .trueFalse ? ["V", "F"][n] : ["A", "B", "C", "D"][n]
    }

    private func choiceText(_ ai: Int, _ q: Question) -> String {
        switch kind {
        case .choice, .listening: q.a[ai]
        case .trueFalse: ai == 0 ? "Vrai" : "Faux"
        case .hebrew: translations(q).options[ai]
        }
    }

    @ViewBuilder private func questionHeader(_ q: Question) -> some View {
        switch kind {
        case .choice:
            Text(q.q).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
        case .trueFalse:
            let st = ExercisePlanner.statement(for: q)
            Text("Vrai ou faux ?").font(.title2.weight(.bold))
            Text(q.q).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Réponse proposée").font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                Text(q.a[st.answerIndex]).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            }
            .card()
        case .listening:
            Text("Écoutez la question").font(.title2.weight(.bold))
            HStack(spacing: 12) {
                Button { Speech.say(q.q) } label: { Label("Écouter", systemImage: "speaker.wave.3.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                if !textShown {
                    Button("Lire le texte") { withAnimation { textShown = true } }.buttonStyle(.bordered).controlSize(.large)
                }
            }
            if textShown || checked { Text(q.q).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true).transition(.opacity) }
        case .hebrew:
            Text("Que dit cette question ?").font(.title2.weight(.bold))
            if let he = app.hebrew(q.id) {
                Text(he.q).font(.title3.weight(.semibold)).environment(\.layoutDirection, .rightToLeft)
                    .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true).card()
            }
        }
    }

    private func runDemo() {
        guard let demo, let q = question, !checked, outcome == nil else { return }
        switch demo {
        case "feedback-right":
            chosen = correctIndex(q)
            check(q)
        case "feedback-wrong":
            chosen = (correctIndex(q) + 1) % choiceCount(q)
            check(q)
        case let d where d.hasPrefix("skip-"):
            // `skip-2` plays the first two questions right, to see the exercise that comes next.
            for _ in 0..<(Int(d.dropFirst(5)) ?? 0) { session.submit(correct: true) }
        case "complete":
            var done = session
            var first = true
            while !done.isFinished { done.submit(correct: !first || questions.count < 3); first = false }
            outcome = done.outcome()
        default: break
        }
    }

    private func state(of ai: Int, in q: Question) -> AnswerButton.State {
        if checked { return ai == correctIndex(q) ? .correct : ai == chosen ? .wrong : .dimmed }
        return ai == chosen ? .selected : .normal
    }

    @ViewBuilder private func bottom(_ q: Question) -> some View {
        if checked {
            let tint: Color = right ? .ringGreen : .signRed
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 14) {
                    // Rouli is delighted by a right answer at the first try, Stoppy is sorry for a wrong one.
                    MascotView(mascot: right ? .rouli : .stoppy, mood: right ? (session.isFirstAttempt ? .cheer : .happy) : .sad, size: 76)
                    Label(right ? Self.praise(for: q.id) : "Pas tout à fait", systemImage: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title2.weight(.bold)).foregroundStyle(tint)
                }
                if !right { Text("Bonne réponse : \(correctText(q))").font(.subheadline.weight(.semibold)) }
                if let e = q.e { Text(e).font(.subheadline).fixedSize(horizontal: false, vertical: true) }
                if let ref = q.r?.compactMap({ app.law[$0]?.l }).first {
                    Text("Référence : \(ref)").font(.caption).foregroundStyle(.secondary)
                }
                Button { next() } label: { Text(right ? "Continuer" : "Compris").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).tint(tint).controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.14).background(Color.cardBackground))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            Button { check(q) } label: { Text("Vérifier").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(chosen == nil)
                .keyboardShortcut(.defaultAction)
                .padding(20)
                .frame(maxWidth: 680)
        }
    }

    private func check(_ q: Question) {
        // The first answer to a question counts in the statistics, like in the classic mode.
        // A Hebrew exercise tests the reading, not the rule, so it stays out of the statistics.
        if session.isFirstAttempt, demo == nil, kind != .hebrew { app.record(q, ok: right) }
        seconds = Date().timeIntervalSince(shownAt)
        Haptics.answer(right)
        (right ? Sound.right : Sound.wrong).play()
        withAnimation(.spring(duration: 0.4, bounce: 0.25)) { checked = true }
    }

    private func next() {
        let ok = right
        withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
            session.submit(correct: ok, seconds: seconds)
            chosen = nil
            checked = false
            textShown = false
            shownAt = Date()
            Speech.stop()
            if session.isFinished { outcome = app.finishJourney(lesson: lesson, session: session, review: isReview) }
        }
    }

    private static func praise(for id: String) -> String {
        let words = ["Bravo !", "Exact !", "Excellent !", "Bien joué !", "Parfait !"]
        return words[abs(id.hashValue) % words.count]
    }
}

/// A rounded progress bar that fills with a spring.
struct ProgressBar: View {
    let value: Double
    var color: Color = .ringGreen

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule().fill(color)
                    .frame(width: max(14, geo.size.width * value))
                    .animation(.spring(duration: 0.5, bounce: 0.2), value: value)
            }
        }
        .frame(height: 14)
        .accessibilityElement()
        .accessibilityLabel("Avancement")
        .accessibilityValue("\(Int(value * 100)) %")
    }
}

/// The end of a lesson: stars, XP, accuracy.
private struct LessonComplete: View {
    let title: String
    let outcome: SessionOutcome
    let close: () -> Void
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    private var cheer: String {
        outcome.perfect ? "Sans faute ! Vous êtes un as du volant !" : outcome.accuracy >= 0.7 ? "Beau travail, continuez comme ça !" : "On y arrive. Je vous reposerai bientôt les questions ratées."
    }

    private var goalReached: Bool { app.progress.journey.xpToday() >= JourneyRules.dailyXP }

    var body: some View {
        ZStack {
            if !reduceMotion { Confetti() }
            VStack(spacing: 26) {
                Spacer()
                HStack(alignment: .bottom, spacing: 18) {
                    TalkingMascot(mascot: .rouli, mood: outcome.accuracy >= 0.7 ? .cheer : .happy, size: 120, message: cheer)
                    if goalReached { TalkingMascot(mascot: .feo, mood: .cheer, size: 72, message: "Objectif du jour atteint !") }
                }
                HStack(spacing: 12) {
                    ForEach(1...3, id: \.self) { n in
                        Image(systemName: n <= outcome.stars ? "star.fill" : "star")
                            .font(.system(size: 54))
                            .foregroundStyle(n <= outcome.stars ? Color.ringOrange : Color.primary.opacity(0.2))
                            .scaleEffect(shown ? 1 : 0.2)
                            .opacity(shown ? 1 : 0)
                            .animation(.spring(duration: 0.55, bounce: 0.5).delay(0.15 * Double(n)), value: shown)
                    }
                }
                Text(title).font(.largeTitle.weight(.bold))
                Text(outcome.perfect ? "Sans faute, bravo !" : "Les questions ratées reviendront dans votre révision.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    stat("XP gagnés", "+\(outcome.xp)", .ringOrange)
                    stat("Précision", "\(Int((outcome.accuracy * 100).rounded())) %", .ringGreen)
                    stat("Erreurs", "\(outcome.mistakes)", outcome.mistakes == 0 ? .ringGreen : .signRed)
                }
                if outcome.speedBonus {
                    Label("Bonus de vitesse : +\(JourneyRules.xpSpeedBonus) XP", systemImage: "bolt.fill")
                        .font(.headline).foregroundStyle(Color.ringOrange)
                }
                if outcome.stars == 3 {
                    Label("Leçon dorée !", systemImage: "trophy.fill").font(.headline).foregroundStyle(Color.gold)
                }
                let days = app.progress.streak()
                if days > 0 {
                    Label("\(days) jour\(days > 1 ? "s" : "") d’affilée", systemImage: "flame.fill")
                        .font(.headline).foregroundStyle(Color.ringOrange)
                }
                Spacer()
                Button(action: close) { Text("Continuer").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(24)
            .frame(maxWidth: 520)
        }
        .onAppear {
            shown = true
            Sound.complete.play()
            for n in 0..<outcome.stars { Sound.star.play(after: 0.9 + 0.35 * Double(n)) }
        }
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.weight(.bold).monospacedDigit()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.4), lineWidth: 1.5))
    }
}

/// A few seconds of confetti.
private struct Confetti: View {
    private struct Piece: Identifiable {
        let id: Int
        let x: Double
        let delay: Double
        let duration: Double
        let size: CGFloat
        let color: Color
        let spin: Double
    }

    private let pieces: [Piece] = (0..<44).map { i in
        Piece(id: i, x: .random(in: 0...1), delay: .random(in: 0...0.8), duration: .random(in: 1.8...3.2), size: .random(in: 7...13),
              color: [Color.ringOrange, .ringGreen, .ringBlue, .signRed][i % 4], spin: .random(in: 180...540))
    }
    @State private var fall = false

    var body: some View {
        GeometryReader { geo in
            ForEach(pieces) { p in
                RoundedRectangle(cornerRadius: 2).fill(p.color)
                    .frame(width: p.size, height: p.size * 1.6)
                    .rotationEffect(.degrees(fall ? p.spin : 0))
                    .position(x: p.x * geo.size.width, y: fall ? geo.size.height + 40 : -40)
                    .opacity(fall ? 0.2 : 1)
                    .animation(.easeIn(duration: p.duration).delay(p.delay), value: fall)
            }
        }
        .allowsHitTesting(false)
        .onAppear { fall = true }
        .accessibilityHidden(true)
    }
}
