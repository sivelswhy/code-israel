import CodeIsraelKit
import Foundation
import Observation

/// Which model answers, chosen automatically: Apple Intelligence when the device has it, and the search
/// mode (no model) otherwise.
enum Engine: Equatable {
    case apple
    case none
}

/// The model of the app, shared by every conversation.
@MainActor
@Observable
final class AIEngines {
    private(set) var appleStatus = AppleEngine.status

    var current: Engine { appleStatus == .available ? .apple : .none }

    /// Apple Intelligence may have been turned on, or finished preparing, while the app was away.
    func refresh() {
        appleStatus = AppleEngine.status
    }

    func answer(_ engine: Engine, prompt: String) -> AsyncThrowingStream<String, Error> {
        switch engine {
        case .apple: AppleEngine.answer(system: AssistantPrompt.system, prompt: prompt)
        case .none: AsyncThrowingStream { $0.finish() }
        }
    }
}

/// One message of a conversation with the assistant.
struct ChatMessage: Identifiable {
    enum Role { case user, assistant }

    let id = UUID()
    let role: Role
    var text: String
    /// Official questions the answer is based on.
    var sources: [Question] = []
    var streaming = false
    /// Written by a model (rather than composed from the official texts).
    var byModel = false
    /// A remark about the learner's own results, composed by the app.
    var note: String?
}

/// A conversation: the learner's messages and the answers, checked against the official texts.
@MainActor
@Observable
final class Conversation {
    private(set) var messages: [ChatMessage] = []
    @ObservationIgnored private var task: Task<Void, Never>?
    /// What the last answer was based on, for a follow-up ("et ça fait combien en miles ?").
    @ObservationIgnored private var carry: AssistantCarry?

    var isAnswering: Bool { messages.last?.streaming == true }

    func send(_ text: String, brain: AssistantBrain, topic: AssistantTopic?, engines: AIEngines, learner: LearnerContext? = nil) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !isAnswering else { return }
        let previous = messages.last { $0.role == .user }?.text
        let turn = brain.turn(for: clean, previous: previous, topic: topic, learner: learner, carry: carry)
        let engine = engines.current
        let useModel = engine != .none && turn.canUseModel
        messages.append(ChatMessage(role: .user, text: clean))
        messages.append(ChatMessage(role: .assistant, text: useModel ? "" : turn.direct, sources: turn.hits, streaming: useModel, byModel: useModel, note: turn.note))
        guard useModel else {
            // A conversion or a reminder is not new knowledge: only an answer built on sources becomes the next context.
            if !turn.exact, turn.previousAnswer == nil, !turn.hits.isEmpty, !turn.direct.isEmpty {
                carry = AssistantCarry(sourceText: turn.sourceText, hits: turn.hits, answer: turn.direct)
            }
            return
        }

        let stream = engines.answer(engine, prompt: AssistantPrompt.user(question: turn.prompt, sources: turn.sourceText, previousAnswer: turn.previousAnswer))
        task = Task {
            do {
                for try await text in stream {
                    updateLast { $0.text = text }
                }
            } catch {
                // The composed answer below replaces an empty or interrupted one.
            }
            // A small model sometimes invents figures, articles or rules: such an answer is replaced
            // by the one composed from the official texts.
            updateLast {
                if $0.text.isEmpty || !turn.accepts($0.text) {
                    $0.text = turn.direct
                    $0.byModel = false
                } else {
                    $0.text = tidyAnswer($0.text)
                    carry = AssistantCarry(sourceText: turn.sourceText, hits: turn.hits, answer: $0.text)
                }
                $0.streaming = false
            }
        }
    }

    func stop() {
        task?.cancel()
    }

    func clear() {
        task?.cancel()
        carry = nil
        messages = []
    }

    private func updateLast(_ change: (inout ChatMessage) -> Void) {
        guard !messages.isEmpty else { return }
        change(&messages[messages.count - 1])
    }
}
