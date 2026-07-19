import XCTest

final class ChatGPTLegacyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testSignedOutOAuthScreenFitsAndExplainsTrust() {
        launch(arguments: ["-uiTesting"])

        let continueButton = app.buttons["login.continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))
        XCTAssertTrue(continueButton.isHittable)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.width, 320)
        XCTAssertGreaterThan(app.windows.firstMatch.frame.height, 568)
        XCTAssertTrue(app.otherElements["login.trustRail"].exists)
        XCTAssertTrue(app.staticTexts["No API key"].exists)
        XCTAssertTrue(app.staticTexts["Keychain protected"].exists)
        capture("signed-out-oauth")
    }

    func testEmptyConversationPresetAndStreamingResponse() {
        launch(arguments: ["-uiTesting", "-uiTestSignedIn"])

        let preset = app.buttons["empty.preset.explain"]
        XCTAssertTrue(preset.waitForExistence(timeout: 5))
        preset.tap()

        let composer = app.textViews["composer.text"]
        XCTAssertTrue(composer.waitForExistence(timeout: 2))
        XCTAssertTrue((composer.value as? String)?.contains("first principles") == true)
        capture("empty-preset-filled")

        app.buttons["composer.send"].tap()
        XCTAssertTrue(app.buttons["composer.stop"].waitForExistence(timeout: 2))
        capture("streaming-response")
        XCTAssertTrue(app.buttons["composer.send"].waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(app.otherElements.matching(identifier: "message.assistant").count, 1)
    }

    func testHistorySearchAndRenameFlow() {
        launch(arguments: ["-uiTesting", "-uiTestSignedIn", "-uiTestPopulated"])

        let historyButton = app.buttons["chat.history"]
        XCTAssertTrue(historyButton.waitForExistence(timeout: 5))
        historyButton.tap()
        XCTAssertTrue(app.buttons["history.done"].waitForExistence(timeout: 3))
        let search = app.textFields["history.search"]
        search.tap()
        search.typeText("launch")
        XCTAssertTrue(app.staticTexts["A careful launch plan"].exists)
        capture("history-search")
        search.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 2))

        let actions = app.buttons["Actions for A careful launch plan"]
        XCTAssertTrue(actions.exists)
        actions.tap()
        app.buttons["Rename"].tap()
        let title = app.textFields["rename.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        title.selectAllAndType("Release confidence")
        app.buttons["rename.save"].tap()
        XCTAssertTrue(app.staticTexts["Release confidence"].waitForExistence(timeout: 3))
    }

    func testPremiumUITour() {
        launch(arguments: ["-uiTesting", "-uiTestSignedIn", "-uiTestPopulated"])

        XCTAssertTrue(app.buttons["chat.history"].waitForExistence(timeout: 5))
        capture("tour-01-chat")
        pauseForVideo()

        app.buttons["chat.history"].tap()
        XCTAssertTrue(app.buttons["history.done"].waitForExistence(timeout: 3))
        capture("tour-02-history")
        pauseForVideo()
        app.buttons["history.done"].tap()

        app.buttons["chat.actions"].tap()
        app.buttons["Prompt library"].tap()
        XCTAssertTrue(app.buttons["prompts.cancel"].waitForExistence(timeout: 3))
        capture("tour-03-prompts")
        pauseForVideo()
        app.buttons["prompts.item.decide"].tap()

        let composer = app.textViews["composer.text"]
        XCTAssertTrue(composer.waitForExistence(timeout: 3))
        capture("tour-04-composer")
        app.buttons["composer.send"].tap()
        XCTAssertTrue(app.buttons["composer.stop"].waitForExistence(timeout: 2))
        pauseForVideo()
        capture("tour-05-streaming")
        XCTAssertTrue(app.buttons["composer.send"].waitForExistence(timeout: 5))

        app.buttons["chat.actions"].tap()
        app.buttons["Response settings"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 3))
        capture("tour-06-settings")
        pauseForVideo()
        app.buttons["settings.done"].tap()
        XCTAssertTrue(app.buttons["chat.history"].waitForExistence(timeout: 3))
        capture("tour-07-finished")
    }

    func testAccessibilityTextSizeKeepsPrimaryControlsReachable() {
        launch(arguments: [
            "-uiTesting",
            "-uiTestSignedIn",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityMedium"
        ])

        XCTAssertTrue(app.buttons["chat.history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chat.history"].isHittable)
        XCTAssertTrue(app.buttons["chat.new"].isHittable)
        XCTAssertTrue(app.buttons["composer.add"].isHittable)
        XCTAssertTrue(app.buttons["composer.mic"].isHittable)
        capture("accessibility-medium")
    }

    private func launch(arguments: [String]) {
        app.launchArguments = arguments
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "0"
        app.launch()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pauseForVideo() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.55))
    }
}

private extension XCUIElement {
    func selectAllAndType(_ text: String) {
        tap()
        press(forDuration: 1.0)
        let selectAll = XCUIApplication().menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 1) {
            selectAll.tap()
        }
        typeText(text)
    }
}
