import SwiftUI

struct OutputCard: View {
    let responseText: String
    let elapsedTimeText: String?
    let phase: ImageAnalysisViewModel.Phase

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Label("Gemma 4, on-device", systemImage: "cpu")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.08, green: 0.32, blue: 0.30))

                Spacer()

                if let elapsedTimeText {
                    Text(elapsedTimeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            content
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loadingModel, .analyzing:
            HStack(spacing: 10) {
                ProgressView()
                Text(phase.statusText ?? "Working locally...")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("AnalysisProgress")
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.body)
                .foregroundStyle(Color(red: 0.66, green: 0.20, blue: 0.14))
                .fixedSize(horizontal: false, vertical: true)
        case .ready where responseText.isEmpty:
            Text("Ask a question to run the local model.")
                .font(.body)
                .foregroundStyle(.secondary)
        default:
            Text(responseText.isEmpty ? "No response returned." : responseText)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("GemmaResponseText")
        }
    }
}
