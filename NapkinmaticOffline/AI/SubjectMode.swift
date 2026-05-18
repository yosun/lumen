import Foundation

/// The "subject lens" through which Lumen interprets the captured image.
///
/// Each mode carries its own system-prompt fragment, capture hints, and
/// suggested follow-up questions. Picking the wrong mode still works — Gemma
/// is multimodal — but the right mode produces sharper, more pedagogically
/// useful answers.
enum SubjectMode: String, CaseIterable, Identifiable, Codable {
    case universal
    case math
    case science
    case reading
    case history
    case language
    case computerScience
    case arts

    var id: String { rawValue }

    /// Display title shown on subject tiles.
    var title: String {
        switch self {
        case .universal: return "Anything"
        case .math: return "Math"
        case .science: return "Science"
        case .reading: return "Reading"
        case .history: return "History"
        case .language: return "Language"
        case .computerScience: return "Code"
        case .arts: return "Art & Music"
        }
    }

    /// One-line subtitle for the tile.
    var subtitle: String {
        switch self {
        case .universal: return "Point at anything. Lumen figures it out."
        case .math: return "Equations, geometry, graphs, word problems."
        case .science: return "Diagrams, lab setups, biology, chemistry."
        case .reading: return "Passages, vocabulary, comprehension."
        case .history: return "Maps, timelines, primary sources."
        case .language: return "Signs, menus, textbook pages, translation."
        case .computerScience: return "Code on screen or paper, error messages."
        case .arts: return "Sheet music, paintings, technique."
        }
    }

    /// SF Symbol used on the tile.
    var systemImage: String {
        switch self {
        case .universal: return "sparkles.rectangle.stack"
        case .math: return "function"
        case .science: return "atom"
        case .reading: return "text.book.closed"
        case .history: return "scroll"
        case .language: return "character.book.closed"
        case .computerScience: return "chevron.left.forwardslash.chevron.right"
        case .arts: return "paintpalette"
        }
    }

    /// Accent color hue used on tiles and badges.
    var accentRGB: (r: Double, g: Double, b: Double) {
        switch self {
        case .universal: return (0.35, 0.20, 0.55)
        case .math:      return (0.10, 0.40, 0.75)
        case .science:   return (0.10, 0.55, 0.50)
        case .reading:   return (0.70, 0.40, 0.10)
        case .history:   return (0.55, 0.35, 0.20)
        case .language:  return (0.60, 0.20, 0.45)
        case .computerScience: return (0.20, 0.55, 0.30)
        case .arts:      return (0.75, 0.30, 0.45)
        }
    }

    /// Pedagogical instruction injected into the system prompt for this mode.
    var systemInstructionFragment: String {
        switch self {
        case .universal:
            return """
            The user has not specified a subject. Identify what is in the image \
            (a problem, a passage, a diagram, an object, a sign, code, art, etc.) \
            and respond with whatever is most useful for a learner: identify, \
            explain, translate, or solve as appropriate. If it is a problem of \
            any kind, show your reasoning step by step.
            """
        case .math:
            return """
            Treat this image as a math problem. Transcribe equations exactly \
            as written, including handwriting. Solve the problem step by step, \
            showing every line of working. State the final answer clearly. If \
            the problem is ambiguous, state what assumption you are making. \
            Use plain text for math (e.g. x^2, sqrt(2), pi). Do not invent \
            equations that are not visible.
            """
        case .science:
            return """
            Treat this image as a science question. Identify the diagram, \
            apparatus, organism, formula, or phenomenon shown. Explain the \
            underlying concept in clear, age-appropriate language. If it is \
            a problem, show the reasoning step by step. Define technical \
            vocabulary on first use.
            """
        case .reading:
            return """
            Treat this image as a reading passage. First, transcribe the \
            visible text accurately. Then explain the meaning, identify key \
            ideas and any difficult vocabulary, and answer any questions the \
            user asks about it. Quote directly from the passage when \
            answering comprehension questions.
            """
        case .history:
            return """
            Treat this image as a history or civics artifact (map, timeline, \
            document, photograph, monument). Identify what it shows, the \
            period it depicts, and its historical significance. Note any \
            visible labels, dates, or place names. If the image is ambiguous, \
            state what is and is not inferable.
            """
        case .language:
            return """
            Treat this image as foreign-language content (a sign, menu, \
            textbook page, etc.). Transcribe the visible text in its \
            original language exactly. Then translate it into the user's \
            chosen output language. Explain key grammar or vocabulary the \
            learner is likely to find useful. If the script is unfamiliar, \
            describe it.
            """
        case .computerScience:
            return """
            Treat this image as code, a terminal output, or a developer \
            error message. Transcribe the code or error exactly. Identify \
            the language. Explain what the code does or what the error \
            means, line by line where useful. If the user asks for a fix, \
            propose a corrected version and explain the change.
            """
        case .arts:
            return """
            Treat this image as a work of art, a piece of sheet music, or a \
            performing-arts technique. If it is sheet music, identify the \
            key, time signature, and any notable markings, then describe \
            how a beginner might play or sing it. If it is visual art, \
            identify period/medium/style if possible and describe \
            composition and technique. Be specific about what is visible.
            """
        }
    }

    /// Suggested prompt chips shown under the image preview.
    var suggestedPrompts: [String] {
        switch self {
        case .universal: return [
            "What is this and what should I know?",
            "Explain this to me",
            "Read it out loud"
        ]
        case .math: return [
            "Solve this step by step",
            "Check my work",
            "Explain the concept"
        ]
        case .science: return [
            "Explain this diagram",
            "What's happening here?",
            "Define the key terms"
        ]
        case .reading: return [
            "Summarize this passage",
            "What do the hard words mean?",
            "What is the main idea?"
        ]
        case .history: return [
            "What does this show?",
            "What period is this from?",
            "Why is it important?"
        ]
        case .language: return [
            "Translate this",
            "Pronounce it for me",
            "Explain the grammar"
        ]
        case .computerScience: return [
            "Explain this code",
            "What's the bug?",
            "Suggest a fix"
        ]
        case .arts: return [
            "Describe this work",
            "How was it made?",
            "How would I play this?"
        ]
        }
    }
}
