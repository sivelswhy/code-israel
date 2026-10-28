import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apple Intelligence's on-device model (FoundationModels). Free, private and already on the iPhone:
/// nothing to download. Only `SystemLanguageModel` is used — never Private Cloud Compute, which runs
/// off the device.
enum AppleEngine {
    enum Status: Equatable {
        case available
        /// Apple Intelligence is off in Settings.
        case disabled
        /// Apple is still downloading its model.
        case preparing
        /// iPhone without Apple Intelligence, older iOS, or French not supported.
        case unsupported
    }

    static var status: Status {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return model.supportsLocale(Locale(identifier: "fr_FR")) ? .available : .unsupported
            case .unavailable(.appleIntelligenceNotEnabled):
                return .disabled
            case .unavailable(.modelNotReady):
                return .preparing
            case .unavailable:
                return .unsupported
            }
        }
        #endif
        return .unsupported
    }

    /// Streams the cumulative answer text.
    static func answer(system: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                #if canImport(FoundationModels)
                if #available(iOS 26.0, macOS 26.0, *) {
                    do {
                        let session = LanguageModelSession(instructions: system)
                        let options = GenerationOptions(temperature: 0.1, maximumResponseTokens: 300)
                        for try await snapshot in session.streamResponse(to: prompt, options: options) {
                            continuation.yield(snapshot.content)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                    return
                }
                #endif
                continuation.finish(throwing: CancellationError())
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
