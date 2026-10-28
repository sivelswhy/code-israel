import CodeIsraelKit
import Foundation
import Observation

// Foundation also has a `Progress`: this names the learner's one from CodeIsraelKit.
typealias Progress = CodeIsraelKit.Progress
// On the Mac, the Objective-C runtime also defines a `Category`.
typealias Category = CodeIsraelKit.Category

/// The two ways to use the app: the classic home (practice, exam) or the Parcours (lessons, XP, review).
enum AppMode: String, CaseIterable {
    case classic, journey

    var label: String { self == .classic ? "Classique" : "Parcours" }
}

/// App-wide state: the bundled data and the learner's progress, saved on the device only.
@MainActor
@Observable
final class AppModel {
    let library: Library
    let law: [String: LawExcerpt]
    let signs: [String: Sign]

    private(set) var progress: Progress {
        didSet { save() }
    }

    /// Questions of the selected license.
    private(set) var pool: [Question] {
        didSet { poolByID = nil }
    }

    /// Classic home or Parcours: remembered between launches.
    var mode: AppMode = .classic {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: "appMode") }
    }

    /// Hebrew reading exercises in the lessons: off unless the learner turns them on.
    var hebrewExercises = UserDefaults.standard.bool(forKey: "hebrewExercises") {
        didSet { UserDefaults.standard.set(hebrewExercises, forKey: "hebrewExercises") }
    }

    @ObservationIgnored private var poolByID: [String: Question]?
    @ObservationIgnored private var paths: [License: LearningPath] = [:]

    /// Search index for the assistant, built on first use and per license.
    @ObservationIgnored private var brains: [License: AssistantBrain] = [:]
    @ObservationIgnored private var hebrewBank: [String: Question]?

    private static var dataDirectory: URL { Bundle.main.resourceURL!.appending(path: "Data") }
    private static var progressURL: URL {
        URL.applicationSupportDirectory.appending(path: "progress.json")
    }

    init() {
        let library = try! Library(directory: Self.dataDirectory)
        self.library = library
        law = Dictionary(library.law.map { ($0.ref, $0) }, uniquingKeysWith: { a, _ in a })
        signs = Dictionary(library.signs.map { ($0.n, $0) }, uniquingKeysWith: { a, _ in a })
        let saved = (try? Data(contentsOf: Self.progressURL)).flatMap { try? JSONDecoder().decode(Progress.self, from: $0) }
        progress = saved ?? Progress()
        pool = library.pool(for: (saved ?? Progress()).license)
        mode = AppMode(rawValue: UserDefaults.standard.string(forKey: "appMode") ?? "") ?? .classic
    }

    var license: License {
        get { progress.license }
        set {
            guard newValue != progress.license else { return }
            progress.license = newValue
            pool = library.pool(for: newValue)
        }
    }

    var mastery: Mastery { Mastery(pool: pool, stats: progress.stats) }

    var exams: [ExamRecord] { progress.exams.filter { $0.license == license } }

    func record(_ question: Question, chosen: Int?) {
        progress.record(question.id, ok: chosen == question.c)
    }

    /// Records an answer to an exercise other than the plain multiple choice (true or false, for example).
    func record(_ question: Question, ok: Bool) {
        progress.record(question.id, ok: ok)
    }

    func recordExam(_ questions: [Question], answers: [Int?]) {
        for (q, a) in zip(questions, answers) { progress.record(q.id, ok: a == q.c) }
        let errors = zip(questions, answers).filter { $0.1 != $0.0.c }.count
        progress.addExam(ExamRecord(date: .now, errors: errors, license: license, ids: questions.map(\.id), answers: answers))
    }

    func isFavorite(_ question: Question) -> Bool { progress.favorites.contains(question.id) }

    func toggleFavorite(_ question: Question) { progress.toggleFavorite(question.id) }

    /// The starred questions of the current license.
    var favorites: [Question] { pool.filter { progress.favorites.contains($0.id) } }

    /// Questions and answers of a saved exam, or nil when it cannot be rebuilt faithfully.
    func review(_ exam: ExamRecord) -> (questions: [Question], answers: [Int?])? {
        guard exam.canReview, let ids = exam.ids, let answers = exam.answers else { return nil }
        let byId = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })
        let questions = ids.compactMap { byId[$0] }
        return questions.count == ids.count ? (questions, answers) : nil
    }

    // MARK: Parcours

    /// The lessons of the selected license.
    var path: LearningPath {
        if let cached = paths[license] { return cached }
        let built = LearningPath(pool: pool)
        paths[license] = built
        return built
    }

    func questions(_ ids: [String]) -> [Question] {
        let byId = poolByID ?? Dictionary(pool.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        poolByID = byId
        return ids.compactMap { byId[$0] }
    }

    /// A short rule taken from the official explanations, told by the characters of the Parcours.
    func tip() -> String {
        let candidates = pool.compactMap(\.e).filter { (40...170).contains($0.count) }
        guard let e = candidates.randomElement() else { return "Gardez toujours vos distances de sécurité !" }
        return "Le saviez-vous ? " + e
    }

    // MARK: Preparation

    /// How ready the learner is for the exam, estimated from their answers.
    var readiness: Readiness { Preparation.readiness(pool: pool, stats: progress.stats) }

    var examPlan: ExamPlan? { Preparation.plan(examDate: progress.examDate, pool: pool, stats: progress.stats) }

    func setExamDate(_ date: Date?) { progress.examDate = date.map { Progress.day($0) } }

    /// Questions the learner keeps getting wrong, the worst first.
    var trapQuestions: [Question] { questions(Preparation.trapIDs(pool: pool, stats: progress.stats)) }

    /// The questions of a theme the learner is least likely to answer right, for the exercise "work on a weak theme".
    func weakest(in category: Category, count: Int = ExamRules.practiceSize) -> [Question] {
        pool.filter { $0.cat == category }
            .sorted { (Preparation.chance(progress.stats[$0.id]), $0.id) < (Preparation.chance(progress.stats[$1.id]), $1.id) }
            .prefix(count).map { $0 }
    }

    var examPassStreak: Int { Preparation.passStreak(exams) }

    /// XP of a finished sign quiz (one per right answer). It counts as practice today, so that it keeps the streak alive.
    func finishSignQuiz(correct: Int) {
        progress.journey.add(xp: correct)
        progress.daily[Progress.day(.now), default: 0] += 1
        Reminders.refresh(self)
    }

    /// Questions whose review is due today.
    var dueReview: [Question] { questions(progress.journey.dueQuestionIDs()) }

    /// Saves a finished lesson (or review, when `lesson` is nil). The answers were recorded one by one as they were given.
    @discardableResult
    func finishJourney(lesson: Lesson?, session: LessonSession, review: Bool = true) -> SessionOutcome {
        let outcome = session.outcome(bonus: lesson != nil)
        progress.journey.finish(lesson: lesson, outcome: outcome, countsAsReview: review)
        Reminders.refresh(self)
        return outcome
    }

    /// Streak freezes spent on the days missed, until the learner has been told.
    var freezeNotice = 0

    /// To call at launch and whenever the app comes back: spends streak freezes if a day was missed, and plans the reminders.
    func refreshJourney() {
        let used = progress.applyStreakFreezes()
        if used > 0 { freezeNotice = used }
        Reminders.refresh(self)
    }

    /// The questions of the adaptive training: the ones the learner has about 8 chances in 10 to get right.
    var adaptiveQuestions: [Question] {
        questions(progress.journey.adaptivePick(from: pool.map(\.id)))
    }

    func claim(_ quest: QuestKind) -> Bool { progress.journey.claim(quest) }

    func openChest() -> ChestReward? { progress.journey.openChest() }

    /// The pairs of one round of the sign matching game.
    func matchRound(seed: Int) -> [Sign] { ExercisePlanner.matchPairs(signs: library.signs, seed: seed) }

    /// XP of a finished matching round. It also counts as practice today, so that it keeps the streak alive.
    func finishMatch() {
        progress.journey.add(xp: JourneyRules.xpMatch)
        progress.daily[Progress.day(.now), default: 0] += 1
        Reminders.refresh(self)
    }

    func resetProgress() {
        let license = progress.license
        progress = Progress()
        progress.license = license
    }

    var brain: AssistantBrain {
        if let b = brains[license] { return b }
        let b = AssistantBrain(pool: pool, law: library.law, signs: library.signs)
        brains[license] = b
        return b
    }

    /// The authoritative Hebrew wording of a question, loaded on first request.
    func hebrew(_ id: String) -> Question? {
        if hebrewBank == nil { hebrewBank = (try? Library.hebrew(directory: Self.dataDirectory)) ?? [:] }
        return hebrewBank?[id]
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: Self.progressURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(progress).write(to: Self.progressURL, options: .atomic)
        } catch {
            // Not saved: progress lives for this session only.
        }
    }
}
