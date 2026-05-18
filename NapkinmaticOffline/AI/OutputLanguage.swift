import Foundation

/// The language Lumen should respond in. Defaults to English. Gemma 4 is
/// multilingual so no translation API is needed — we just ask the model.
enum OutputLanguage: String, CaseIterable, Identifiable, Codable {
    case english
    case spanish
    case french
    case german
    case portuguese
    case arabic
    case hindi
    case chinese
    case japanese
    case korean
    case swahili
    case vietnamese

    var id: String { rawValue }

    /// Human-friendly name in English (used in the picker).
    var englishName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .portuguese: return "Portuguese"
        case .arabic: return "Arabic"
        case .hindi: return "Hindi"
        case .chinese: return "Chinese (Simplified)"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .swahili: return "Swahili"
        case .vietnamese: return "Vietnamese"
        }
    }

    /// Native name (also shown in the picker so users find their own
    /// language even if they don't read English well).
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .portuguese: return "Português"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .swahili: return "Kiswahili"
        case .vietnamese: return "Tiếng Việt"
        }
    }

    /// Flag-ish emoji shown in the picker (chosen for recognizability,
    /// not political endorsement of any country).
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .portuguese: return "🇧🇷"
        case .arabic: return "🌍"
        case .hindi: return "🇮🇳"
        case .chinese: return "🇨🇳"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .swahili: return "🌍"
        case .vietnamese: return "🇻🇳"
        }
    }

    /// BCP-47 locale identifier used to pick the matching AVSpeechSynthesisVoice.
    var bcp47: String {
        switch self {
        case .english: return "en-US"
        case .spanish: return "es-ES"
        case .french: return "fr-FR"
        case .german: return "de-DE"
        case .portuguese: return "pt-BR"
        case .arabic: return "ar-SA"
        case .hindi: return "hi-IN"
        case .chinese: return "zh-CN"
        case .japanese: return "ja-JP"
        case .korean: return "ko-KR"
        case .swahili: return "sw-KE"
        case .vietnamese: return "vi-VN"
        }
    }

    /// Instruction injected into the system prompt so Gemma replies in the
    /// chosen language (regardless of the language the source material is
    /// written in).
    var systemInstructionFragment: String {
        switch self {
        case .english:
            return "Respond in English."
        default:
            return "Respond in \(englishName) (\(nativeName)). All steps, headings, and explanations must be in \(englishName). If you transcribe text from the image, keep the original language for the transcription, but write your explanation in \(englishName)."
        }
    }
}
