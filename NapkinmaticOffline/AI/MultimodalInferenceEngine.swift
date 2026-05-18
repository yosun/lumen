import UIKit

protocol MultimodalInferenceEngine {
    func loadModel() async throws

    /// Replace the system prompt baked into the conversation. The model itself
    /// is not reloaded, just the conversation. Used to switch subject /
    /// answer-style / output-language without reloading 2.4 GB of weights.
    func applySystemInstruction(_ text: String) async throws

    func generateResponse(
        image: UIImage,
        prompt: String
    ) async throws -> String

    func streamResponse(
        image: UIImage,
        prompt: String
    ) async throws -> AsyncThrowingStream<String, Error>

    /// Text-only smoke test. Useful for verifying that the model loaded and can
    /// generate at all, before attempting multimodal (image + text) inference.
    func streamTextResponse(
        prompt: String
    ) async throws -> AsyncThrowingStream<String, Error>
}

extension MultimodalInferenceEngine {
    func applySystemInstruction(_ text: String) async throws {
        // Default: do nothing. Engines that don't support dynamic system
        // prompts can leave this as a no-op.
        _ = text
    }
    func streamResponse(
        image: UIImage,
        prompt: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await generateResponse(image: image, prompt: prompt)
                    continuation.yield(response)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func streamTextResponse(
        prompt: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(
                throwing: NSError(
                    domain: "MultimodalInferenceEngine",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Text-only inference is not implemented for this engine."]
                )
            )
        }
    }
}
