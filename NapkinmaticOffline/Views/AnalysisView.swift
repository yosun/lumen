import SwiftUI
import UIKit

/// Per-image working surface. Shown after the user picks a subject and
/// captures (or chooses) an image on `HomeView`. Owns the
/// `ImageAnalysisViewModel` for the run and a `SpeechSynthesizer` for
/// read-aloud playback.
struct AnalysisView: View {
    @StateObject private var viewModel: ImageAnalysisViewModel
    @StateObject private var speech = SpeechSynthesizer()

    private let subject: SubjectMode
    private let onClose: () -> Void

    init(image: UIImage, subject: SubjectMode, onClose: @escaping () -> Void) {
        self.subject = subject
        self.onClose = onClose
        _viewModel = StateObject(
            wrappedValue: ImageAnalysisViewModel(image: image, subject: subject)
        )
    }

    private var subjectAccent: Color {
        Color(
            red: subject.accentRGB.r,
            green: subject.accentRGB.g,
            blue: subject.accentRGB.b
        )
    }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topBar
                    imagePreview
                    privacyStrip
                    languagePicker
                    answerStylePicker
                    suggestedPromptsRow
                    customQuestionField
                    askButton
                    OutputCard(
                        responseText: viewModel.responseText,
                        elapsedTimeText: viewModel.elapsedTimeText,
                        phase: viewModel.phase
                    )
                    if let warning = viewModel.memoryWarning {
                        memoryWarningBanner(warning)
                    }
                    readAloudBar
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                LumenBrand.surfaceTint
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LumenBrand.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground), in: Circle())
                    .overlay(Circle().stroke(Color(.separator), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("AnalysisCloseButton")

            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(LumenBrand.primary)
                Text(LumenBrand.appName)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(LumenBrand.secondary)
            }

            Spacer()

            subjectBadge
        }
    }

    private var subjectBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: subject.systemImage)
                .font(.caption.weight(.bold))
            Text(subject.title)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(subjectAccent, in: Capsule())
        .accessibilityIdentifier("AnalysisSubjectBadge")
    }

    // MARK: Image preview

    private var imagePreview: some View {
        Image(uiImage: viewModel.image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 280)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            }
            .accessibilityIdentifier("AnalysisImagePreview")
    }

    // MARK: Privacy strip

    private var privacyStrip: some View {
        Label(LumenBrand.privacyReceipt, systemImage: "lock.shield.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(LumenBrand.surfaceTint, in: Capsule())
    }

    // MARK: Language picker

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Output language")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LumenBrand.secondary)

            Menu {
                Picker("Output language", selection: $viewModel.outputLanguage) {
                    ForEach(OutputLanguage.allCases) { language in
                        Text("\(language.flag) \(language.nativeName) (\(language.englishName))")
                            .tag(language)
                    }
                }
            } label: {
                HStack {
                    Text(viewModel.outputLanguage.flag)
                    Text(viewModel.outputLanguage.nativeName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(LumenBrand.secondary)
                    Text("(\(viewModel.outputLanguage.englishName))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(
                    Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                }
            }
            .accessibilityIdentifier("AnalysisLanguageMenu")
        }
    }

    // MARK: Answer-style picker

    private var answerStylePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Answer style")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LumenBrand.secondary)

            Picker("Answer style", selection: $viewModel.answerStyle) {
                ForEach(AnswerStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("AnalysisAnswerStylePicker")
        }
    }

    // MARK: Suggested prompts

    private var suggestedPromptsRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Suggested prompts")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LumenBrand.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(subject.suggestedPrompts, id: \.self) { prompt in
                        PromptChip(
                            title: prompt,
                            isSelected: viewModel.customQuestion == prompt
                        ) {
                            viewModel.applySuggestedPrompt(prompt)
                        }
                        .frame(width: 200)
                    }
                }
            }
            .accessibilityIdentifier("AnalysisSuggestedPrompts")
        }
    }

    // MARK: Custom question

    private var customQuestionField: some View {
        TextField(
            "Ask Lumen a question…",
            text: $viewModel.customQuestion,
            axis: .vertical
        )
        .lineLimit(1...3)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        }
        .accessibilityIdentifier("AnalysisCustomQuestion")
    }

    // MARK: Ask button

    private var askButton: some View {
        PrimaryActionButton(
            title: "Ask Lumen",
            systemImage: "sparkles"
        ) {
            Task { await viewModel.askLumen() }
        }
        .opacity(viewModel.phase.isWorking ? 0.6 : 1.0)
        .disabled(viewModel.phase.isWorking)
    }

    // MARK: Memory-warning banner

    private func memoryWarningBanner(_ warning: String) -> some View {
        Label(warning, systemImage: "memorychip")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color(red: 0.66, green: 0.20, blue: 0.14))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(red: 1.00, green: 0.93, blue: 0.90),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(red: 0.85, green: 0.55, blue: 0.45), lineWidth: 1)
            }
            .accessibilityIdentifier("AnalysisMemoryWarning")
    }

    // MARK: Read-aloud bar

    private var readAloudBar: some View {
        let canPlay = !viewModel.responseText.isEmpty && !speech.isSpeaking
        let canPause = speech.isSpeaking && !speech.isPaused
        let canResume = speech.isPaused
        let canStop = speech.isSpeaking || speech.isPaused

        return VStack(alignment: .leading, spacing: 8) {
            Text("Read aloud")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LumenBrand.secondary)

            HStack(spacing: 10) {
                readAloudButton(
                    title: "Play",
                    systemImage: "play.fill",
                    isEnabled: canPlay
                ) {
                    speech.speak(
                        viewModel.responseText,
                        language: viewModel.outputLanguage
                    )
                }
                .accessibilityIdentifier("ReadAloudPlay")

                readAloudButton(
                    title: "Pause",
                    systemImage: "pause.fill",
                    isEnabled: canPause
                ) {
                    speech.pause()
                }
                .accessibilityIdentifier("ReadAloudPause")

                readAloudButton(
                    title: "Resume",
                    systemImage: "playpause.fill",
                    isEnabled: canResume
                ) {
                    speech.resume()
                }
                .accessibilityIdentifier("ReadAloudResume")

                readAloudButton(
                    title: "Stop",
                    systemImage: "stop.fill",
                    isEnabled: canStop
                ) {
                    speech.stop()
                }
                .accessibilityIdentifier("ReadAloudStop")
            }
        }
    }

    private func readAloudButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? LumenBrand.secondary : Color(.tertiaryLabel))
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.separator), lineWidth: 1)
        }
        .opacity(isEnabled ? 1.0 : 0.5)
        .disabled(!isEnabled)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AnalysisView(
            image: UIImage(systemName: "photo") ?? UIImage(),
            subject: .math,
            onClose: {}
        )
    }
}
#endif
