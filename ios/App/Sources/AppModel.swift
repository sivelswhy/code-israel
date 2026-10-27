import CodeIsraelKit
import Foundation
import Observation

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
    private(set) var pool: [Question]

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
