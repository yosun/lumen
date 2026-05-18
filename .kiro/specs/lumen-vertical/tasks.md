# Implementation Plan: Lumen Vertical

Convert the feature design into a series of prompts for a code-generation LLM that will implement each step with incremental progress. Make sure that each prompt builds on the previous prompts, and ends with wiring things together. There should be no hanging or orphaned code that isn't integrated into a previous step. Focus ONLY on tasks that involve writing, modifying, or testing code.

## Overview

The build order maps 1:1 onto the user-supplied list. Most files already exist in the workspace, so each task is "audit, then modify only if a real gap is found." The only greenfield file is `AnalysisView.swift`. The final task compiles the project against a generic iOS device.

Implementation language: Swift / SwiftUI.

## Task Dependency Graph

```
1 (SubjectMode audit) ──┐
2 (AnswerStyle audit)   ├──▶ 4 (PromptComposer audit) ──▶ 7 (ViewModel audit) ──┐
3 (OutputLanguage audit)┘                                                       │
                                                                                ├──▶ 8 (AnalysisView NEW) ──┐
5 (SpeechSynthesizer audit/refactor) ───────────────────────────────────────────┘                          │
                                                                                                           │
1 (SubjectMode audit) ──▶ 6 (HomeView audit) ──────────────────────────────────────────────────────────────┤
                                                                                                           │
9 (GemmaMultimodalEngine audit) ───────────────────────────────────────────────────────────────────────────┤
                                                                                                           │
10 (App branding: Info.plist + LumenBrand) ────────────────────────────────────────────────────────────────┤
                                                                                                           ▼
                                                                                                       11 (Build & verify)
```

Notes:
- Tasks 1, 2, 3, 5, 9, 10 have no upstream dependencies and can be executed in any order or in parallel.
- Task 4 depends on 1, 2, 3 (composer references all three enums).
- Task 6 depends on 1 (HomeView grid binds to `SubjectMode.allCases`).
- Task 7 depends on 1, 2, 3, 4 (view-model uses all enums + composer).
- Task 8 depends on 1, 2, 3, 5, 7 (AnalysisView binds to view-model state and uses speech).
- Task 11 depends on every other task; it is the sole verification gate.

```json
{
  "waves": [
    {
      "wave": 1,
      "tasks": ["1", "2", "3", "5", "9", "10"],
      "description": "Independent audits: enum catalogues, speech synthesizer refactor, engine wiring audit, branding tokens. No cross-task dependencies."
    },
    {
      "wave": 2,
      "tasks": ["4", "6"],
      "description": "Composer depends on the three catalogues (1, 2, 3). HomeView audit depends on SubjectMode (1)."
    },
    {
      "wave": 3,
      "tasks": ["7"],
      "description": "ImageAnalysisViewModel audit depends on the catalogues (1, 2, 3) and PromptComposer (4)."
    },
    {
      "wave": 4,
      "tasks": ["8"],
      "description": "Greenfield AnalysisView depends on the catalogues (1, 2, 3), SpeechSynthesizer (5), and the view-model (7)."
    },
    {
      "wave": 5,
      "tasks": ["11"],
      "description": "Build verification gate — runs only after every preceding task is complete."
    }
  ]
}
```

## Tasks

- [x] 1. Audit `SubjectMode.swift`
  - Open `NapkinmaticOffline/AI/SubjectMode.swift` and verify it defines exactly the 8 cases (universal, math, science, reading, history, language, computerScience, arts) with non-empty `title`, `subtitle`, `systemImage`, `accentRGB`, `systemInstructionFragment`, and `suggestedPrompts.count >= 3`.
  - If any case is missing or any field is empty, edit the file in place to satisfy the requirement.
  - Do NOT rewrite the file if it already passes the audit.
  - _Requirements: 1.1, 1.2, 1.3_

  - [ ]* 1.1 Property test for SubjectMode catalogue
    - Add `NapkinmaticOfflineTests/SubjectModeTests.swift` with an XCTest that iterates `SubjectMode.allCases` and asserts every field is non-empty and `suggestedPrompts.count >= 3`.
    - **Property 1: SubjectMode catalogue is fully populated**
    - **Validates: Requirements 1.2**

