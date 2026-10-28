import Foundation

/// What the app knows about the learner's results, used to personalise the assistant's answers.
public struct LearnerContext: Sendable {
    public let stats: [String: Stat]
    /// The questions of the learner's license.
    public let pool: [Question]

    public init(stats: [String: Stat], pool: [Question]) {
        self.stats = stats
        self.pool = pool
    }
}

/// The category where the learner does worst, if there are enough answers to say and it is below 60 %.
func weakestCategory(_ learner: LearnerContext) -> (cat: Category, percent: Int)? {
    var weakest: (cat: Category, percent: Int)?
    for cat in Category.allCases {
        let qs = learner.pool.filter { $0.cat == cat }
        let ok = qs.reduce(0) { $0 + (learner.stats[$1.id]?.ok ?? 0) }
        let ko = qs.reduce(0) { $0 + (learner.stats[$1.id]?.ko ?? 0) }
        guard ok + ko >= 8 else { continue }
        let percent = Int((Double(ok) / Double(ok + ko) * 100).rounded())
        if percent < 60, weakest == nil || percent < weakest!.percent { weakest = (cat, percent) }
    }
    return weakest
}

/// A short remark about the learner's own results, shown above an answer. It is composed by the app from
/// the saved results, never written by a model, so it cannot invent a figure.
public func personalNote(topic: AssistantTopic?, hits: [Question], learner: LearnerContext) -> String? {
    guard let q = topic?.question ?? hits.first else { return nil }
    var lines: [String] = []
    if topic != nil, let s = learner.stats[q.id] {
        if s.ko >= 2 {
            lines.append("Cette question vous a déjà fait trébucher \(s.ko) fois : prenez le temps de bien retenir la règle.")
        } else if s.ko == 1 && s.ok == 0 {
            lines.append("Vous avez déjà raté cette question une fois.")
        } else if s.ok >= 2 && s.ko == 0 {
            lines.append("Vous réussissez habituellement cette question : cette explication sert à la consolider.")
        }
    }
    if let weak = weakestCategory(learner), weak.cat == q.cat {
        lines.append("Le thème « \(q.cat.label) » est votre point faible pour l’instant (\(weak.percent) % de réussite) : une série d’entraînement dessus vous aiderait.")
    }
    return lines.isEmpty ? nil : lines.joined(separator: " ")
}
