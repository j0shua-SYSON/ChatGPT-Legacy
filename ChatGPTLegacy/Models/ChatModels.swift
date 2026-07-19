import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: ChatRole
    var text: String
    let createdAt: Date
    var attachments: [ChatAttachment]

    init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        createdAt: Date = Date(),
        attachments: [ChatAttachment] = []
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.attachments = attachments
    }

    private enum CodingKeys: String, CodingKey {
        case id, role, text, createdAt, attachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        role = try container.decode(ChatRole.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        attachments = try container.decodeIfPresent(
            [ChatAttachment].self,
            forKey: .attachments
        ) ?? []
    }
}

struct ChatAttachment: Identifiable, Codable, Equatable {
    let id: UUID
    let data: Data
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int

    init(
        id: UUID = UUID(),
        data: Data,
        mimeType: String = "image/jpeg",
        pixelWidth: Int,
        pixelHeight: Int
    ) {
        self.id = id
        self.data = data
        self.mimeType = mimeType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    var dataURL: String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }
}

struct ChatConversation: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        title: String = "New conversation",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [ChatMessage] = [],
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
        self.isPinned = isPinned
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, createdAt, updatedAt, messages, isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        messages = try container.decode([ChatMessage].self, forKey: .messages)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    mutating func updateTitleIfNeeded(from firstMessage: String) {
        guard title == "New conversation" else { return }

        let firstLine = firstMessage
            .split(whereSeparator: { $0.isNewline })
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !firstLine.isEmpty else { return }
        let limit = 38
        title = firstLine.count > limit
            ? String(firstLine.prefix(limit)).trimmingCharacters(in: .whitespaces) + "…"
            : firstLine
    }

    var markdownExport: String {
        var output = "# \(title)\n\n"
        output += "_Exported from ChatGPT Legacy_\n\n"
        for message in messages {
            output += "## \(message.role == .user ? "You" : "ChatGPT")\n\n"
            if !message.text.isEmpty {
                output += message.text + "\n\n"
            }
            if !message.attachments.isEmpty {
                output += "_[\(message.attachments.count) image attachment"
                output += message.attachments.count == 1 ? "]_\n\n" : "s]_\n\n"
            }
        }
        return output
    }
}

struct AccountProfile: Equatable {
    let email: String?
    let plan: String?
    let accountID: String?

    var displayName: String {
        email ?? "ChatGPT account"
    }

    var planLabel: String {
        guard let plan, !plan.isEmpty else { return "Subscription" }
        return plan.prefix(1).uppercased() + plan.dropFirst()
    }
}
