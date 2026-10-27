import CodeIsraelKit
import Foundation
import HuggingFace
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Observation
import Tokenizers

/// Qwen3.5 2B running on the iPhone with MLX, for iPhones without Apple Intelligence. Downloaded once
/// from Hugging Face (free), then works offline.
@MainActor
@Observable
final class QwenEngine {
    enum State: Equatable {
        case idle
        case downloading(Double)
        case loading
        case ready
        case failed(String)
    }

    static let configuration = LLMRegistry.qwen3_5_2b_4bit
    static let downloadSize = "1,75 Go"

    private(set) var state: State = .idle
    @ObservationIgnored private var container: ModelContainer?
    @ObservationIgnored private var loading: Task<Void, Never>?

    private static let downloadedKey = "qwen.downloaded"

    /// Whether this iPhone can run the model: MLX needs the GPU (not the simulator) and enough memory.
    static var isSupported: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return ProcessInfo.processInfo.physicalMemory >= 5_500_000_000
        #endif
    }

    /// The model was fully downloaded once: it can be loaded without asking again.
    var wasDownloaded: Bool { UserDefaults.standard.bool(forKey: Self.downloadedKey) }

    func load() {
        guard loading == nil, state != .ready else { return }
        state = wasDownloaded ? .loading : .downloading(0)
        loading = Task {
            do {
                let container = try await #huggingFaceLoadModelContainer(configuration: Self.configuration) { progress in
                    let fraction = progress.fractionCompleted
                    Task { @MainActor [weak self] in
                        guard let self, case .downloading = self.state else { return }
                        self.state = fraction >= 1 ? .loading : .downloading(fraction)
                    }
                }
                self.container = container
                UserDefaults.standard.set(true, forKey: Self.downloadedKey)
                state = .ready
            } catch {
                state = .failed(Self.explain(error))
            }
            loading = nil
        }
    }

    func cancel() {
        loading?.cancel()
        loading = nil
        state = .idle
    }

    /// Streams the cumulative answer text, without any reasoning block.
    func answer(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard let container else {
                continuation.finish(throwing: CancellationError())
                return
            }
            let task = Task {
                do {
                    let session = ChatSession(
                        container,
                        instructions: system,
                        // Small models can loop on a single word; discourage repeats.
                        generateParameters: GenerateParameters(maxTokens: 300, temperature: 0.1, repetitionPenalty: 1.1),
                        // Qwen3.5 would otherwise think aloud before answering.
                        additionalContext: ["enable_thinking": false]
                    )
                    var raw = ""
                    for try await chunk in session.streamResponse(to: prompt) {
                        raw += chunk
                        continuation.yield(visibleAnswer(raw))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func explain(_ error: Error) -> String {
        let message = error.localizedDescription
        if (error as NSError).domain == NSURLErrorDomain {
            return "Le téléchargement a été interrompu (connexion ?). Réessayez : ce qui est déjà reçu est conservé."
        }
        if message.localizedCaseInsensitiveContains("space") || message.localizedCaseInsensitiveContains("disk") {
            return "Espace de stockage insuffisant. Libérez de la place puis réessayez."
        }
        return message
    }
}
