import Combine
import Foundation

enum ResponseStyle: String, CaseIterable, Identifiable {
    case concise
    case balanced
    case detailed

    var id: String { rawValue }

    var label: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    var instruction: String {
        switch self {
        case .concise:
            return "Prefer compact answers. Lead with the answer and omit unnecessary framing."
        case .balanced:
            return "Use enough detail to be useful while keeping the response easy to scan."
        case .detailed:
            return "Give thorough explanations, relevant context, and concrete examples when useful."
        }
    }

    var verbosityValue: String {
        switch self {
        case .concise: return "low"
        case .balanced: return "medium"
        case .detailed: return "high"
        }
    }
}

enum ReasoningChoice: String, CaseIterable, Identifiable {
    case automatic
    case low
    case medium
    case high
    case extraHigh

    var id: String { rawValue }

    var label: String {
        switch self {
        case .automatic: return "Automatic"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .extraHigh: return "Extra high"
        }
    }

    var apiValue: String? {
        switch self {
        case .automatic: return nil
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .extraHigh: return "xhigh"
        }
    }
}

final class AppSettings: ObservableObject {
    @Published var responseStyle: ResponseStyle {
        didSet { defaults.set(responseStyle.rawValue, forKey: Keys.responseStyle) }
    }
    @Published var reasoning: ReasoningChoice {
        didSet { defaults.set(reasoning.rawValue, forKey: Keys.reasoning) }
    }
    @Published var customInstructions: String {
        didSet { defaults.set(customInstructions, forKey: Keys.customInstructions) }
    }
    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.hapticsEnabled) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        responseStyle = ResponseStyle(
            rawValue: defaults.string(forKey: Keys.responseStyle) ?? ""
        ) ?? .balanced
        reasoning = ReasoningChoice(
            rawValue: defaults.string(forKey: Keys.reasoning) ?? ""
        ) ?? .automatic
        customInstructions = defaults.string(forKey: Keys.customInstructions) ?? ""
        hapticsEnabled = defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
    }

    var requestInstructions: String {
        var instructions = [
            "You are ChatGPT in a native iOS chat client. Be helpful, accurate, and direct.",
            responseStyle.instruction
        ]
        let custom = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !custom.isEmpty {
            instructions.append("User preferences:\n\(custom)")
        }
        return instructions.joined(separator: "\n\n")
    }

    private enum Keys {
        static let responseStyle = "settings.responseStyle"
        static let reasoning = "settings.reasoning"
        static let customInstructions = "settings.customInstructions"
        static let hapticsEnabled = "settings.hapticsEnabled"
    }
}

struct PromptPreset: Identifiable, Equatable {
    let id: String
    let category: String
    let title: String
    let prompt: String

    static let builtIn: [PromptPreset] = [
        PromptPreset(
            id: "explain",
            category: "Learn",
            title: "Explain it clearly",
            prompt: "Explain this from first principles, then give me a concrete example:\n"
        ),
        PromptPreset(
            id: "study",
            category: "Learn",
            title: "Make a study guide",
            prompt: "Turn the following material into a focused study guide with key ideas, recall questions, and a short quiz:\n"
        ),
        PromptPreset(
            id: "decide",
            category: "Think",
            title: "Untangle a decision",
            prompt: "Help me make this decision. Clarify the real tradeoffs, challenge my assumptions, and recommend a next step:\n"
        ),
        PromptPreset(
            id: "critique",
            category: "Think",
            title: "Pressure-test an idea",
            prompt: "Pressure-test this idea. Identify hidden assumptions, likely failure modes, and the smallest useful experiment:\n"
        ),
        PromptPreset(
            id: "draft",
            category: "Write",
            title: "Draft from rough notes",
            prompt: "Turn these rough notes into a clear, natural draft. Preserve my meaning and avoid generic filler:\n"
        ),
        PromptPreset(
            id: "rewrite",
            category: "Write",
            title: "Sharpen my writing",
            prompt: "Rewrite this for clarity and flow. Keep the tone human and explain the most important edits afterward:\n"
        ),
        PromptPreset(
            id: "image",
            category: "See",
            title: "Analyze an image",
            prompt: "Study the attached image carefully. Describe the important details, then answer my question:\n"
        ),
        PromptPreset(
            id: "plan",
            category: "Do",
            title: "Build a practical plan",
            prompt: "Turn this goal into a realistic plan with milestones, risks, and the first three concrete actions:\n"
        )
    ]
}