- [x] 2. Audit `AnswerStyle.swift`
  - Open `NapkinmaticOffline/AI/AnswerStyle.swift` and verify it defines exactly the 3 cases (directWithSteps, socratic, quickAnswer) with non-empty `title`, `subtitle`, `systemImage`, and `systemInstructionFragment`.
  - Confirm `socratic.systemInstructionFragment` instructs the model to ask a guiding question and not reveal the final answer.
  - Edit only to close gaps.
  - _Requirements: 2.1, 2.2, 2.3_

  - [ ]* 2.1 Property test for AnswerStyle catalogue
    - Add `NapkinmaticOfflineTests/AnswerStyleTests.swift` asserting every case's fields are non-empty, plus an example test verifying the socratic fragment contains guidance keywords ("guiding", "do not", or equivalent).
    - **Property 2: AnswerStyle catalogue is fully populated**
    - **Validates: Requirements 2.2, 2.3**

- [x] 3. Audit `OutputLanguage.swift`
  - Open `NapkinmaticOffline/AI/OutputLanguage.swift` and verify it defines exactly the 12 cases listed in the requirements with non-empty `englishName`, `nativeName`, `flag`, `bcp47`, and `systemInstructionFragment`.
  - Confirm every `bcp47` contains a hyphen and every non-english `systemInstructionFragment` includes the language's `englishName`.
  - Edit only to close gaps.
  - _Requirements: 3.1, 3.2, 3.3_

  - [ ]* 3.1 Property test for OutputLanguage catalogue
    - Add `NapkinmaticOfflineTests/OutputLanguageTests.swift` iterating `OutputLanguage.allCases`, asserting non-empty fields, hyphenated bcp47, and that non-english fragments contain the case's englishName.
    - **Property 3: OutputLanguage catalogue is fully populated and language-tagged**
    - **Validates: Requirements 3.2, 3.3**

- [x] 4. Audit `PromptComposer.swift` and remove legacy `PromptTemplates` references
  - Open `NapkinmaticOffline/AI/PromptComposer.swift` and verify `systemInstruction(subject:style:language:)` returns a string containing the Lumen identity preamble plus all three input fragments, and `userPrompt(subject:customQuestion:)` returns trimmed input or the subject's first suggested prompt for empty/whitespace input.
  - Search the entire `NapkinmaticOffline/` source tree (excluding tests) for any remaining `PromptTemplates` or `PromptTemplate` symbol references; if any remain, replace them with the equivalent `PromptComposer` calls.
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [ ]* 4.1 Property test for PromptComposer.systemInstruction
    - Add `NapkinmaticOfflineTests/PromptComposerTests.swift` with a test that iterates the full Cartesian product `SubjectMode.allCases × AnswerStyle.allCases × OutputLanguage.allCases` (288 combinations) and asserts the result contains each fragment as a substring plus the identity preamble.
    - **Property 4: PromptComposer system instruction includes all fragments**
    - **Validates: Requirements 4.2**

  - [ ]* 4.2 Property test for PromptComposer.userPrompt
    - Add to `PromptComposerTests.swift` a test that iterates `SubjectMode.allCases` and a small set of (empty, whitespace-only, non-empty, leading/trailing whitespace) input strings, asserting trim-or-default behavior.
    - **Property 5: PromptComposer user prompt is trim-or-default**
    - **Validates: Requirements 4.3, 4.4**

- [x] 5. Audit and refactor `SpeechSynthesizer.swift`
  - Open `NapkinmaticOffline/Utilities/SpeechSynthesizer.swift` and verify it conforms to the design surface (`speak`, `pause`, `resume`, `stop`, `isSpeaking`, `isPaused`).
  - Refactor: extract the existing `bestVoice(for:)` instance method into a `static func bestVoice(from voices: [AVSpeechSynthesisVoice], for language: OutputLanguage) -> AVSpeechSynthesisVoice?` pure helper. Have the instance method delegate to the static helper, passing `AVSpeechSynthesisVoice.speechVoices()`.
  - Preserve all current behavior (premium → enhanced → any → fallback).
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_

  - [ ]* 5.1 Property test for SpeechSynthesizer.bestVoice
    - Add `NapkinmaticOfflineTests/SpeechSynthesizerTests.swift` with a test that builds synthetic `AVSpeechSynthesisVoice`-shaped fixtures (or wraps `AVSpeechSynthesisVoice` directly) covering: (a) only premium matches, (b) only enhanced matches, (c) only default matches, (d) no language matches. Assert the chosen voice satisfies the priority order in Property 6.
    - **Property 6: SpeechSynthesizer voice selection is language-correct**
    - **Validates: Requirements 5.2, 5.7**

