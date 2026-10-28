import Foundation

/// The kinds of exercise of a lesson.
public enum ExerciseKind: String, Sendable {
    /// The usual multiple choice question.
    case choice
    /// "True or false?" about one answer of the question.
    case trueFalse
    /// The question is read aloud and its text is hidden until the learner asks.
    case listening
    /// The Hebrew wording of the exam is shown: find its French translation.
    case hebrew
}

public enum ExercisePlanner {
    /// The kind of exercise for the question at `position` of a lesson. Only the first time a question is shown gets a
    /// variety of exercises: a question that comes back after a mistake is always the plain multiple choice.
    public static func kind(position: Int, firstAttempt: Bool, hasHebrew: Bool) -> ExerciseKind {
        guard firstAttempt else { return .choice }
        switch position % 4 {
        case 1: return .trueFalse
        case 2: return .listening
        case 3: return hasHebrew ? .hebrew : .choice
        default: return .choice
        }
    }

    /// For a true/false exercise: the answer shown and whether the statement is true. The same question always
    /// shows the same statement.
    public static func statement(for q: Question) -> (answerIndex: Int, isTrue: Bool) {
        let h = q.id.unicodeScalars.reduce(5) { ($0 &* 31 &+ Int($1.value)) % 10_007 }
        if h % 2 == 0 || q.a.count < 2 { return (q.c, true) }
        let wrong = q.a.indices.filter { $0 != q.c }
        return (wrong[h % wrong.count], false)
    }

    /// For a Hebrew exercise: four French wordings (the right one and three from the same theme), in a fixed order.
    public static func translations(for q: Question, in pool: [Question]) -> (options: [String], correct: Int) {
        func salt(_ s: String) -> Int { s.unicodeScalars.reduce(3) { ($0 &* 31 &+ Int($1.value)) % 10_007 } }
        let others = pool.filter { $0.id != q.id && $0.cat == q.cat && $0.q != q.q && abs($0.q.count - q.q.count) < max(40, q.q.count) }
            .sorted { (salt(q.id + $0.id), $0.id) < (salt(q.id + $1.id), $1.id) }
        // Several questions share the same wording (they differ by their picture): keep each text once.
        var seen: Set<String> = [q.q]
        let distractors = others.map(\.q).filter { seen.insert($0).inserted }.prefix(3)
        var options = Array(distractors) + [q.q]
        options.sort { (salt(q.id + $0), $0) < (salt(q.id + $1), $1) }
        return (options, options.firstIndex(of: q.q)!)
    }

    /// Pairs for the sign matching game: signs of one family, with distinct meanings.
    public static func matchPairs(signs: [Sign], count: Int = JourneyRules.matchPairs, seed: Int) -> [Sign] {
        let usable = signs.filter { $0.asset != nil }
        let families = Dictionary(grouping: usable, by: \.cat).filter { $0.value.count >= count }
        guard let family = families.keys.sorted()[safe: seed % max(1, families.count)] else { return [] }
        var seen = Set<String>()
        let sorted = families[family]!.sorted { $0.n < $1.n }.filter { seen.insert($0.fr).inserted }
        guard sorted.count >= count else { return [] }
        let start = (seed / 7) % (sorted.count - count + 1)
        return Array(sorted[start..<(start + count)])
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
