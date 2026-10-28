import CodeIsraelKit
import SwiftUI

/// The Parcours: a path of short lessons for each theme, XP, a level, and a daily review of the questions
/// that were missed. A mode of its own: the classic home stays available from the switch at the top.
struct JourneyView: View {
    @Environment(AppModel.self) private var app
    @State private var theme: Category = .rules
    @State private var active: ActiveLesson?
    @State private var matchSeed: Int?
    @State private var reward: ChestReward?
    @State private var remindersOn = Reminders.isOn
    @State private var sheet: Sheet?
    @State private var signQuiz = false

    /// On a phone, the quests and the reminders open in a sheet instead of crowding the path.
    enum Sheet: String, Identifiable {
        case quests, settings, readiness
        var id: String { rawValue }
    }

    /// A lesson or review being played.
    struct ActiveLesson: Identifiable {
        let id = UUID()
        let title: String
        let lesson: Lesson?
        let questions: [Question]
        var isReview = true
    }

    var body: some View {
        let path = app.path
        let journey = app.progress.journey
        let unit = path.unit(theme) ?? path.units.first
        // The layout follows the room available, not the device: a wide window (Mac, iPad, a browser-sized
        // split view) puts the summary beside the path, a narrow one (iPhone, a small window) puts it on top.
        GeometryReader { geo in
            let wide = geo.size.width >= 760
            if wide {
                HStack(alignment: .top, spacing: 0) {
                    pathScroll(unit, journey, width: geo.size.width - 331, wide: true)
                    Divider()
                    ScrollView { summary(journey, showSwitcher: false).padding(20) }
                        .frame(width: 330)
                }
            } else {
                pathScroll(unit, journey, width: geo.size.width, wide: false, summaryOnTop: compactHeader(journey))
            }
        }
        .background(Color.groupedBackground)
        .navigationTitle("Parcours")
        .toolbar { ToolbarItem(placement: .primaryAction) { SyncButton() } }
        #if os(macOS)
        .toolbarBackground(Color.groupedBackground, for: .windowToolbar)
        #endif
        .fullScreenCoverCompat(item: $active) { a in
            LessonView(title: a.title, lesson: a.lesson, questions: a.questions, isReview: a.isReview) { active = nil }
                .environment(app)
        }
        .fullScreenCoverCompat(item: Binding(get: { matchSeed.map(MatchRound.init) }, set: { matchSeed = $0?.seed })) { round in
            MatchGame(seed: round.seed) { matchSeed = nil }
                .environment(app)
        }
        .sheet(item: $sheet) { which in
            NavigationStack {
                ScrollView {
                    Group {
                        switch which {
                        case .quests: quests(journey)
                        case .readiness: ReadinessCard { startWeak($0) }
                        case .settings: VStack(spacing: 12) { remindersCard; hebrewCard }
                        }
                    }
                    .padding(20)
                }
                .background(Color.groupedBackground)
                .navigationTitle(which == .quests ? "Quêtes du jour" : which == .readiness ? "Préparation" : "Réglages")
                #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { sheet = nil } } }
            }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCoverCompat(isPresented: $signQuiz) { SignQuizView { signQuiz = false }.environment(app) }
        .alert("Coffre ouvert !", isPresented: Binding(get: { reward != nil }, set: { if !$0 { reward = nil } })) {
            Button("Super !") { reward = nil }
        } message: {
            Text(reward.map { "+\($0.xp) XP" + ($0.freeze ? "\nEt un gel de série pour sauver un jour manqué." : "") } ?? "")
        }
        .onAppear {
            // `-openLesson 1` on the command line starts that lesson of the first theme: handy to check the screen.
            let n = UserDefaults.standard.integer(forKey: "openLesson")
            // `-matchGame 1` opens the sign matching game.
            if UserDefaults.standard.bool(forKey: "matchGame") { UserDefaults.standard.removeObject(forKey: "matchGame"); matchSeed = 1 }
            if active == nil, n > 0, let u = path.units.first, u.lessons.indices.contains(n - 1) {
                UserDefaults.standard.removeObject(forKey: "openLesson")
                start(u.lessons[n - 1])
            }
        }
    }

    // MARK: Path

    private func pathScroll(_ unit: JourneyUnit?, _ journey: JourneyProgress, width: Double, wide: Bool, summaryOnTop: (some View)? = Optional<EmptyView>.none) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    if let summaryOnTop { summaryOnTop }
                    if wide { HStack { ModeSwitcher().frame(width: 230); Spacer() } }
                    themePicker
                    if let unit {
                        unitBanner(unit, journey)
                        LazyVStack(spacing: 0) {
                            ForEach(Array(unit.lessons.enumerated()), id: \.element.id) { i, lesson in
                                node(lesson, index: i, unit: unit, journey: journey, half: (min(640, width) - 40) / 2).id(lesson.id)
                            }
                        }
                        .padding(.vertical, 8)
                        .zIndex(1)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .task(id: theme) {
                // Open the path where the learner stopped.
                // The first lessons are already in view below the header: only a long way in is worth a scroll.
                if let unit, let current = journey.currentLesson(in: unit), current.number > 3 {
                    try? await Task.sleep(for: .milliseconds(150))
                    withAnimation { proxy.scrollTo(current.id, anchor: .center) }
                }
            }
        }
    }

