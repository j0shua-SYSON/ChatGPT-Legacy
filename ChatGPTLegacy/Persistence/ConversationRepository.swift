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
        // Preserve the exact IEEE-754 value Foundation stores internally.
        // Converting through seconds-since-1970 loses a few low-order bits.
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let bits = String(date.timeIntervalSinceReferenceDate.bitPattern, radix: 16)
            try container.encode("date-v1:\(bits)")
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let legacyFormatter = ISO8601DateFormatter()
        legacyFormatter.formatOptions = [.withInternetDateTime]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let interval = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: interval)
            }

            let value = try container.decode(String.self)
            if value.hasPrefix("date-v1:"),
               let bits = UInt64(value.dropFirst("date-v1:".count), radix: 16) {
                return Date(
                    timeIntervalSinceReferenceDate: Double(bitPattern: bits)
                )
            }
            if let date = fractionalFormatter.date(from: value) ?? legacyFormatter.date(from: value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected a Unix timestamp or ISO-8601 date."
            )
        }
        return decoder
    }()
}
