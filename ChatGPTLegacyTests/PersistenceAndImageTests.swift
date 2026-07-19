import UIKit
import XCTest
@testable import ChatGPTLegacy

final class PersistenceAndImageTests: XCTestCase {
    func testConversationRoundTripAndMarkdownExport() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = ConversationRepository(
            fileURL: directory.appendingPathComponent("conversations.json")
        )
        let conversation = ChatConversation(
            title: "Release notes",
            messages: [
                ChatMessage(role: .user, text: "Ship it"),
                ChatMessage(role: .assistant, text: "After the tests pass.")
            ],
            isPinned: true
        )

        try repository.save([conversation])
        let loaded = try repository.load()

        XCTAssertEqual(loaded, [conversation])
        XCTAssertTrue(loaded[0].markdownExport.contains("## ChatGPT"))
        XCTAssertTrue(loaded[0].markdownExport.contains("After the tests pass."))
    }

    func testLegacyHistoryDefaultsNewFields() throws {
        let json = #"[{"id":"00000000-0000-0000-0000-000000000001","title":"Old","createdAt":"2026-01-01T00:00:00Z","updatedAt":"2026-01-01T00:00:00Z","messages":[{"id":"00000000-0000-0000-0000-000000000002","role":"user","text":"Hi","createdAt":"2026-01-01T00:00:00Z"}]}]"#
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let fileURL = directory.appendingPathComponent("conversations.json")
        try Data(json.utf8).write(to: fileURL)

        let decoded = try ConversationRepository(fileURL: fileURL).load()

        XCTAssertFalse(decoded[0].isPinned)
        XCTAssertTrue(decoded[0].messages[0].attachments.isEmpty)
    }

    func testImageProcessorBoundsLargeImages() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3_200, height: 2_000)).image {
            UIColor.systemTeal.setFill()
            $0.cgContext.fill(CGRect(x: 0, y: 0, width: 3_200, height: 2_000))
        }

        let attachment = try ImageAttachmentProcessor.process(image)

        XCTAssertEqual(attachment.pixelWidth, 1_600)
        XCTAssertEqual(attachment.pixelHeight, 1_000)
        XCTAssertFalse(attachment.data.isEmpty)
        XCTAssertLessThan(attachment.data.count, 2_000_000)
    }
}
