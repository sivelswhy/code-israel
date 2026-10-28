import CodeIsraelKit
import SwiftUI

/// The Parcours: a path of short lessons for each theme, XP, a level, and a daily review of the questions
/// that were missed. A mode of its own: the classic home stays available from the switch at the top.
struct JourneyView: View {
    @Environment(AppModel.self) private var app
    @State private var theme: Category = .rules
    @State private var active: ActiveLesson?

    /// A lesson or review being played.
    struct ActiveLesson: Identifiable {
        let id = UUID()
        let title: String
        let lesson: Lesson?
        let questions: [Question]
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
                pathScroll(unit, journey, width: geo.size.width, wide: false, summaryOnTop: summary(journey, showSwitcher: true))
            }
        }
        .background(Color.groupedBackground)
        .navigationTitle("Parcours")
        #if os(macOS)
        .toolbarBackground(Color.groupedBackground, for: .windowToolbar)
        #endif
        .fullScreenCoverCompat(item: $active) { a in
            LessonView(title: a.title, lesson: a.lesson, questions: a.questions) { active = nil }
                .environment(app)
        }
        .onAppear {
            // `-openLesson 1` on the command line starts that lesson of the first theme: handy to check the screen.
            let n = UserDefaults.standard.integer(forKey: "openLesson")
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
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 16)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .task(id: theme) {
                // Open the path where the learner stopped.
                if let unit, let current = journey.currentLesson(in: unit) {
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
        let guideReach = min(150, half - 50)
        // The guide stands on the side of the path with the most room.
        let side: Double = sin(Double(index) * 0.9) >= 0 ? -1 : 1
        return VStack(spacing: 6) {
            PathNode(color: unit.category.color, number: lesson.number, stars: result?.stars, unlocked: unlocked, current: current) { start(lesson) }
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
        .overlay {
            if current {
                TalkingMascot(mascot: .rouli, mood: .happy, size: half < 160 ? 68 : 84, message: "Prêt ? C’est parti !")
                    .offset(x: side * guideReach, y: -6)
            }
        }
        .offset(x: sin(Double(index) * 0.9) * amplitude)
        .padding(.vertical, 14)
    }

    private func start(_ lesson: Lesson) {
        active = ActiveLesson(title: "\(lesson.category.label) · leçon \(lesson.number)", lesson: lesson, questions: app.questions(lesson.questionIDs))
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
                    .padding(10)
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
            Text("Les questions ratées reviennent après 1 jour, puis 2, 4, 8 et 16 jours si vous les réussissez.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// A lesson on the path: done (with its stars), the one to play now, or locked.
private struct PathNode: View {
    let color: Color
    let number: Int
    let stars: Int?
    let unlocked: Bool
    let current: Bool
    let action: () -> Void
    @State private var pressed = false

    var body: some View {
        let fill = unlocked ? color : Color.gray.opacity(0.45)
        let shade = unlocked ? color.opacity(0.55) : Color.gray.opacity(0.3)
        Button(action: action) {
            ZStack {
                // The darker disc below gives the button its thickness.
                Circle().fill(shade).frame(width: 70, height: 70).offset(y: pressed ? 2 : 6)
                Circle().fill(fill).frame(width: 70, height: 70).offset(y: pressed ? 4 : 0)
                    .overlay {
                        Image(systemName: stars != nil ? "checkmark" : current ? "play.fill" : unlocked ? "star.fill" : "lock.fill")
                            .font(.system(size: 26, weight: .bold)).foregroundStyle(.white).offset(y: pressed ? 4 : 0)
                    }
                if current {
                    Circle().stroke(color.opacity(0.35), lineWidth: 5).frame(width: 86, height: 86)
                }
            }
            .frame(width: 90, height: 84)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in pressed = true }.onEnded { _ in pressed = false })
        .animation(.spring(duration: 0.2), value: pressed)
        .accessibilityLabel(unlocked ? "Leçon \(number)" : "Leçon \(number), verrouillée")
        .accessibilityValue(stars.map { "\($0) étoile\($0 > 1 ? "s" : "")" } ?? (current ? "à faire" : ""))
    }
}
