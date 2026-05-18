import SwiftUI

/// Centralized Lumen brand tokens.
enum LumenBrand {
    static let appName = "Lumen"
    static let tagline = "A private tutor for anything you can photograph."
    static let privacyReceipt = "🔒 100% on this iPhone · 0 bytes sent"

    /// Warm primary (used for the main CTA and selected chips).
    static let primary = Color(red: 0.95, green: 0.55, blue: 0.10)
    /// Deep, calming secondary (used for subject tiles and headlines).
    static let secondary = Color(red: 0.10, green: 0.20, blue: 0.35)
    /// Soft warm background tint behind cards.
    static let surfaceTint = Color(red: 1.00, green: 0.97, blue: 0.92)
    /// Subtle text color.
    static let muted = Color.secondary
}
