# Design Document: Lumen Vertical

## Overview

Lumen Vertical wires three new pieces of state — `SubjectMode`, `AnswerStyle`, `OutputLanguage` — through a fresh `PromptComposer`, into the existing `ImageAnalysisViewModel`, and onto `GemmaMultimodalEngine`'s LiteRT-LM conversation. The home screen is rebranded to Lumen with a subject grid; a new `AnalysisView` is the per-image working surface, with read-aloud powered by `AVSpeechSynthesizer` through `SpeechSynthesizer`.

Most of the listed files already exist in the workspace and look correct. The design treats each one as an audit target: read it, confirm it satisfies the requirement, and only modify if a real gap is found. The single greenfield file is `Views/AnalysisView.swift`.

The implementation language is Swift / SwiftUI, matching the entire workspace.

## Architecture

```
HomeView                          ── picks SubjectMode + capture path
   │
   ▼
AnalysisView                      ── holds AnswerStyle, OutputLanguage, custom question
   │  (binds to)
   ▼
ImageAnalysisViewModel            ── computes System_Instruction + user prompt
   │  (uses)
   ▼
PromptComposer                    ── pure composer: identity + subject + style + language
   │
   ▼
GemmaMultimodalEngine             ── applySystemInstruction(_:) recreates Conversation
   │                                  without reloading weights
   ▼
LiteRT-LM Engine (Vendor/LiteRTLM)

AnalysisView ── controls ─▶ SpeechSynthesizer
                            ── AVSpeechSynthesizer wrapper, picks voice by
                               OutputLanguage.bcp47
```

Key invariants:

- `PromptComposer` is a pure function of `(SubjectMode, AnswerStyle, OutputLanguage)` — easy to property-test.
- `GemmaMultimodalEngine.applySystemInstruction(_:)` mutates the conversation but never the loaded weights. Idempotent for the same string.
- `SpeechSynthesizer.bestVoice(for:)` is the only piece of speech logic worth pulling out as a pure helper for property testing.

## Components and Interfaces

### `SubjectMode` (NapkinmaticOffline/AI/SubjectMode.swift)

Already implemented in workspace. Audit only. Required surface:

```swift
enum SubjectMode: String, CaseIterable, Identifiable, Codable {
    case universal, math, science, reading, history, language, computerScience, arts
    var id: String { get }
    var title: String { get }
    var subtitle: String { get }
    var systemImage: String { get }
    var accentRGB: (r: Double, g: Double, b: Double) { get }
    var systemInstructionFragment: String { get }
    var suggestedPrompts: [String] { get }   // length >= 3
}
```

Audit checks: 8 cases, every getter returns non-empty values, `suggestedPrompts.count >= 3`.

### `AnswerStyle` (NapkinmaticOffline/AI/AnswerStyle.swift)

Already implemented. Audit only. Required surface:

```swift
enum AnswerStyle: String, CaseIterable, Identifiable, Codable {
    case directWithSteps, socratic, quickAnswer
    var id: String { get }
    var title: String { get }
    var subtitle: String { get }
    var systemImage: String { get }
    var systemInstructionFragment: String { get }
}
```

Audit check: `socratic.systemInstructionFragment` must instruct the model to ask a guiding question and not reveal the final answer.

### `OutputLanguage` (NapkinmaticOffline/AI/OutputLanguage.swift)

Already implemented. Audit only. Required surface:

```swift
enum OutputLanguage: String, CaseIterable, Identifiable, Codable {
    case english, spanish, french, german, portuguese, arabic,
         hindi, chinese, japanese, korean, swahili, vietnamese
    var id: String { get }
    var englishName: String { get }
    var nativeName: String { get }
    var flag: String { get }
    var bcp47: String { get }
    var systemInstructionFragment: String { get }
}
```

Audit checks: 12 cases, all getters non-empty, `bcp47` contains a hyphen, non-english fragments mention the language by name.

### `PromptComposer` (NapkinmaticOffline/AI/PromptComposer.swift)

Already implemented. Audit only. Required surface:

```swift
enum PromptComposer {
    static func systemInstruction(
        subject: SubjectMode,
        style: AnswerStyle,
        language: OutputLanguage
    ) -> String

    static func userPrompt(
        subject: SubjectMode,
        customQuestion: String
    ) -> String
}
```

