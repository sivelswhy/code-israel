import Foundation

/// The bundled data: question banks, law excerpts and road signs.
public struct Library: Sendable {
    public let questions: [Question]
    public let law: [LawExcerpt]
    public let signs: [Sign]

    public init(questions: [Question], law: [LawExcerpt], signs: [Sign]) {
        self.questions = questions
        self.law = law
        self.signs = signs
    }

    /// Loads `questions.fr.json`, `law.json` and `signs.json` from `directory`.
    public init(directory: URL) throws {
        let decoder = JSONDecoder()
        questions = try decoder.decode([Question].self, from: Data(contentsOf: directory.appending(path: "questions.fr.json")))
        law = try decoder.decode([LawExcerpt].self, from: Data(contentsOf: directory.appending(path: "law.json")))
        signs = try decoder.decode([Sign].self, from: Data(contentsOf: directory.appending(path: "signs.json")))
    }

    /// Questions of the license.
    public func pool(for license: License) -> [Question] {
        questions.filter { $0.lic.contains(license.rawValue) }
    }

    /// The authoritative Hebrew bank, loaded only when the learner asks for the original text.
    public static func hebrew(directory: URL) throws -> [String: Question] {
        let all = try JSONDecoder().decode([Question].self, from: Data(contentsOf: directory.appending(path: "questions.he.json")))
        return Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }
}

extension Question {
    /// The sign number an answer consists of (e.g. "432"), when the question is about signs.
    public func sign(inAnswer answer: String, signs: [String: Sign]) -> String? {
        guard aboutSigns, let n = signAnswer.matches(in: answer, group: 1).first, signs[n] != nil else { return nil }
        return n
    }

    /// Every sign number cited in the question or its answers.
    public func citedSigns(_ signs: [String: Sign]) -> [String] {
        guard aboutSigns else { return [] }
        return citedSignNumbersAll(([q] + a).joined(separator: " "), signs: signs)
    }

    var aboutSigns: Bool {
        cat == .signs || ["panneau", "תמרור", "signalisation", "marquage"].contains { q.localizedCaseInsensitiveContains($0) }
    }
}

private let signAnswer = Pattern(#"^\s*(\d{3}פ?)\s*\.?\s*$"#)
private let anySignNumber = Pattern(#"(?<![\d,.])(\d{3}פ?)(?![\d,.]|\s?(?:km|kg|m\b|mètres|%))"#)

func citedSignNumbersAll(_ text: String, signs: [String: Sign]) -> [String] {
    anySignNumber.matches(in: text, group: 1).uniqued().filter { signs[$0] != nil }
}
