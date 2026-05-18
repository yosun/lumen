import Foundation
import UIKit

#if canImport(LiteRTLM)
import LiteRTLM
#endif

enum GemmaInferenceError: LocalizedError {
    case runtimeUnavailable
    case modelLoadFailed(String)
    case conversationUnavailable
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            return "LiteRT-LM Swift is not linked with this app target yet. Add the LiteRTLM Swift package and its iOS binary runtime, then rebuild."
        case .modelLoadFailed(let details):
            return "Failed to load the offline model. \(details)"
        case .conversationUnavailable:
            return "The LiteRT-LM conversation was not initialized."
        case .inferenceFailed(let details):
            return "Offline Gemma inference failed. \(details)"
        }
    }
}

@MainActor
final class GemmaMultimodalEngine: MultimodalInferenceEngine {
    private let modelManager: ModelManager
    private var isLoaded = false
    private(set) var loadDiagnostics: [String] = []
    private(set) var activeBackendDescription: String?
    private(set) var visionAvailable: Bool = false

    /// The system instruction currently baked into the live conversation.
    /// `applySystemInstruction(_:)` is a no-op when the same string is passed
    /// twice in a row.
    private(set) var activeSystemInstruction: String = """
    You are Lumen, a private on-device tutor. You run entirely on the user's iPhone — nothing they show you ever leaves the device. Be patient, encouraging, and concise. Answer only from what is visible in the supplied image and the user's prompt; never invent details that are not present. If something is unclear, say so.
    """

    /// Callback invoked with each diagnostic line as the engine attempts to
    /// load. Wired up by the view model so the user can see exactly which
    /// backend combinations failed and why.
    var diagnosticHandler: (@MainActor (String) -> Void)?

    #if canImport(LiteRTLM)
    private var engine: Engine?
    private var conversation: Conversation?
    #endif

    init(modelManager: ModelManager = ModelManager()) {
        self.modelManager = modelManager
    }

    private func emit(_ line: String) {
        loadDiagnostics.append(line)
        diagnosticHandler?(line)
    }

    func loadModel() async throws {
        if isLoaded {
            return
        }

        // Note: device RAM is intentionally NOT validated here. The UI surfaces
        // a non-blocking warning via ImageAnalysisViewModel.memoryWarning so
        // that LiteRT-LM is always given a chance to actually try loading the
        // bundled Gemma 4 E2B model on this hardware.
        let modelURL = try await modelManager.validateModelAvailable()
        let configuration = await modelManager.configuration

        #if canImport(LiteRTLM)
        guard let cacheDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            throw GemmaInferenceError.modelLoadFailed("Could not resolve the Caches directory.")
        }

