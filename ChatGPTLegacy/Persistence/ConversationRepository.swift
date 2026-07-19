import Foundation

protocol ConversationPersisting {
    func load() throws -> [ChatConversation]
    func save(_ conversations: [ChatConversation]) throws
}

final class ConversationRepository: ConversationPersisting {
    private let fileURL: URL
    private let fileManager: FileManager

    convenience init() {
        let fileManager = FileManager.default
        let supportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        self.init(
            fileURL: supportDirectory
                .appendingPathComponent("ChatGPTLegacy", isDirectory: true)
                .appendingPathComponent("conversations.json"),
            fileManager: fileManager
        )
    }

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func load() throws -> [ChatConversation] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try Self.decoder.decode([ChatConversation].self, from: data)
    }

    func save(_ conversations: [ChatConversation]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let data = try Self.encoder.encode(conversations)
        try data.write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
