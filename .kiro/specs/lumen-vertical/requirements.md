# Requirements Document

## Introduction

Lumen Vertical turns the existing NapkinmaticOffline iOS app into a Lumen-branded private on-device tutor. The user picks a subject (one of 8), captures or chooses an image, and Lumen — Gemma 4 E2B running fully on-device via LiteRT-LM — answers in the user's chosen output language using their chosen pedagogical style (step-by-step, Socratic, or quick answer). Lumen can read its answer aloud through `AVSpeechSynthesizer` using a voice that matches the chosen language.

This spec audits and integrates a build order the user supplied. Many of the listed files already exist in the workspace and look implemented; the spec treats them as audit targets — they are kept if correct, modified only where there is a real gap, and the AnalysisView (which does not yet exist) is built greenfield. The final acceptance is a compile-only `xcodebuild` against a generic iOS device.

## Glossary

- **Lumen**: Product name shown in-app (display name, brand tokens, tagline). Implemented via `LumenBrand`.
- **Lumen_App**: The shipping iOS application target `NapkinmaticOffline` (display name "Lumen").
- **Subject_Mode**: The 8-case `SubjectMode` enum (universal, math, science, reading, history, language, computerScience, arts) carrying titles, capture hints, and per-subject system-prompt fragments.
- **Answer_Style**: The 3-case `AnswerStyle` enum (directWithSteps, socratic, quickAnswer) carrying a system-prompt fragment.
- **Output_Language**: The 12-case `OutputLanguage` enum (english, spanish, french, german, portuguese, arabic, hindi, chinese, japanese, korean, swahili, vietnamese) carrying English name, native name, BCP-47 locale, and a system-prompt fragment.
- **Prompt_Composer**: The `PromptComposer` enum that assembles the full system instruction (identity preamble + subject + style + language fragments) and the per-turn user prompt.
- **Speech_Synthesizer**: The `SpeechSynthesizer` `AVSpeechSynthesizer` wrapper that picks a voice from the `Output_Language.bcp47` and exposes play / pause / resume / stop and `isSpeaking` / `isPaused`.
- **Home_View**: The `HomeView` SwiftUI screen showing Lumen branding, the 8-subject grid, and the camera / library entry points.
- **Analysis_View**: The new `AnalysisView` SwiftUI screen (does not yet exist in the workspace) shown after capture; carries the subject badge, language picker, style toggle, read-aloud controls, and privacy receipt.
- **Image_Analysis_View_Model**: The `ImageAnalysisViewModel` that owns the captured image, `Subject_Mode`, `Answer_Style`, `Output_Language`, custom question, and orchestrates the engine call.
- **Gemma_Engine**: The `GemmaMultimodalEngine` LiteRT-LM wrapper that loads Gemma 4 E2B and exposes `applySystemInstruction(_:)` to recreate the conversation when subject / style / language changes.
- **System_Instruction**: The full system prompt produced by `Prompt_Composer.systemInstruction(subject:style:language:)`.
- **Privacy_Receipt**: The user-visible string asserting nothing leaves the device (e.g., "🔒 100% on this iPhone · 0 bytes sent"). Sourced from `LumenBrand.privacyReceipt`.
- **Build_Verification**: A successful `xcodebuild -scheme NapkinmaticOffline -destination 'generic/platform=iOS' build` invocation against the existing Xcode project.

## Requirements

### Requirement 1: Subject Mode catalogue

**User Story:** As a learner, I want to pick from 8 subject lenses, so that Lumen interprets my image with the right pedagogical framing.

#### Acceptance Criteria

1. THE Subject_Mode SHALL define exactly 8 cases: universal, math, science, reading, history, language, computerScience, arts.
2. THE Subject_Mode SHALL expose for each case a non-empty title, subtitle, SF Symbol name, accent color triple, system-prompt fragment, and an array of suggested capture-hint prompts of length at least 3.
3. WHEN the Subject_Mode catalogue is queried via `allCases`, THE Subject_Mode SHALL return the 8 cases in a stable order suitable for grid rendering.

### Requirement 2: Answer Style catalogue

**User Story:** As a learner, I want to choose how Lumen answers, so that I get steps, Socratic coaching, or just the answer.

#### Acceptance Criteria

1. THE Answer_Style SHALL define exactly 3 cases: directWithSteps, socratic, quickAnswer.
2. THE Answer_Style SHALL expose for each case a non-empty title, subtitle, SF Symbol name, and system-prompt fragment.
3. WHERE Answer_Style is socratic, THE system-prompt fragment SHALL instruct the model not to reveal the final answer and to ask one guiding question instead.

### Requirement 3: Output Language catalogue

**User Story:** As a learner, I want Lumen to respond in my language, so that I can study in the language I think in.

#### Acceptance Criteria