        // Prepare a writable, dedicated cache subdirectory. LiteRT-LM writes
        // compiled-kernel and weight caches here; if it isn't writable the
        // engine creation silently returns NULL.
        let liteCacheDir = cacheDirectory.appendingPathComponent("LiteRTLM", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: liteCacheDir,
                withIntermediateDirectories: true
            )
        } catch {
            emit("Could not create LiteRT-LM cache dir: \(error.localizedDescription)")
        }

        ExperimentalFlags.optIntoExperimentalAPIs()
        // Disable speculative decoding regardless of configuration here. It is
        // a known cause of `litert_lm_engine_create` returning NULL on Gemma 4
        // E2B unless the model bundle includes a draft model.
        ExperimentalFlags.enableSpeculativeDecoding = false
        ExperimentalFlags.visualTokenBudget = configuration.visualTokenBudget

        emit("Model file: \(modelURL.lastPathComponent)")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: modelURL.path),
           let size = attrs[.size] as? NSNumber {
            let mb = Double(size.int64Value) / 1_048_576.0
            emit(String(format: "Model size on disk: %.0f MB", mb))
        }
        emit("Cache dir: \(liteCacheDir.path)")

        // Probe the file with the lightweight Capabilities loader before
        // committing to a full engine init. If this returns nil, the file is
        // not openable as a LiteRT-LM bundle — engine attempts will all fail.
        let capabilitiesProbe = await StderrCapture.capture {
            if let caps = Capabilities(modelPath: modelURL.path) {
                self.emit("Capabilities probe: model file opened successfully.")
                let speculative = caps.hasSpeculativeDecodingSupport()
                self.emit("Capabilities probe: speculative decoding support = \(speculative)")
            } else {
                self.emit("⚠️ Capabilities probe: LiteRT-LM could NOT open the model file. The .litertlm bundle may be corrupt or built for a different runtime version.")
            }
        }
        if !capabilitiesProbe.isEmpty {
            let trimmed = capabilitiesProbe
                .split(separator: "\n")
                .suffix(8)
                .joined(separator: " | ")
            emit("Native log (probe): \(trimmed)")
        }

        // Sequence of (engine backend, vision backend, maxNumTokens) attempts.
        // Each one is tried until one succeeds. CPU-only is tried before GPU
        // because Gemma 4 E2B GPU support on iOS is fragile and many devices
        // hit `failedToCreateEngine` on GPU but succeed on CPU.
        struct Attempt {
            let label: String
            let backend: Backend
            let vision: Backend?
            let maxTokens: Int
        }

        let attempts: [Attempt] = [
            Attempt(
                label: "CPU + vision CPU, \(configuration.maxNumTokens) tokens",
                backend: .cpu(),
                vision: .cpu(),
                maxTokens: configuration.maxNumTokens
            ),
            Attempt(
                label: "CPU + vision CPU, 2048 tokens",
                backend: .cpu(),
                vision: .cpu(),
                maxTokens: 2048
            ),
            Attempt(
                label: "CPU only (text-only, no vision), 2048 tokens",
                backend: .cpu(),
                vision: nil,
                maxTokens: 2048
            ),
            Attempt(
                label: "GPU + vision GPU, \(configuration.maxNumTokens) tokens",
                backend: .gpu,
                vision: .gpu,
                maxTokens: configuration.maxNumTokens
            )
        ]

        var lastError: Error?

        for attempt in attempts {
            emit("Attempt: \(attempt.label)")
            let stderrText = await StderrCapture.capture {
                do {
                    let engineConfig = try EngineConfig(
                        modelPath: modelURL.path,
                        backend: attempt.backend,
                        visionBackend: attempt.vision,
                        audioBackend: nil,
                        maxNumTokens: attempt.maxTokens,
                        cacheDir: liteCacheDir.path
                    )
                    let loadedEngine = Engine(engineConfig: engineConfig)
                    try await loadedEngine.initialize()

                    let samplerConfig = try SamplerConfig(
                        topK: configuration.topK,
                        topP: configuration.topP,
                        temperature: configuration.temperature
                    )
                    let conversationConfig = ConversationConfig(
                        systemMessage: Message(self.activeSystemInstruction, role: .system),
                        samplerConfig: samplerConfig
                    )
                    let loadedConversation = try await loadedEngine.createConversation(
                        with: conversationConfig
                    )

                    self.engine = loadedEngine
                    self.conversation = loadedConversation
                    self.activeBackendDescription = attempt.label
                    self.visionAvailable = attempt.vision != nil
                    self.isLoaded = true
                    lastError = nil
                } catch {
                    lastError = error
                }
            }

            if !stderrText.isEmpty {
                let trimmed = stderrText
                    .split(separator: "\n")
                    .suffix(8)
                    .joined(separator: " | ")
                emit("Native log: \(trimmed)")
            }

            if isLoaded {
                emit("✅ Engine ready: \(attempt.label)\(visionAvailable ? "" : " (TEXT-ONLY)")")
                return
            }

            if let lastError {
                emit("❌ \(attempt.label) → \(Self.shortDescription(of: lastError))")
            } else {
                emit("❌ \(attempt.label) → unknown failure")
            }
        }

        let summary = lastError.map { Self.shortDescription(of: $0) } ?? "engine creation returned null"
        throw GemmaInferenceError.modelLoadFailed(
            "All backend attempts failed. Last error: \(summary). See runtime log for the native LiteRT-LM diagnostics."
        )
        #else
        _ = modelURL
        _ = configuration
        throw GemmaInferenceError.runtimeUnavailable
        #endif
    }

    private static func shortDescription(of error: Error) -> String {
        if let localized = error as? LocalizedError, let desc = localized.errorDescription {
            return desc
        }
        return String(describing: error)
    }

    /// Recreates the conversation against the existing loaded engine using
    /// the supplied system instruction. No-op if the instruction is unchanged.
    /// The model itself is NOT reloaded — only the conversation is rebuilt,
    /// which is fast.
    func applySystemInstruction(_ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed == activeSystemInstruction && conversation != nil {
            return
        }

        try await loadModel()

        #if canImport(LiteRTLM)
        guard let engine else {
            throw GemmaInferenceError.modelLoadFailed("Engine is not initialized.")
        }
        let configuration = await modelManager.configuration

        let samplerConfig = try SamplerConfig(
            topK: configuration.topK,
            topP: configuration.topP,
            temperature: configuration.temperature
        )
        let conversationConfig = ConversationConfig(
            systemMessage: Message(trimmed, role: .system),
            samplerConfig: samplerConfig
        )
        let newConversation = try await engine.createConversation(with: conversationConfig)
        self.conversation = newConversation
        self.activeSystemInstruction = trimmed
        #else
        _ = trimmed
        throw GemmaInferenceError.runtimeUnavailable
        #endif
    }

    func generateResponse(image: UIImage, prompt: String) async throws -> String {
        let stream = try await streamResponse(image: image, prompt: prompt)
        var response = ""
        for try await chunk in stream {
            response += chunk
        }
        return response
    }

    func streamResponse(
        image: UIImage,
        prompt: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await loadModel()
        let configuration = await modelManager.configuration
        let preparedImage = try ImagePreprocessor.encodedJPEGData(
            from: image,
            maxDimension: configuration.maxImageDimension
        )

        #if canImport(LiteRTLM)
        guard let conversation else {
            throw GemmaInferenceError.conversationUnavailable
        }

        // If the engine loaded only as a text-only backend (no vision), fall
        // back to a text-only prompt that explains the image cannot be
        // processed but still demonstrates Gemma can generate.
        if !visionAvailable {
            let textPrompt = "(Note: vision backend is unavailable on this device, responding from prompt only.) " + prompt
            return AsyncThrowingStream { continuation in
                Task {
                    do {
                        let message = Message(textPrompt)
                        for try await chunk in conversation.sendMessageStream(message) {
                            let text = chunk.toString
                            if !text.isEmpty {
                                continuation.yield(text)
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(
                            throwing: GemmaInferenceError.inferenceFailed(error.localizedDescription)
                        )
                    }
                }
            }
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let message = Message(contents: [
                        .imageData(preparedImage),
                        .text(prompt)
                    ])

                    for try await chunk in conversation.sendMessageStream(message) {
                        let text = chunk.toString
                        if !text.isEmpty {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: GemmaInferenceError.inferenceFailed(error.localizedDescription)
                    )
                }
            }
        }
        #else
        _ = preparedImage
        throw GemmaInferenceError.runtimeUnavailable
        #endif
    }

    func streamTextResponse(
        prompt: String
    ) async throws -> AsyncThrowingStream<String, Error> {
        try await loadModel()

        #if canImport(LiteRTLM)
        guard let conversation else {
            throw GemmaInferenceError.conversationUnavailable
        }

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let message = Message(prompt)
                    for try await chunk in conversation.sendMessageStream(message) {
                        let text = chunk.toString
                        if !text.isEmpty {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(
                        throwing: GemmaInferenceError.inferenceFailed(error.localizedDescription)
                    )
                }
            }
        }
        #else
        _ = prompt
        throw GemmaInferenceError.runtimeUnavailable
        #endif
    }
}

#if canImport(LiteRTLM)
private extension InferenceBackend {
    var liteRTBackend: Backend {
        switch self {
        case .cpu:
            return .cpu()
        case .gpu:
            return .gpu
        }
    }
}
#endif