- [x] 6. Audit `HomeView.swift` Lumen branding and subject grid
  - Open `NapkinmaticOffline/Views/HomeView.swift` and confirm: it sources `LumenBrand.appName`, `LumenBrand.tagline`, and `LumenBrand.privacyReceipt`; renders a 2-column grid of all 8 `SubjectMode` cases via `SubjectTile`; presents `CameraCaptureView` for "Take Photo" and `PhotosPicker` for "Choose from Library"; navigates to `AnalysisView(image:subject:onClose:)` after capture.
  - The file currently navigates to `AnalysisView` which does not yet exist. Do NOT add a stub here — Task 8 creates the real `AnalysisView`.
  - Edit only to close gaps in branding strings, tile binding, or capture entry points. Do not introduce new state.
  - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 10.3_

- [x] 7. Audit `ImageAnalysisViewModel.swift`
  - Open `NapkinmaticOffline/ViewModels/ImageAnalysisViewModel.swift` and verify: it accepts a `SubjectMode` at init, publishes `answerStyle: AnswerStyle`, `outputLanguage: OutputLanguage`, and `customQuestion: String`; computes `composedSystemInstruction` via `PromptComposer.systemInstruction(...)`; in `askLumen()` calls `engine.applySystemInstruction(composedSystemInstruction)` BEFORE `engine.streamResponse(image:prompt:)`; passes `PromptComposer.userPrompt(subject:customQuestion:)` as the prompt; updates `phase` to `.completed` on success and `.failed(...)` on error; never references `PromptTemplate` / `PromptTemplates`.
  - Edit only to close gaps. Preserve the existing diagnostic-log and memory-warning plumbing.
  - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [ ]* 7.1 Property test for askLumen prompt forwarding
    - Add `NapkinmaticOfflineTests/ImageAnalysisViewModelTests.swift`. Define a `RecordingFakeEngine: MultimodalInferenceEngine` that records the order and arguments of `applySystemInstruction` and `streamResponse` calls. Iterate (subject, style, language, sampleQuestion) tuples and assert the recorded arguments equal the `PromptComposer` outputs and that `applySystemInstruction` is observed before `streamResponse`.
    - **Property 7: ImageAnalysisViewModel forwards composed prompts in order**
    - **Validates: Requirements 8.3, 8.4**

  - [ ]* 7.2 Unit tests for askLumen success and failure paths
    - In the same file, add example tests that drive a fake engine yielding known chunks and assert `responseText` accumulates and `phase` ends in `.completed`. Add a counterpart that throws and asserts `phase` ends in `.failed(_)`.
    - _Requirements: 8.5_

- [x] 8. Build new `AnalysisView.swift`
  - Create `NapkinmaticOffline/Views/AnalysisView.swift` (greenfield) with init `(image: UIImage, subject: SubjectMode, onClose: @escaping () -> Void)`.
  - Use `@StateObject` for `ImageAnalysisViewModel(image:subject:)` and `@StateObject` for `SpeechSynthesizer()`.
  - Lay out (top-to-bottom): close button + Lumen wordmark + subject badge; rounded image preview; `LumenBrand.privacyReceipt` strip; output-language `Menu` picker bound to `viewModel.outputLanguage` (rendering `flag nativeName (englishName)`); answer-style `Picker` (segmented) bound to `viewModel.answerStyle`; horizontal scroll of suggested-prompt chips that fill `viewModel.customQuestion` on tap (use existing `PromptChip`); `TextField` for custom question; primary "Ask Lumen" button calling `Task { await viewModel.askLumen() }` (disabled while `viewModel.phase.isWorking`); existing `OutputCard` for streamed response/elapsed/phase plus a memory-warning banner if `viewModel.memoryWarning != nil`; read-aloud bar with Play / Pause / Resume / Stop bound to the speech synthesizer.
  - Play taps `speech.speak(viewModel.responseText, language: viewModel.outputLanguage)` and is disabled when `viewModel.responseText.isEmpty`. Pause/Resume/Stop call the corresponding `SpeechSynthesizer` methods. Reflect `speech.isSpeaking` and `speech.isPaused` in the bar's enabled-state.
  - Use `LumenBrand` tokens (`primary`, `secondary`, `surfaceTint`) for accent colors. Use `subject.accentRGB` for the subject badge fill.
  - Keep the file self-contained — do not introduce new shared components beyond what's reused (`PromptChip`, `OutputCard`, `PrimaryActionButton`).
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8, 7.9, 10.3_

  - [x]* 8.1 Add `AnalysisView.swift` to the Xcode target if not auto-discovered
    - If `xcodebuild` reports the new file is not part of the `NapkinmaticOffline` target, edit `NapkinmaticOffline.xcodeproj/project.pbxproj` to add the file to the `Sources` build phase. The Xcode project uses file-system synchronized groups in many sections, so a manual entry may not be required — only do this if Task 11 reports a build error referencing AnalysisView.
    - _Requirements: 11.1_

