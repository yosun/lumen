# Lumen

Lumen is a native iOS prototype for private, on-device visual tutoring powered by a bundled Gemma 4 E2B LiteRT-LM model. A learner can take or import a photo, choose a subject lens, ask a question, and receive a streamed answer without sending the image or prompt to a server.

The product goal is simple: make everyday learning help available in places where privacy, connectivity, cost, or classroom access make cloud AI a poor fit.

## What It Does

- Captures images with the camera or imports them from Photos.
- Supports subject modes for general help, math, science, reading, history, language, code, and arts.
- Lets the learner choose step-by-step coaching, Socratic guidance, or a short answer.
- Produces answers in 12 output languages.
- Reads answers aloud with on-device speech synthesis.
- Runs Gemma through LiteRT-LM locally, with no cloud inference fallback.
- Surfaces model-load diagnostics, backend attempts, elapsed time, and memory warnings.
- Stores completed analyses locally through an in-progress Smart History layer.

## Current Architecture

Lumen is organized as a small SwiftUI app with explicit model/runtime boundaries:

- `NapkinmaticOffline/Views/` contains the capture and analysis surfaces.
- `NapkinmaticOffline/ViewModels/ImageAnalysisViewModel.swift` owns the image-analysis flow.
- `NapkinmaticOffline/AI/GemmaMultimodalEngine.swift` adapts LiteRT-LM to the app's `MultimodalInferenceEngine` protocol.
- `NapkinmaticOffline/AI/PromptComposer.swift` builds subject, style, language, and lesson-idea prompts.
- `NapkinmaticOffline/History/` contains Smart History support: local image storage, deterministic categorization, and lesson-idea generation.
- `NapkinmaticOffline/Models/` contains persisted history records, clusters, lesson ideas, and handoff payloads.
- `Vendor/LiteRTLM/` vendors the LiteRT-LM Swift wrapper and `CLiteRTLM.xcframework`.
- `project.yml` is the source of truth for the Xcode project; regenerate with XcodeGen after adding files.

## Model And Runtime

The default model configuration targets:

- Model: `Gemma 4 E2B`
- Repository noted in code: `litert-community/gemma-4-E2B-it-litert-lm`
- Expected bundle file: `gemma-4-E2B-it.litertlm`
- Current local model size: about 2.41 GiB / 2.59 GB
- Recommended memory threshold in code: 8 GB
- Image preprocessing cap: 1024 px maximum side
- Preferred runtime path: LiteRT-LM with CPU-first fallback and optional vision backend

The app disables speculative decoding at runtime because the bundled model does not include a draft model. The engine tries multiple backend configurations and reports native diagnostics to the UI.

## Smart History Status

Smart History is partially implemented:

- Implemented: `HistoryRecord`, `HistoryStoreDocument`, `HistoryStore`, `HistoryImageStore`, `Cluster`, `LessonIdea`, `HandoffPayload`.
- Implemented: deterministic TF-IDF categorization with subject partitioning, centroid linkage, stable labels, and deterministic cluster IDs.
- Implemented: on-device lesson-idea generation prompt construction and JSON validation.
- Implemented: optional history append plumbing in `ImageAnalysisViewModel`.
- Not fully wired: visible Smart History SwiftUI screen, home navigation entry point, lesson-idea handoff into a new analysis, and default production `HistoryStore.shared` wiring.

The `.kiro/specs/smart-history-mode/` files contain the detailed requirements and implementation plan. Some checklist items are stale: several tests exist even though the plan still marks their tasks unchecked.

## Build

Requirements:

- Xcode 26.x
- XcodeGen 2.45.x or compatible
- iOS 17+ simulator or device
- Local Gemma `.litertlm` model asset for real inference

Regenerate the project and build:

```bash
xcodegen generate
xcodebuild -project NapkinmaticOffline.xcodeproj -scheme NapkinmaticOffline -destination 'generic/platform=iOS Simulator' build
```

Device demo notes:

- Add a development team/signing identity in Xcode before running on device.
- The camera path needs an `NSCameraUsageDescription` string in the app Info.plist before a physical-device demo.
- The real model asset is intentionally ignored by Git via `*.litertlm`.

## Test And Audit Results

Audit date: 2026-05-19.

Verified:

- `xcodegen generate` succeeds.
- App build succeeds after regenerating `NapkinmaticOffline.xcodeproj`.
- No app-source `URLSession`, analytics, telemetry, Firebase, Sentry, Mixpanel, or Amplitude usage was found.
- The local model file exists at `NapkinmaticOffline/Resources/ModelPlaceholder/gemma-4-E2B-it.litertlm`.

Current blockers and risks:

- The checked-in project must be regenerated after adding source files; otherwise app build fails because `Models/` and `History/` files are missing from the Xcode project.
- The test target does not currently run: `NapkinmaticOfflineTests` has no Info.plist or generated Info.plist setting.
- Many tests import `SwiftCheck`, but `project.yml` does not declare a SwiftCheck package dependency.
- `.build/`, `build/`, and `Vendor/LiteRTLM/build/` are present locally and large; they should stay out of source control.
- `Info.plist` currently lacks camera/photo usage copy needed for a polished device demo.
- Smart History persistence exists, but the user-facing Smart History screen is not yet wired into `HomeView`.

## Kaggle Project Description Draft

We built Lumen, a private on-device visual tutor for iPhone powered by Gemma 4 E2B through LiteRT-LM. Lumen lets a learner point their phone at real-world learning material - a math problem, science diagram, reading passage, foreign-language sign, code error, historical artifact, or artwork - and ask for help without uploading the image.

The app runs as a native SwiftUI experience. A learner chooses a subject mode, captures or imports an image, picks an answer style, and receives a streamed response from the local Gemma model. Lumen can explain step by step, coach Socratically, give a concise answer, translate or explain in 12 languages, and read the response aloud with on-device speech synthesis.

Our AI-for-good focus is access and trust. Students often need help in environments where internet access is unreliable, cloud tools are blocked, or photographed material is too private to upload. By keeping inference, history, and lesson suggestions on the device, Lumen makes multimodal AI assistance more usable for learners in classrooms, homes, libraries, and low-connectivity settings.

We also started Smart History Mode: a local-only learning memory that saves completed sessions, groups similar topics with deterministic TF-IDF clustering, and asks the same on-device Gemma model to suggest next lesson ideas. The long-term vision is a pocket tutor that not only answers the current question, but helps learners see what they keep practicing and decide what to study next - all without sending their images, prompts, or history off the phone.

## References Used During Implementation

- LiteRT-LM Swift API docs: https://ai.google.dev/edge/litert-lm/swift
- Gemma 4 LiteRT-LM docs: https://ai.google.dev/edge/litert-lm/models/gemma-4
- LiteRT-LM source and Swift wrapper: https://github.com/google-ai-edge/LiteRT-LM
- Google AI Edge Gallery source: https://github.com/google-ai-edge/gallery
