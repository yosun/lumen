import SwiftUI
import UIKit

@MainActor
final class ImageAnalysisViewModel: ObservableObject {
    enum Phase: Equatable {
        case ready
        case loadingModel
        case analyzing
        case completed
        case failed(String)

        var statusText: String? {
            switch self {
            case .ready:
                return nil
            case .loadingModel:
                return "Loading offline tutor..."
            case .analyzing:
                return "Lumen is reading the image..."
            case .completed:
                return nil
            case .failed:
                return nil
            }
        }

        var isWorking: Bool {
            switch self {
            case .loadingModel, .analyzing:
                return true
            case .ready, .completed, .failed:
                return false
            }
        }
    }

    let image: UIImage
    let subject: SubjectMode

    @Published var answerStyle: AnswerStyle = .directWithSteps
    @Published var outputLanguage: OutputLanguage = .english
    @Published var customQuestion: String = ""
    @Published private(set) var responseText = ""
    @Published private(set) var elapsedTimeText: String?
    @Published private(set) var phase: Phase = .ready
    @Published private(set) var memoryWarning: String?
    @Published private(set) var diagnosticLog: String = ""

    private let engine: any MultimodalInferenceEngine
    private let modelManager: ModelManager

    init(
        image: UIImage,
        subject: SubjectMode,
        engine: (any MultimodalInferenceEngine)? = nil,
        modelManager: ModelManager = ModelManager()
    ) {
        self.image = image
        self.subject = subject
        self.modelManager = modelManager
        let resolvedEngine = engine ?? GemmaMultimodalEngine(modelManager: modelManager)
        self.engine = resolvedEngine
        if let gemma = resolvedEngine as? GemmaMultimodalEngine {
            gemma.diagnosticHandler = { [weak self] line in
                self?.appendLog(line)
            }
        }
        Task { [weak self] in
            guard let self else { return }
            let warning = await modelManager.deviceMemoryWarning()
            await MainActor.run {
                self.memoryWarning = warning
            }
        }
    }

    /// The full assembled system instruction Lumen will use for the next run.
    /// Surfaced for debug-only display.
    var composedSystemInstruction: String {
        PromptComposer.systemInstruction(
            subject: subject,
            style: answerStyle,
            language: outputLanguage
        )
    }

    func askLumen() async {
        guard !phase.isWorking else { return }

        responseText = ""
        elapsedTimeText = nil
        diagnosticLog = ""
        phase = .loadingModel
        let timing = Timing()

        let userPrompt = PromptComposer.userPrompt(
            subject: subject,
            customQuestion: customQuestion
        )
        let systemPrompt = composedSystemInstruction

        do {
            appendLog("Loading bundled Gemma 4 E2B .litertlm model...")
            try await engine.loadModel()
            appendLog("Configuring \(subject.title) · \(answerStyle.title) · \(outputLanguage.englishName)...")
            try await engine.applySystemInstruction(systemPrompt)

            phase = .analyzing
            appendLog("Running image + text inference...")
            let stream = try await engine.streamResponse(image: image, prompt: userPrompt)
            for try await chunk in stream {
                responseText += chunk
            }

            elapsedTimeText = ElapsedTimeFormatter.string(from: timing.elapsedSeconds)
            phase = .completed
            appendLog("Inference complete in \(elapsedTimeText ?? "?")")
        } catch {
            elapsedTimeText = ElapsedTimeFormatter.string(from: timing.elapsedSeconds)
            phase = .failed(Self.displayMessage(for: error))
            appendLog("FAILED: \(Self.displayMessage(for: error))")
        }
    }

    func resetResponse() {
        responseText = ""
        elapsedTimeText = nil
        diagnosticLog = ""
        phase = .ready
    }

    func applySuggestedPrompt(_ text: String) {
        customQuestion = text
    }

    private func appendLog(_ line: String) {
        if diagnosticLog.isEmpty {
            diagnosticLog = line
        } else {
            diagnosticLog += "\n" + line
        }
    }

    private static func displayMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}