    private var themePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Category.allCases, id: \.self) { cat in
                    Button {
                        withAnimation(.spring(duration: 0.35)) { theme = cat }
                    } label: {
                        Label(cat.label.components(separatedBy: " ").first!, systemImage: cat.icon)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Capsule().fill(theme == cat ? cat.color : Color.cardBackground))
                            .foregroundStyle(theme == cat ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(theme == cat ? .isSelected : [])
                }
            }
        }
    }

    private func unitBanner(_ unit: JourneyUnit, _ journey: JourneyProgress) -> some View {
        let done = journey.completedCount(in: unit)
        return VStack(alignment: .leading, spacing: 6) {
            Text(unit.category.label).font(.title2.weight(.bold))
            Text(unit.category.hint).font(.subheadline).opacity(0.9)
            HStack {
                ProgressBar(value: Double(done) / Double(max(1, unit.lessons.count)), color: .white)
                    .tint(.white)
                Text("\(done)/\(unit.lessons.count)").font(.footnote.weight(.semibold).monospacedDigit())
            }
            .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(unit.category.color))
    }

    private func node(_ lesson: Lesson, index: Int, unit: JourneyUnit, journey: JourneyProgress, half: Double) -> some View {
        let result = journey.lessons[lesson.id]
        let unlocked = journey.isUnlocked(lesson, in: unit)
        let current = journey.currentLesson(in: unit) == lesson
        // The zigzag and the guide must stay inside the column, from a 320 pt phone to a wide window.
        let amplitude = min(110, max(24, half - 125))
        // The guide stands on the side of the path with the most room.
        let side: Double = sin(Double(index) * 0.9) >= 0 ? -1 : 1
        let node = VStack(spacing: 6) {
            PathNode(color: unit.category.color, number: lesson.number, stars: result?.stars, gold: result?.isGold ?? false, unlocked: unlocked, current: current) { start(lesson) }
            if let stars = result?.stars {
                HStack(spacing: 2) {
                    ForEach(1...3, id: \.self) { n in
                        Image(systemName: n <= stars ? "star.fill" : "star").font(.caption2)
                            .foregroundStyle(n <= stars ? Color.ringOrange : Color.primary.opacity(0.2))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .offset(x: sin(Double(index) * 0.9) * amplitude)
        // The guide stays on the edge of the row, on the side opposite to the node: it can never leave the screen.
        return ZStack(alignment: side < 0 ? .topLeading : .topTrailing) {
            node
            if current {
                TalkingMascot(mascot: .rouli, mood: .happy, size: half < 160 ? 60 : 84, message: half < 170 ? nil : "Prêt ? C’est parti !", floating: true, bubbleAlignment: side < 0 ? .topLeading : .topTrailing)
                    .frame(maxWidth: half < 160 ? 150 : 200, alignment: side < 0 ? .leading : .trailing)
            }
        }
        // The guide's bubble rises above its row: room is kept for it, so it does not cover what lies over the row.
        .padding(.top, current ? 40 : 14).padding(.bottom, 14)
        // A tip told by the guide may reach over the rows around it: it is drawn above them.
        .zIndex(current ? 1 : 0)
    }

    private func start(_ lesson: Lesson) {
        active = ActiveLesson(title: "\(lesson.category.label) · leçon \(lesson.number)", lesson: lesson, questions: app.questions(lesson.questionIDs))
    }

    private func startWeak(_ category: Category) {
        sheet = nil
        active = ActiveLesson(title: "Points faibles : \(category.label)", lesson: nil, questions: app.weakest(in: category, count: JourneyRules.adaptiveSize), isReview: false)
    }

    private func startTraps() {
        active = ActiveLesson(title: "Pièges", lesson: nil, questions: Array(app.trapQuestions.prefix(JourneyRules.adaptiveSize)), isReview: false)
    }

    private func startReview(_ due: [Question]) {
        active = ActiveLesson(title: "Révision du jour", lesson: nil, questions: Array(due.prefix(JourneyRules.reviewSize)))
    }

    // MARK: Summary

    private func summary(_ journey: JourneyProgress, showSwitcher: Bool) -> some View {
        let due = app.dueReview
        let today = journey.xpToday()
        let days = app.progress.streak()
        return VStack(alignment: .leading, spacing: 14) {
            if showSwitcher { ModeSwitcher() }
            HStack(spacing: 14) {
                Rings(rings: [.init(value: min(1, Double(today) / Double(JourneyRules.dailyXP)), color: .ringOrange)], size: 76, stroke: 11)
                    .overlay(Image(systemName: today >= JourneyRules.dailyXP ? "checkmark" : "bolt.fill").foregroundStyle(Color.ringOrange))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Objectif du jour").font(.headline)
                    Text("\(min(today, JourneyRules.dailyXP)) / \(JourneyRules.dailyXP) XP").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    if days > 0 {
                        Label("\(days) jour\(days > 1 ? "s" : "") d’affilée", systemImage: "flame.fill")
                            .font(.footnote.weight(.semibold)).foregroundStyle(Color.ringOrange)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.trailing, 48)
            .card()
            .overlay(alignment: .topTrailing) {
                // The traffic light shows how the day is going: red, orange, then green once the goal is reached.
                TalkingMascot(mascot: .feo, mood: today >= JourneyRules.dailyXP ? .cheer : today > 0 ? .thinking : .sad, size: 58)
                    // Room above for its jumps (a sixth of its height), so that it stays inside the card.
                    .padding(EdgeInsets(top: 24, leading: 10, bottom: 10, trailing: 10))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Niveau \(journey.level)", systemImage: "trophy.fill").font(.headline).foregroundStyle(Color.ringBlue)
                    Spacer()
                    Text("\(journey.xp) XP").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                }
                ProgressBar(value: Double(journey.xpInLevel) / Double(JourneyRules.xpPerLevel), color: .ringBlue)
                Text("\(JourneyRules.xpPerLevel - journey.xpInLevel) XP avant le niveau \(journey.level + 1)").font(.caption).foregroundStyle(.secondary)
            }
            .card()

            ReadinessCard { startWeak($0) }

            stats(journey, days: days)

            freezeBanner

            quests(journey)

            Button { startReview(due) } label: {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.triangle.2.circlepath").font(.title2).foregroundStyle(.white)
                        .frame(width: 46, height: 46).background(RoundedRectangle(cornerRadius: 12).fill(due.isEmpty ? Color.gray : Color.signRed))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Révision du jour").font(.headline).foregroundStyle(.primary)
                        Text(due.isEmpty ? "Rien à revoir : revenez demain." : "\(due.count) question\(due.count > 1 ? "s" : "") à revoir")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !due.isEmpty { Image(systemName: "chevron.right").foregroundStyle(.tertiary) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(due.isEmpty)
            .card()

            actionCard(icon: "scope", color: .ringBlue, title: "Entraînement adapté",
                       subtitle: "\(JourneyRules.adaptiveSize) questions choisies pour que vous en réussissiez environ \(Int(JourneyRules.targetSuccess * 100)) %.") {
                active = ActiveLesson(title: "Entraînement adapté", lesson: nil, questions: app.adaptiveQuestions, isReview: false)
            }

            actionCard(icon: "exclamationmark.triangle.fill", color: .signRed, title: "Pièges",
                       subtitle: app.trapQuestions.isEmpty ? "Les questions où vous vous trompez le plus apparaîtront ici." : "\(min(app.trapQuestions.count, JourneyRules.adaptiveSize)) questions où vous vous trompez souvent.") {
                startTraps()
            }

            actionCard(icon: "questionmark.square.dashed", color: .ringOrange, title: "Quiz des panneaux",
                       subtitle: "Reconnaissez 10 panneaux : 1 XP par bonne réponse.") {
                signQuiz = true
            }

            actionCard(icon: "square.grid.2x2.fill", color: .ringGreen, title: "Jeu des panneaux",
                       subtitle: "Associez \(JourneyRules.matchPairs) panneaux à leur sens : +\(JourneyRules.xpMatch) XP.") {
                matchSeed = Int.random(in: 0..<10_000)
            }

            remindersCard

            hebrewCard

            Text("Les questions ratées reviennent après 1 jour, puis 2, 4, 8 et 16 jours si vous les réussissez.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

extension JourneyView {
    /// The top of the path on a phone: the goal, the streak and a few shortcuts. Everything else is one tap away.
    fileprivate func compactHeader(_ journey: JourneyProgress) -> some View {
        let today = journey.xpToday()
        let days = app.progress.streak()
        let due = app.dueReview
        let quests = journey.quests()
        let done = quests.filter { journey.isClaimed($0) }.count
        let goal = today >= JourneyRules.dailyXP
        return VStack(spacing: 12) {
            ModeSwitcher()
            HStack(spacing: 12) {
                Rings(rings: [.init(value: min(1, Double(today) / Double(JourneyRules.dailyXP)), color: .ringOrange)], size: 50, stroke: 8)
                    .overlay(Image(systemName: goal ? "checkmark" : "bolt.fill").font(.caption.bold()).foregroundStyle(Color.ringOrange))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Objectif du jour").font(.subheadline.weight(.semibold))
                    Text("\(min(today, JourneyRules.dailyXP)) / \(JourneyRules.dailyXP) XP · niveau \(journey.level)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                miniStat("flame.fill", .ringOrange, days)
                miniStat("snowflake", .ringBlue, journey.freezes)
            }
            .card()
            freezeBanner
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    shortcut("checkmark.seal.fill", "Préparation", .ringGreen) { sheet = .readiness }
                    shortcut("target", "Quêtes \(done)/\(quests.count)", .ringBlue) { sheet = .quests }
                    shortcut("arrow.triangle.2.circlepath", due.isEmpty ? "Révision" : "Révision (\(due.count))", due.isEmpty ? .gray : .signRed) { startReview(due) }.disabled(due.isEmpty)
                    shortcut("scope", "Entraînement", .ringBlue) { active = ActiveLesson(title: "Entraînement adapté", lesson: nil, questions: app.adaptiveQuestions, isReview: false) }
                    shortcut("exclamationmark.triangle.fill", "Pièges", .signRed) { startTraps() }.disabled(app.trapQuestions.isEmpty)
                    shortcut("square.grid.2x2.fill", "Panneaux", .ringGreen) { matchSeed = Int.random(in: 0..<10_000) }
                    shortcut("questionmark.square.dashed", "Quiz panneaux", .ringOrange) { signQuiz = true }
                    shortcut("gearshape.fill", "Réglages", .gray) { sheet = .settings }
                }
            }
        }
    }

    private func miniStat(_ icon: String, _ color: Color, _ value: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).foregroundStyle(color)
            Text("\(value)").font(.subheadline.weight(.bold).monospacedDigit())
        }
    }

    private func shortcut(_ icon: String, _ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(Color.cardBackground))
                .overlay(Capsule().stroke(Color.primary.opacity(0.08)))
                .foregroundStyle(color == .gray ? Color.secondary : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

extension JourneyView {
    /// Streak, freezes in stock and how well the reviewed questions are remembered.
    fileprivate func stats(_ journey: JourneyProgress, days: Int) -> some View {
        let memory = journey.memoryStrength()
        return HStack(spacing: 10) {
            statPill(icon: "flame.fill", color: .ringOrange, value: "\(days)", label: days > 1 ? "jours" : "jour")
            statPill(icon: "snowflake", color: .ringBlue, value: "\(journey.freezes)", label: journey.freezes > 1 ? "gels" : "gel")
            statPill(icon: "brain", color: .ringGreen, value: memory.map { "\(Int(($0 * 100).rounded())) %" } ?? "–", label: "mémoire")
        }
        .accessibilityElement(children: .combine)
    }

    private func statPill(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).foregroundStyle(color)
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.06)))
    }

    /// Tells the learner that a streak freeze saved a missed day.
    @ViewBuilder fileprivate var freezeBanner: some View {
        if app.freezeNotice > 0 {
            HStack(spacing: 10) {
                Image(systemName: "snowflake").foregroundStyle(Color.ringBlue)
                Text(app.freezeNotice > 1 ? "\(app.freezeNotice) gels de série ont sauvé votre série." : "Un gel de série a sauvé votre série hier.")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Button { app.freezeNotice = 0 } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
                    .accessibilityLabel("Fermer")
            }
            .card()
        }
    }

    /// The three quests of the day, and the chest they open.
    fileprivate func quests(_ journey: JourneyProgress) -> some View {
        let list = journey.quests()
        return VStack(alignment: .leading, spacing: 12) {
            Label("Quêtes du jour", systemImage: "target").font(.headline)
            ForEach(list, id: \.self) { quest in
                let done = journey.isDone(quest)
                let claimed = journey.isClaimed(quest)
                HStack(spacing: 12) {
                    Image(systemName: quest.icon).foregroundStyle(.white)
                        .frame(width: 34, height: 34).background(Circle().fill(claimed ? Color.ringGreen : Color.ringBlue))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quest.title).font(.subheadline.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        ProgressBar(value: Double(journey.questProgress(quest)) / Double(quest.target), color: claimed ? .ringGreen : .ringBlue)
                    }
                    if claimed {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.ringGreen)
                    } else if done {
                        Button("+\(JourneyRules.questXP) XP") {
                            if app.claim(quest) { Sound.star.play() }
                        }
                        .buttonStyle(.borderedProminent).tint(.ringOrange).controlSize(.small)
                    } else {
                        Text("\(journey.questProgress(quest))/\(quest.target)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
            Divider()
            HStack(spacing: 12) {
                Image(systemName: journey.today.chestOpened && journey.today.day == Progress.day(.now) ? "shippingbox" : "shippingbox.fill")
                    .font(.title2).foregroundStyle(Color.gold).frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Coffre du jour").font(.subheadline.weight(.semibold))
                    Text(chestHint(journey)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if journey.canOpenChest() {
                    Button("Ouvrir") {
                        if let r = app.openChest() { reward = r; Sound.complete.play() }
                    }
                    .buttonStyle(.borderedProminent).tint(Color.gold).controlSize(.small)
                }
            }
        }
        .card()
    }

    private func chestHint(_ journey: JourneyProgress) -> String {
        if journey.today.day == Progress.day(.now), journey.today.chestOpened { return "Ouvert. Revenez demain !" }
        if journey.canOpenChest() { return "Prêt : +\(JourneyRules.chestXP) XP à gagner." }
        return "Récupérez les 3 quêtes pour l’ouvrir."
    }

    fileprivate func actionCard(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).foregroundStyle(.white)
                    .frame(width: 46, height: 46).background(RoundedRectangle(cornerRadius: 12).fill(color))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .card()
    }

    /// The Hebrew reading exercises are an option: they are never forced on the learner.
    fileprivate var hebrewCard: some View {
        Toggle(isOn: Binding(get: { app.hebrewExercises }, set: { app.hebrewExercises = $0 })) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Exercices en hébreu", systemImage: "character.book.closed").font(.headline)
                Text("Ajoute de temps en temps un texte hébreu de l’examen à retrouver en français. Désactivé par défaut.")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    fileprivate var remindersCard: some View {
        Toggle(isOn: Binding(get: { remindersOn }, set: { on in
            Task { remindersOn = await Reminders.setOn(on, app: app) }
        })) {
            VStack(alignment: .leading, spacing: 2) {
                Label("Rappels", systemImage: "bell.fill").font(.headline)
                Text("Un rappel à \(Reminders.hour(app)) h, l’heure où vous étudiez d’habitude, et une alerte le soir si votre série est en danger.")
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }
}

private struct MatchRound: Identifiable {
    let seed: Int
    var id: Int { seed }
}

/// A lesson on the path: done (with its stars), the one to play now, or locked.
private struct PathNode: View {
    let color: Color
    let number: Int
    let stars: Int?
    let gold: Bool
    let unlocked: Bool
    let current: Bool
    let action: () -> Void
    var body: some View {
        let base = gold ? Color.gold : color
        let fill = unlocked ? base : Color.gray.opacity(0.45)
        let shade = unlocked ? base.opacity(0.55) : Color.gray.opacity(0.3)
        Button(action: action) {
            Color.clear.frame(width: 90, height: 84)
        }
        .buttonStyle(NodeStyle(fill: fill, shade: shade, base: base, icon: gold ? "trophy.fill" : stars != nil ? "checkmark" : current ? "play.fill" : unlocked ? "star.fill" : "lock.fill", current: current))
        .disabled(!unlocked)
        .accessibilityLabel(unlocked ? "Leçon \(number)" : "Leçon \(number), verrouillée")
        .accessibilityValue(stars.map { "\($0) étoile\($0 > 1 ? "s" : "")" + (gold ? ", dorée" : "") } ?? (current ? "à faire" : ""))
    }
}

/// The 3D look of a lesson button. A button style follows the press by itself, so a drag on the node still scrolls the path.
private struct NodeStyle: ButtonStyle {
    let fill: Color
    let shade: Color
    let base: Color
    let icon: String
    let current: Bool

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        ZStack {
            // The darker disc below gives the button its thickness.
            Circle().fill(shade).frame(width: 70, height: 70).offset(y: pressed ? 2 : 6)
            Circle().fill(fill).frame(width: 70, height: 70).offset(y: pressed ? 4 : 0)
                .overlay {
                    Image(systemName: icon).font(.system(size: 26, weight: .bold)).foregroundStyle(.white).offset(y: pressed ? 4 : 0)
                }
            if current {
                Circle().stroke(base.opacity(0.35), lineWidth: 5).frame(width: 86, height: 86)
            }
        }
        .frame(width: 90, height: 84)
        .contentShape(Circle())
        .animation(.spring(duration: 0.2), value: pressed)
    }
}