- [x] 9. Audit system-instruction wiring in `GemmaMultimodalEngine.swift`
  - Open `NapkinmaticOffline/AI/GemmaMultimodalEngine.swift` and confirm: `applySystemInstruction(_:)` is implemented; it returns early when the trimmed input equals `activeSystemInstruction` AND `conversation != nil`; it calls `loadModel()` first if the engine is not loaded; on a different instruction it calls `engine.createConversation(with: ConversationConfig(systemMessage: Message(trimmed, role: .system), samplerConfig: ...))` and replaces `self.conversation` and `self.activeSystemInstruction`; it never touches the model weights / `Engine` instance.
  - Confirm `streamResponse(image:prompt:)` and `streamTextResponse(prompt:)` always use the most recently stored `conversation`.
  - Confirm the protocol declaration `MultimodalInferenceEngine` includes `applySystemInstruction(_:)` so a recording fake can satisfy the protocol.
  - Edit only to close gaps. Do not change loading-attempt sequencing or error handling.
  - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6_

  - [ ]* 9.1 Idempotence example test for applySystemInstruction
    - In `NapkinmaticOfflineTests/GemmaMultimodalEngineTests.swift`, add a test that calls `applySystemInstruction("X")` twice in a row against a real (or refactored decision-helper) engine and asserts that `activeSystemInstruction` equals "X" both times and that no observable side-effect from a second creation occurred. If LiteRT-LM is not linkable in this test target, downgrade to a static-helper test of the decision logic.
    - **Property 8: GemmaMultimodalEngine.applySystemInstruction is idempotent**
    - **Validates: Requirements 9.2_

- [x] 10. App branding — display name and brand tokens
  - Open `NapkinmaticOffline/App/Info.plist` and add `<key>CFBundleDisplayName</key><string>Lumen</string>` if not present.
  - Open `NapkinmaticOffline/App/LumenBrand.swift` and verify all tokens listed in design (`appName`, `tagline`, `privacyReceipt`, `primary`, `secondary`, `surfaceTint`, `muted`) exist.
  - Verify `HomeView.swift` and the new `AnalysisView.swift` source brand strings/colors from `LumenBrand` rather than hard-coding.
  - _Requirements: 10.1, 10.2, 10.3_

- [x] 11. Build & verify
  - Run from the workspace root: `xcodebuild -project NapkinmaticOffline.xcodeproj -scheme NapkinmaticOffline -destination 'generic/platform=iOS' build`.
  - Treat any Swift compile error or linker error as task failure; resolve and re-run until the build succeeds.
  - Do NOT boot a simulator and do NOT run the test target — verification is compile-only.
  - If a missing-file error references `AnalysisView`, ensure Task 8 created the file at `NapkinmaticOffline/Views/AnalysisView.swift` and that the Xcode project includes it.
  - _Requirements: 11.1, 11.2, 11.3_

## Notes

- Tasks marked with `*` are optional and can be skipped for the fastest path to a green build.
- Each top-level task references the requirement clauses it satisfies for traceability.
- Tasks 1–10 are dependency-ordered: Tasks 1–5 (catalogues, composer, speech) have no dependencies; Task 6 (HomeView audit) depends on Task 1; Task 7 (view-model audit) depends on Tasks 1, 2, 3, 4; Task 8 (new AnalysisView) depends on Tasks 1, 2, 3, 5, 7; Task 9 (engine wiring) is independent but pairs with Task 7's call site; Task 10 (branding) is independent; Task 11 (build) requires every preceding task.
- All audit tasks are "minimal-edit": preserve correct existing code; only modify when a real gap exists.
- Property tests use XCTest and exhaustively iterate finite enum domains rather than introducing a new PBT framework.
