import Foundation

/// How Lumen should respond — pedagogically, not just informationally.
enum AnswerStyle: String, CaseIterable, Identifiable, Codable {
    /// Show the full answer with every working step.
    case directWithSteps
    /// Don't give the answer. Ask one guiding question at a time.
    case socratic
    /// Just the answer, briefly. No steps. No questions.
    case quickAnswer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .directWithSteps: return "Step by step"
        case .socratic: return "Coach me"
        case .quickAnswer: return "Just the answer"
        }
    }

    var subtitle: String {
        switch self {
        case .directWithSteps: return "Show every step of the working."
        case .socratic: return "Ask me guiding questions instead of solving."
        case .quickAnswer: return "Give the shortest correct answer."
        }
    }

    var systemImage: String {
        switch self {
        case .directWithSteps: return "list.number"
        case .socratic: return "questionmark.bubble"
        case .quickAnswer: return "bolt"
        }
    }

    /// Pedagogical instruction injected into the system prompt.
    var systemInstructionFragment: String {
        switch self {
        case .directWithSteps:
            return """
            Respond with a complete, correct answer. Show every step of \
            your reasoning, numbered "Step 1:", "Step 2:", etc. After the \
            steps, state the final answer on its own line, prefixed with \
            "Answer:". If the question is not solvable from what's visible, \
            say what is missing.
            """
        case .socratic:
            return """
            Do NOT give the final answer. Instead, ask the learner ONE \
            short guiding question that helps them take the next step on \
            their own. Acknowledge anything correct they have already \
            shown. After your question, briefly explain what concept they \
            should be thinking about. Keep your reply under 80 words. \
            Never reveal the final answer, even if asked directly — \
            instead, ask another guiding question.
            """
        case .quickAnswer:
            return """
            Respond with only the final answer, in one or two short \
            sentences. No working, no steps, no preamble. If the answer \
            is a number or short phrase, lead with it.
            """
        }
    }
}