Audit checks:
- Output of `systemInstruction(...)` contains the static identity preamble and every input fragment as a substring.
- `userPrompt(...)` returns trimmed input when non-empty after trim, otherwise the subject's first suggested prompt.
- No file in `NapkinmaticOffline/` outside `AI/PromptComposer.swift` references a legacy `PromptTemplates` / `PromptTemplate` symbol.

### `SpeechSynthesizer` (NapkinmaticOffline/Utilities/SpeechSynthesizer.swift)

Already implemented. Audit + small refactor. Required surface:

```swift
@MainActor
final class SpeechSynthesizer: NSObject, ObservableObject {
    @Published private(set) var isSpeaking: Bool
    @Published private(set) var isPaused: Bool
    func speak(_ text: String, language: OutputLanguage)
    func pause()
    func resume()
    func stop()

    // Pure helper extracted for property testing:
    static func bestVoice(
        from voices: [AVSpeechSynthesisVoice],
        for language: OutputLanguage
    ) -> AVSpeechSynthesisVoice?
}
```

Refactor: pull the existing `bestVoice(for:)` into a static, dependency-injected pure function that takes the voice list as input. The instance method continues to call it with `AVSpeechSynthesisVoice.speechVoices()`.

### `HomeView` (NapkinmaticOffline/Views/HomeView.swift)

Already implemented. Audit only. Confirms:
- Renders `LumenBrand.appName`, `LumenBrand.tagline`, `LumenBrand.privacyReceipt`.
- Renders `SubjectMode.allCases` in a 2-column grid of `SubjectTile`.
- "Take Photo" → `CameraCaptureView`; "Choose from Library" → `PhotosPicker`.
- Navigates to `AnalysisView(image:subject:onClose:)` with the captured image and selected subject.

Gap to fix: `AnalysisView` is currently referenced but does not exist in the project; build will fail until it lands. (Addressed by the new `AnalysisView` task.)

### `AnalysisView` (NapkinmaticOffline/Views/AnalysisView.swift) — NEW

Greenfield. Owns an `@StateObject ImageAnalysisViewModel` and an `@StateObject SpeechSynthesizer`.

Layout (top-to-bottom):

1. Top bar: Close button (calls `onClose`), Lumen wordmark, subject badge (`subject.title`).
2. Image preview card: rounded image of `viewModel.image`.
3. Privacy receipt strip: `LumenBrand.privacyReceipt`.
4. Controls row 1: Output language picker (Menu) bound to `viewModel.outputLanguage`, listing all 12 cases as `flag nativeName (englishName)`.
5. Controls row 2: Answer-style segmented control bound to `viewModel.answerStyle`.
6. Suggested-prompt chips: horizontal scroll of `subject.suggestedPrompts`, each tap fills `viewModel.customQuestion`.
7. Custom-question text field bound to `viewModel.customQuestion`.
8. Primary action: "Ask Lumen" → `Task { await viewModel.askLumen() }`. Disabled while `viewModel.phase.isWorking`.
9. Output card: streamed `viewModel.responseText`, elapsed time, phase status, optional memory-warning banner.
10. Read-aloud bar: Play / Pause / Resume / Stop bound to the `SpeechSynthesizer`. Play disabled if `viewModel.responseText.isEmpty`. Play calls `speech.speak(viewModel.responseText, language: viewModel.outputLanguage)`. When `viewModel.outputLanguage` changes mid-utterance, do nothing — current speech finishes; new speech uses the new language.

Initialization signature:

```swift
struct AnalysisView: View {
    init(image: UIImage, subject: SubjectMode, onClose: @escaping () -> Void)
}
```

### `ImageAnalysisViewModel` (NapkinmaticOffline/ViewModels/ImageAnalysisViewModel.swift)

Already implemented. Audit only. Required surface (already in place):

```swift
@MainActor
final class ImageAnalysisViewModel: ObservableObject {
    let image: UIImage
    let subject: SubjectMode
    @Published var answerStyle: AnswerStyle
    @Published var outputLanguage: OutputLanguage
    @Published var customQuestion: String
    @Published private(set) var responseText: String
    @Published private(set) var elapsedTimeText: String?
    @Published private(set) var phase: Phase
    @Published private(set) var memoryWarning: String?
    @Published private(set) var diagnosticLog: String

    var composedSystemInstruction: String { get }
    func askLumen() async
    func resetResponse()
    func applySuggestedPrompt(_ text: String)
}
```

