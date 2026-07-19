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

    func testPremiumChatRendersAtIPhone6sPlusLandscapeViewport() throws {
        let image = try renderChat(size: CGSize(width: 736, height: 414), populated: true)
        XCTAssertEqual(image.size, CGSize(width: 736, height: 414))
        XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 20_000)
        attach(image, name: "chat-736x414-light")
    }

    func testPremiumChatRendersAtIPhone6sPlusWithAccessibilityText() throws {
        let image = try renderChat(
            size: CGSize(width: 414, height: 736),
            populated: true,
            sizeCategory: .accessibilityMedium
        )
        XCTAssertEqual(image.size, CGSize(width: 414, height: 736))
        XCTAssertGreaterThan(try XCTUnwrap(image.pngData()).count, 20_000)
        attach(image, name: "chat-414x736-accessibility-medium")
    }

    private func renderChat(
        size: CGSize,
        populated: Bool,
        style: UIUserInterfaceStyle = .light,
        sizeCategory: ContentSizeCategory = .large
    ) throws -> UIImage {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "visual-\(UUID().uuidString)"))
        let repository = InMemoryConversationRepository()
        let model = AppModel(
            repository: repository,
            settings: AppSettings(defaults: suite),
            defaults: suite
        )
        model.configureForVisualTesting(populated: populated)

        let colorScheme: ColorScheme = style == .dark ? .dark : .light
        let controller = UIHostingController(
            rootView: ChatView()
                .environmentObject(model)
                .environment(\.colorScheme, colorScheme)
                .environment(\.sizeCategory, sizeCategory)
        )
        controller.overrideUserInterfaceStyle = style
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = style
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
