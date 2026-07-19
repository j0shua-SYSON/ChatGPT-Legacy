import XCTest
@testable import ChatGPTLegacy

final class ResponsePayloadTests: XCTestCase {
    func testBuildsMultimodalConversationPayload() throws {
        let attachment = ChatAttachment(
            data: Data([0x01, 0x02, 0x03]),
            pixelWidth: 32,
            pixelHeight: 24
        )
        let messages = [
            ChatMessage(role: .user, text: "What is this?", attachments: [attachment]),
            ChatMessage(role: .assistant, text: "It is a test image."),
            ChatMessage(role: .user, text: "Summarize that.")
        ]
        let model = CatalogModel(
            slug: "gpt-test",
            displayName: "GPT Test",
            defaultReasoningLevel: "medium"
        )
        let options = ChatRequestOptions(
            instructions: "Be useful.",
            responseStyle: .detailed,
            reasoning: .high
        )

        let payload = OpenAIChatService.responsePayload(
            messages: messages,
            model: model,
            options: options,
            conversationID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        )

        XCTAssertEqual(payload["model"] as? String, "gpt-test")
        XCTAssertEqual(payload["stream"] as? Bool, true)
        XCTAssertEqual((payload["reasoning"] as? [String: Any])?["effort"] as? String, "high")
        XCTAssertEqual((payload["text"] as? [String: Any])?["verbosity"] as? String, "high")

        let input = try XCTUnwrap(payload["input"] as? [[String: Any]])
        XCTAssertEqual(input.count, 3)
        XCTAssertEqual(input[1]["role"] as? String, "assistant")
        let firstContent = try XCTUnwrap(input[0]["content"] as? [[String: Any]])
        XCTAssertEqual(firstContent.map { $0["type"] as? String }, ["input_text", "input_image"])
        XCTAssertTrue(
            (firstContent[1]["image_url"] as? String)?.hasPrefix("data:image/jpeg;base64,") == true
        )
    }

    func testAutomaticReasoningUsesCatalogDefault() {
        let model = CatalogModel(
            slug: "gpt-test",
            displayName: "GPT Test",
            defaultReasoningLevel: "low"
        )
        let payload = OpenAIChatService.responsePayload(
            messages: [ChatMessage(role: .user, text: "Hello")],
            model: model,
            options: ChatRequestOptions(
                instructions: "Be useful.",
                responseStyle: .concise,
                reasoning: .automatic
            ),
            conversationID: UUID()
        )
        XCTAssertEqual((payload["reasoning"] as? [String: Any])?["effort"] as? String, "low")
    }
}