Audit checks:
- No reference to legacy `PromptTemplate` / `PromptTemplates`.
- `askLumen()` calls `engine.applySystemInstruction(composedSystemInstruction)` before `engine.streamResponse(image:prompt:)`.
- The user prompt passed to `streamResponse` equals `PromptComposer.userPrompt(subject: subject, customQuestion: customQuestion)`.

### `GemmaMultimodalEngine` (NapkinmaticOffline/AI/GemmaMultimodalEngine.swift)

Already implemented. Audit only. Required surface:

```swift
@MainActor
final class GemmaMultimodalEngine: MultimodalInferenceEngine {
    private(set) var activeSystemInstruction: String
    func loadModel() async throws
    func applySystemInstruction(_ text: String) async throws
    func streamResponse(image: UIImage, prompt: String) async throws -> AsyncThrowingStream<String, Error>
    func streamTextResponse(prompt: String) async throws -> AsyncThrowingStream<String, Error>
}
```

Audit checks (against the existing implementation):
- `applySystemInstruction(_:)` returns early when the trimmed string equals `activeSystemInstruction` AND a conversation already exists.
- `applySystemInstruction(_:)` calls `loadModel()` first if not loaded.
- `applySystemInstruction(_:)` recreates only the `Conversation`, never the `Engine`.
- `streamResponse(image:prompt:)` uses the most recently applied conversation.

### `MultimodalInferenceEngine` protocol (NapkinmaticOffline/AI/MultimodalInferenceEngine.swift)

Already implemented. Confirms the `applySystemInstruction(_:)` requirement is on the protocol so swapping in a fake engine for tests is straightforward.

### `LumenBrand` (NapkinmaticOffline/App/LumenBrand.swift)

Already implemented. Audit only. Required tokens: `appName`, `tagline`, `privacyReceipt`, `primary`, `secondary`, `surfaceTint`, `muted`.

### `Info.plist` (NapkinmaticOffline/App/Info.plist)

Existing. Required change: add `CFBundleDisplayName = "Lumen"`. Currently absent.

## Data Models

No new persistent data. The (`SubjectMode`, `AnswerStyle`, `OutputLanguage`) tuple is the only state that affects the engine's behavior, and it is held in-memory on `ImageAnalysisViewModel`. All three enums are `Codable` so they are persistable later if needed.

## Error Handling

- `ImageAnalysisViewModel.phase` carries a `.failed(String)` case displayed by `AnalysisView` in the output card.
- `GemmaInferenceError` already covers runtime / load / inference failures.
- `SpeechSynthesizer` swallows `AVAudioSession` configuration failures silently — TTS still works without an explicit session.
- `HomeView` surfaces an alert if the camera is unavailable on the running device.

No new error types are introduced.

## Testing Approach

Tests live in `NapkinmaticOfflineTests/`. The existing `LiteRTLMIntegrationTests.swift` is kept as-is.

- **Property tests**: All correctness properties below are testable with Swift's XCTest by either iterating finite enum domains exhaustively (no PBT framework needed) or by injecting fakes. `swift-testing` would also work but the project is on XCTest, so we stay with XCTest.
- **Unit tests**: Specific behaviors (e.g., socratic fragment guidance, idempotence on the engine harness, AnalysisView controls) are verified with example tests.
- **Smoke checks**: Bundle display name, no `PromptTemplates` references, brand-token consumption — handled as a small `BrandingSmokeTests` file using grep-like file inspection or a single xcodebuild run.

All test sub-tasks are marked optional (`*`) per the workflow, so MVP can ship without them; the build verification task is mandatory.

## Testing Strategy

- **Property tests (XCTest)**: All correctness properties below are testable by exhaustively iterating finite enum domains (`SubjectMode.allCases`, `AnswerStyle.allCases`, `OutputLanguage.allCases`) — no PBT framework is introduced. The 288-tuple Cartesian product for `PromptComposer` is small enough to brute-force in a single test.
- **Unit tests (XCTest)**: Specific behaviors (socratic fragment guidance, view-model success/failure paths, idempotence on the engine) are verified with example tests using a `RecordingFakeEngine: MultimodalInferenceEngine`.
- **Smoke checks**: `Info.plist` display name, absence of `PromptTemplates` references, brand-token consumption — handled by inspection during the corresponding audit task or by a single grep test.
- **Build verification**: `xcodebuild -project NapkinmaticOffline.xcodeproj -scheme NapkinmaticOffline -destination 'generic/platform=iOS' build`. No simulator, no device.
- All test sub-tasks are marked optional (`*`) per the workflow; the build verification task is the only mandatory verification gate.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: SubjectMode catalogue is fully populated

