import SwiftUI
import XCTest
@testable import ChatGPTLegacy

@MainActor
final class VisualLayoutTests: XCTestCase {
    func testPremiumChatRendersAtIPhone6sPlusViewport() throws {
        let image = try renderChat(size: CGSize(width: 414, height: 736), populated: true)
        XCTAssertEqual(image.size, CGSize(width: 414, height: 736))
        XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 20_000)
        attach(image, name: "chat-414x736-light")
    }

    func testEmptyChatRendersAtCompactLegacyViewport() throws {
        let image = try renderChat(size: CGSize(width: 320, height: 568), populated: false)
        XCTAssertEqual(image.size, CGSize(width: 320, height: 568))
        XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 15_000)
        attach(image, name: "chat-320x568-light")
    }

    func testPremiumChatRendersAtIPhone6sPlusViewportInDarkMode() throws {
        let image = try renderChat(
            size: CGSize(width: 414, height: 736),
            populated: true,
            style: .dark
        )
        XCTAssertEqual(image.size, CGSize(width: 414, height: 736))
        XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 20_000)
        attach(image, name: "chat-414x736-dark")
    }

    private func renderChat(
        size: CGSize,
        populated: Bool,
        style: UIUserInterfaceStyle = .light
    ) throws -> UIImage {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "visual-\(UUID().uuidString)"))
        let repository = InMemoryConversationRepository()
        let model = AppModel(
            repository: repository,
            settings: AppSettings(defaults: suite),
            defaults: suite
        )
        model.configureForVisualTesting(populated: populated)

        let controller = UIHostingController(
            rootView: ChatView().environmentObject(model)
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = style
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        window.isHidden = true
        return image
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private final class InMemoryConversationRepository: ConversationPersisting {
    private var storage: [ChatConversation] = []
    func load() throws -> [ChatConversation] { storage }
    func save(_ conversations: [ChatConversation]) throws { storage = conversations }
}
