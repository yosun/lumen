# Lumen

Lumen (formerly Napkinmatic Offline) is a native iPhone prototype for private visual intelligence powered by an on-device Gemma 4 LiteRT-LM model. The first vertical slice is an Ask Image flow: capture or import an image, select a natural-language task prompt, optionally add a custom question, and run the multimodal model locally.

The product framing is intentionally local-first: point the phone at signs, menus, appliances, notes, forms, packaging, or other real-world objects and get useful prose without uploading the image.

## Why Gemma 4

Gemma 4 E2B is the first target because it is the mobile-oriented Gemma 4 size. Official LiteRT-LM Gemma 4 guidance lists E2B as a 2.58 GB model and includes iOS CPU/GPU performance numbers. LiteRT-LM is the intended runtime because it supports edge deployment, multimodality, and Metal-backed GPU execution on iOS.

Sources inspected before implementation:

- LiteRT-LM Swift API docs: https://ai.google.dev/edge/litert-lm/swift
- Gemma 4 LiteRT-LM docs: https://ai.google.dev/edge/litert-lm/models/gemma-4
- LiteRT-LM repo and Swift sample: https://github.com/google-ai-edge/LiteRT-LM
- Google AI Edge Gallery model allowlists/source: https://github.com/google-ai-edge/gallery

## Current Implementation

- SwiftUI home screen with the requested title, subtitle, camera action, library action, and privacy line.
- Camera capture through `UIImagePickerController`.
- Photo import through `PhotosPicker`.
- Analysis screen with selected image preview, prompt chips, custom question input, run button, output card, elapsed time, and reset/new image flow.
- `ModelManager` with separate bundled-model and downloaded-local-asset paths.
- `GemmaMultimodalEngine` conforming to `MultimodalInferenceEngine`.
- Image preprocessing that normalizes orientation and downscales before inference.
- Streaming response support through LiteRT-LM's Swift `sendMessageStream` API.
- Explicit errors for missing model, low-memory devices, model load failure, runtime not linked, and inference failure.
- Lightweight integration tests that verify the bundled model is present and can be opened through LiteRT-LM `Capabilities`.

## Important SDK Status

The app now links a local vendored LiteRT-LM Swift package at `Vendor/LiteRTLM`.

As of this scaffold:

- Official Swift docs show `import LiteRTLM`, `EngineConfig`, `Engine`, `Conversation`, `Message`, `Content.imageFile` / `Content.imageData`, and `sendMessageStream`.
- The public LiteRT-LM overview has described Swift as in development, so treat the Swift ABI/API as early.
- The upstream `main` package manifest referenced a `v0.12.0` binary URL, while the public release list I checked exposed `v0.11.0` as latest.
- `v0.11.0-rc.1` publishes `CLiteRTLM.xcframework.zip`; this repo vendors that official binary and uses Google's Swift wrapper sources.

When Google publishes a stable Swift package/binary release, replace `Vendor/LiteRTLM` with the official SPM dependency and keep the `GemmaMultimodalEngine` call sites unchanged.

## Add the Gemma 4 E2B Model

For a bundled hackathon/demo build:

1. Download `gemma-4-E2B-it.litertlm` from `litert-community/gemma-4-E2B-it-litert-lm`.
2. Place it at:

   `ModelPlaceholder/gemma-4-E2B-it.litertlm`

3. Regenerate the project with `xcodegen generate`.
4. Confirm the file appears in the app target's Copy Bundle Resources phase.

For a future production download flow, switch `ModelConfiguration.storageMode` to `.downloadedLocalAsset`. The app will look for:

`Models/gemma-4-E2B-it.litertlm`

No cloud inference fallback is implemented.

## LiteRT-LM Runtime

The project links `LiteRTLM` through `project.yml`:

```yaml
packages:
  LiteRTLM:
    path: Vendor/LiteRTLM
```

The vendored package contains:

- Google Swift wrapper sources from `google-ai-edge/LiteRT-LM`.
- The official `CLiteRTLM.xcframework` binary from the `v0.11.0-rc.1` GitHub release.

The simulator build embeds `CLiteRTLM.framework` in the app. The integration test `testLiteRTLMCanOpenBundledModelCapabilities` verifies the framework can open the bundled `.litertlm` model container.

## Build

Requirements:

- Xcode 26.x or newer
- XcodeGen
- iOS 17+ target device

Commands:

```bash
xcodegen generate
xcodebuild -project NapkinmaticOffline.xcodeproj -scheme NapkinmaticOffline -destination 'generic/platform=iOS Simulator' build
xcodebuild -project NapkinmaticOffline.xcodeproj -scheme NapkinmaticOffline -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

To run on device, open the project in Xcode, select your iPhone, set signing for the app target, and press Run.

## Manual Airplane Mode QA

1. Install the app with the local model asset present.
2. Launch once and confirm the model loads.
3. Enable Airplane Mode.
4. Relaunch the app.
5. Take or import a photo.
6. Tap Ask Offline Gemma.
7. Confirm a response is generated while the network remains disabled.
8. Confirm Xcode logs do not show any cloud inference or upload path.

## Device And Performance Notes

- Gemma 4 E2B is configured as the default model.
- The model file is about 2.58 GB; leave room for app bundle size, runtime memory, and cache files.
- `ModelConfiguration.minimumMemoryGB` is set to 8 GB because the public Gallery allowlist uses 8 GB for Gemma 4 E2B.
- Images are downscaled to a 1024 px maximum side before inference.
- The flow is single-turn and avoids storing heavy multimodal history.
- GPU is configured as the preferred backend and vision backend once LiteRT-LM is linked. Switch to CPU in `ModelConfiguration` if GPU dynamic library setup is not ready.

## Future Extensions

- First-run model download with resume, checksum, and storage budget UI.
- Task routing for menus, forms, handwritten notes, device panels, packaging, and accessibility descriptions.
- Local behavior suggestions that never leave the device.
- E4B quality mode for high-memory devices.
- Model health screen with file size, location, backend, load time, and token speed.

## Main Files

- `NapkinmaticOffline/Views/HomeView.swift`
- `NapkinmaticOffline/Views/AnalysisView.swift`
- `NapkinmaticOffline/ViewModels/ImageAnalysisViewModel.swift`
- `NapkinmaticOffline/AI/GemmaMultimodalEngine.swift`
- `NapkinmaticOffline/AI/ModelManager.swift`
- `NapkinmaticOffline/AI/PromptTemplates.swift`
- `NapkinmaticOffline/Utilities/ImagePreprocessor.swift`