1. THE Output_Language SHALL define exactly 12 cases: english, spanish, french, german, portuguese, arabic, hindi, chinese, japanese, korean, swahili, vietnamese.
2. THE Output_Language SHALL expose for each case a non-empty `englishName`, `nativeName`, BCP-47 `bcp47` identifier, and system-prompt fragment.
3. WHERE Output_Language is not english, THE system-prompt fragment SHALL instruct the model to write its explanation in the chosen language while preserving any quoted source text in its original language.

### Requirement 4: Prompt composition

**User Story:** As a developer, I want a single composer that assembles the full system prompt and user prompt from (subject, style, language, custom question), so that the engine receives a deterministic, reproducible instruction.

#### Acceptance Criteria

1. THE Prompt_Composer SHALL expose a `systemInstruction(subject:style:language:)` function that returns a single string.
2. THE returned `systemInstruction` SHALL contain the Lumen identity preamble, the supplied Subject_Mode `systemInstructionFragment`, the supplied Answer_Style `systemInstructionFragment`, and the supplied Output_Language `systemInstructionFragment`.
3. THE Prompt_Composer SHALL expose a `userPrompt(subject:customQuestion:)` function that returns the user-supplied question after trimming whitespace, or the first suggested prompt for the supplied subject when the user-supplied question is empty.
4. WHEN `userPrompt(subject:customQuestion:)` is called with a string of only whitespace, THE Prompt_Composer SHALL return the subject's first suggested prompt.
5. THE legacy `PromptTemplates` static call site SHALL NOT be referenced from any non-test source file in the `NapkinmaticOffline` target.

### Requirement 5: Speech synthesis

**User Story:** As a learner, I want Lumen to read its answer out loud in the language I chose, so that I can listen instead of read.

#### Acceptance Criteria

1. THE Speech_Synthesizer SHALL wrap `AVSpeechSynthesizer` and publish `isSpeaking` and `isPaused` as observable Boolean state.
2. WHEN `speak(_:language:)` is called with non-empty text, THE Speech_Synthesizer SHALL select an `AVSpeechSynthesisVoice` whose `language` prefix-matches the supplied Output_Language `bcp47`, preferring premium then enhanced quality.
3. WHEN `speak(_:language:)` is called while another utterance is in progress, THE Speech_Synthesizer SHALL stop the in-progress utterance before enqueuing the new one.
4. WHEN `pause()` is called while speaking, THE Speech_Synthesizer SHALL pause at the next word boundary and update `isPaused` to true.
5. WHEN `resume()` is called while paused, THE Speech_Synthesizer SHALL continue speaking and update `isPaused` to false.
6. WHEN `stop()` is called, THE Speech_Synthesizer SHALL cancel any active or paused utterance and update `isSpeaking` and `isPaused` to false.
7. IF no voice is installed for the supplied `bcp47`, THEN THE Speech_Synthesizer SHALL fall back to `AVSpeechSynthesisVoice(language:)` with the same `bcp47`.

### Requirement 6: Home screen

**User Story:** As a learner opening Lumen, I want a clear branded home screen with subject tiles and one-tap capture, so that I can start a question in seconds.

#### Acceptance Criteria

1. THE Home_View SHALL display the Lumen brand name, tagline, and Privacy_Receipt sourced from `LumenBrand`.
2. THE Home_View SHALL render exactly 8 selectable subject tiles, one per Subject_Mode case, in a 2-column grid.
3. WHEN a subject tile is tapped, THE Home_View SHALL set the selected subject to that Subject_Mode and visually mark the tile as selected.
4. THE Home_View SHALL expose a "Take Photo" action that presents `CameraCaptureView` when the camera is available.
5. THE Home_View SHALL expose a "Choose from Library" action that presents the system `PhotosPicker` for image selection.
6. WHEN an image is captured or chosen, THE Home_View SHALL navigate to the Analysis_View, passing the captured `UIImage` and the currently selected Subject_Mode.
7. IF the camera is unavailable, THEN THE Home_View SHALL surface a non-blocking alert explaining that a physical iPhone is required.

### Requirement 7: Analysis screen

**User Story:** As a learner, I want a single screen that shows my captured image, lets me pick a language and answering style, runs Lumen, shows the answer, and reads it aloud, so that I can study without hopping between screens.

#### Acceptance Criteria

