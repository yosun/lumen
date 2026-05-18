import SwiftUI

struct PrimaryActionButton: View {
    let title: String
    let systemImage: String
    var prominence: Prominence = .primary
    let action: () -> Void

    enum Prominence {
        case primary
        case secondary
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundStyle)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(borderStyle, lineWidth: 1)
        }
        .accessibilityIdentifier(title.replacingOccurrences(of: " ", with: ""))
    }

    private var foregroundStyle: Color {
        switch prominence {
        case .primary:
            return .white
        case .secondary:
            return .primary
        }
    }

    private var backgroundStyle: Color {
        switch prominence {
        case .primary:
            return Color(red: 0.08, green: 0.32, blue: 0.30)
        case .secondary:
            return Color(.secondarySystemBackground)
        }
    }

    private var borderStyle: Color {
        switch prominence {
        case .primary:
            return Color.clear
        case .secondary:
            return Color(.separator)
        }
    }
}