For any case `c` in `SubjectMode.allCases`, the values of `c.title`, `c.subtitle`, `c.systemImage`, and `c.systemInstructionFragment` are all non-empty strings, and `c.suggestedPrompts.count >= 3`.

**Validates: Requirements 1.2**

### Property 2: AnswerStyle catalogue is fully populated

For any case `s` in `AnswerStyle.allCases`, the values of `s.title`, `s.subtitle`, `s.systemImage`, and `s.systemInstructionFragment` are all non-empty strings.

**Validates: Requirements 2.2**

### Property 3: OutputLanguage catalogue is fully populated and language-tagged

For any case `l` in `OutputLanguage.allCases`, the values of `l.englishName`, `l.nativeName`, `l.bcp47`, and `l.systemInstructionFragment` are all non-empty strings, and `l.bcp47` contains a hyphen. For any case `l` other than `.english`, `l.systemInstructionFragment` contains the substring `l.englishName`.

**Validates: Requirements 3.2, 3.3**

### Property 4: PromptComposer system instruction includes all fragments

For any tuple `(subject, style, language)` in `SubjectMode.allCases × AnswerStyle.allCases × OutputLanguage.allCases`, the string returned by `PromptComposer.systemInstruction(subject:style:language:)` contains the Lumen identity preamble as a substring AND contains `subject.systemInstructionFragment`, `style.systemInstructionFragment`, and `language.systemInstructionFragment` as substrings.

**Validates: Requirements 4.2**

### Property 5: PromptComposer user prompt is trim-or-default

For any `subject` in `SubjectMode.allCases` and any string `q`: if `q.trimmingCharacters(in: .whitespacesAndNewlines)` is non-empty, then `PromptComposer.userPrompt(subject: subject, customQuestion: q)` equals the trimmed value of `q`. Otherwise, it equals `subject.suggestedPrompts.first!`.

**Validates: Requirements 4.3, 4.4**

### Property 6: SpeechSynthesizer voice selection is language-correct

For any `language` in `OutputLanguage.allCases` and any list of `AVSpeechSynthesisVoice` candidates `voices`: let `bcp = language.bcp47.lowercased()` and let `matches = voices.filter { $0.language.lowercased().hasPrefix(bcp) }`. Then `SpeechSynthesizer.bestVoice(from: voices, for: language)` returns either:
(a) a voice in `matches` of `.premium` quality if any such voice exists, or
(b) a voice in `matches` of `.enhanced` quality if no premium match exists but an enhanced one does, or
(c) any voice in `matches` if no premium or enhanced match exists, or
(d) the result of `AVSpeechSynthesisVoice(language: language.bcp47)` if `matches` is empty.

**Validates: Requirements 5.2, 5.7**

### Property 7: ImageAnalysisViewModel forwards composed prompts in order

For any tuple `(subject, style, language, customQuestion)` in `SubjectMode.allCases × AnswerStyle.allCases × OutputLanguage.allCases × { sample strings }`, after invoking `ImageAnalysisViewModel.askLumen()` against a recording fake `MultimodalInferenceEngine`: the recorded `applySystemInstruction(_:)` argument equals `PromptComposer.systemInstruction(subject:style:language:)` for the same inputs, the recorded `streamResponse(image:prompt:)` `prompt` argument equals `PromptComposer.userPrompt(subject:customQuestion:)` for the same inputs, and the `applySystemInstruction` call is observed strictly before the `streamResponse` call.

**Validates: Requirements 8.3, 8.4**

### Property 8: GemmaMultimodalEngine.applySystemInstruction is idempotent

For any non-empty string `s`, after a first call to `applySystemInstruction(s)` (which loads the model and creates a conversation), a second consecutive call to `applySystemInstruction(s)` neither recreates the conversation nor mutates `activeSystemInstruction`. (Tested via a refactored decision helper or as an example test against the live engine if LiteRT-LM cannot be linked into the test target.)

**Validates: Requirements 9.2**