1. THE Analysis_View SHALL display the captured image, a subject badge labelled with the active Subject_Mode title, and the Privacy_Receipt.
2. THE Analysis_View SHALL expose a language picker bound to the Image_Analysis_View_Model's `outputLanguage`, listing all 12 Output_Language cases with `flag`, `nativeName`, and `englishName`.
3. THE Analysis_View SHALL expose an Answer_Style toggle bound to the Image_Analysis_View_Model's `answerStyle`, listing all 3 Answer_Style cases.
4. THE Analysis_View SHALL expose a custom-question text input bound to the Image_Analysis_View_Model's `customQuestion`, plus tappable suggested-prompt chips sourced from the active Subject_Mode's `suggestedPrompts`.
5. WHEN the user taps the primary "Ask Lumen" action, THE Analysis_View SHALL invoke `Image_Analysis_View_Model.askLumen()`.
6. THE Analysis_View SHALL display the streamed response text, the elapsed-time string, the current phase (loading model / analyzing / completed / failed), and any memory warning produced by the view model.
7. THE Analysis_View SHALL expose read-aloud controls (Play, Pause, Resume, Stop) bound to the Speech_Synthesizer.
8. WHEN the user taps Play and the response text is non-empty, THE Analysis_View SHALL call `Speech_Synthesizer.speak(_:language:)` with the response text and the active Output_Language.
9. WHEN the response text is empty, THE Analysis_View SHALL render the Play control as disabled.

### Requirement 8: Image analysis view-model wiring

**User Story:** As a developer, I want the view-model to own subject, style, and language and assemble the full instruction for the engine, so that prompt composition lives in one place.

#### Acceptance Criteria

1. THE Image_Analysis_View_Model SHALL accept a Subject_Mode at initialization and expose published `answerStyle: AnswerStyle`, `outputLanguage: OutputLanguage`, and `customQuestion: String` properties.
2. THE Image_Analysis_View_Model SHALL NOT reference any legacy `PromptTemplate` or `PromptTemplates` type.
3. WHEN `askLumen()` is invoked, THE Image_Analysis_View_Model SHALL compute the System_Instruction via `PromptComposer.systemInstruction(subject:style:language:)` and the user prompt via `PromptComposer.userPrompt(subject:customQuestion:)`.
4. WHEN `askLumen()` is invoked, THE Image_Analysis_View_Model SHALL call `Gemma_Engine.applySystemInstruction(_:)` with the computed System_Instruction before requesting inference.
5. WHEN `askLumen()` is invoked, THE Image_Analysis_View_Model SHALL stream the engine's response into its published `responseText` and update its `phase` to `.completed` on success or `.failed(message)` on error.

### Requirement 9: Engine system-instruction wiring

**User Story:** As a developer, I want the LiteRT-LM conversation to be (re)created with the composed system instruction whenever subject, style, or language changes, so that the model behaves according to the current selection without reloading the 2.4 GB weight file.

#### Acceptance Criteria

1. THE Gemma_Engine SHALL conform to `MultimodalInferenceEngine` and implement `applySystemInstruction(_:)`.
2. WHEN `applySystemInstruction(_:)` is called with a non-empty string equal to the engine's current `activeSystemInstruction` and a conversation already exists, THE Gemma_Engine SHALL return without recreating the conversation.
3. WHEN `applySystemInstruction(_:)` is called with a non-empty string different from the engine's current `activeSystemInstruction`, THE Gemma_Engine SHALL create a new LiteRT-LM `Conversation` against the existing loaded `Engine` using the supplied string as the `systemMessage`, replace its stored `conversation`, and update `activeSystemInstruction`.
4. WHEN `applySystemInstruction(_:)` is called before the model has been loaded, THE Gemma_Engine SHALL invoke `loadModel()` first and then proceed.
5. THE Gemma_Engine SHALL NOT reload the on-disk weight file when only the system instruction changes.
6. WHEN `streamResponse(image:prompt:)` is invoked after `applySystemInstruction(_:)`, THE Gemma_Engine SHALL send the user message through the conversation that was created with the most recently applied System_Instruction.

### Requirement 10: App branding

**User Story:** As a learner, I want the app to look and feel like Lumen on the home screen and inside the app, so that the product identity is consistent.

#### Acceptance Criteria

1. THE Lumen_App SHALL set its display name (`CFBundleDisplayName` in `Info.plist`) to "Lumen".
2. THE LumenBrand SHALL expose `appName`, `tagline`, `privacyReceipt`, `primary`, `secondary`, `surfaceTint`, and `muted` brand tokens consumed by Home_View and Analysis_View.
3. THE Home_View and Analysis_View SHALL source brand strings and colors from `LumenBrand` rather than hard-coding them.

### Requirement 11: Build verification

**User Story:** As a developer finishing the integration, I want a single command that proves the app still compiles, so that I can hand the build off with confidence.

#### Acceptance Criteria

1. THE Lumen_App SHALL build successfully via `xcodebuild -project NapkinmaticOffline.xcodeproj -scheme NapkinmaticOffline -destination 'generic/platform=iOS' build`.
2. IF the `xcodebuild` invocation produces any Swift compile error, THEN the integration SHALL be treated as incomplete until the error is resolved.
3. THE build verification SHALL NOT depend on a running iOS Simulator or attached device.
