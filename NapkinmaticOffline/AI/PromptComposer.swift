import Foundation

/// Assembles a fully-formed system prompt and user message for a given
/// (subject, style, language, custom question) tuple.
///
/// Replaces the old static `PromptTemplates` struct.
enum PromptComposer {
    /// The fixed Lumen identity preamble that prefixes every system prompt.
    private static let identity: String = """
    You are Lumen, a private on-device tutor for any subject. You run \
    entirely on the user's iPhone — nothing they show you ever leaves the \
    device. Be patient, encouraging, and concise. Answer only from what is \
    visible in the supplied image and the user's prompt; never invent \
    details that are not present. If something is unclear, say so.
    """

    /// Builds the full system instruction string.
    static func systemInstruction(
        subject: SubjectMode,
        style: AnswerStyle,
        language: OutputLanguage
    ) -> String {
        return [
            identity,
            "SUBJECT MODE: \(subject.title)",
            subject.systemInstructionFragment,
            "RESPONSE STYLE: \(style.title)",
            style.systemInstructionFragment,
            "OUTPUT LANGUAGE: \(language.englishName)",
            language.systemInstructionFragment
        ].joined(separator: "\n\n")
    }

    /// Builds the per-turn user prompt. If the user supplied a custom
    /// question, that is the prompt. Otherwise, fall back to the subject's
    /// default ("What is in this image?" for universal, etc.).
    static func userPrompt(
        subject: SubjectMode,
        customQuestion: String
    ) -> String {
        let trimmed = customQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return subject.suggestedPrompts.first ?? "Explain what is in this image."
    }
}
