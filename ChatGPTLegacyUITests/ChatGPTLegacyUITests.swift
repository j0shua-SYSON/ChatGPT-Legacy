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
        dismissKeyboardTutorialIfNeeded()
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
        signalVideoTour("READY")
        // simctl can need several seconds before it emits its first encoded
        // frame. Hold the opening chat so the released tour starts in-app at
        // the beginning instead of joining midway through the menu sequence.
        pauseForVideo(6.0)
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
        dismissKeyboardTutorialIfNeeded()

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
        pauseForVideo(1.0)
        signalVideoTour("FINISHED")
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

    func testOAuthDeviceCodeScreenFitsAndKeepsActionsReachable() {
        launch(arguments: ["-uiTesting", "-uiTestDeviceCode"])

        XCTAssertTrue(app.staticTexts["login.code"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["login.code"].label, "ABCD-EFGH")
        XCTAssertTrue(app.buttons["login.open"].isHittable)
        XCTAssertTrue(app.buttons["login.cancel"].isHittable)
        capture("oauth-device-code")
    }

    func testDarkModeKeepsPremiumChatReadableAndReachable() {
        app.launchEnvironment["UITEST_COLOR_SCHEME"] = "dark"
        launch(arguments: ["-uiTesting", "-uiTestSignedIn", "-uiTestPopulated"])

        XCTAssertTrue(app.buttons["chat.history"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["chat.history"].isHittable)
        XCTAssertTrue(app.buttons["composer.add"].isHittable)
        XCTAssertGreaterThanOrEqual(
            app.otherElements.matching(identifier: "message.assistant").count,
            1
        )
        capture("chat-dark")
    }

    func testLandscapeKeepsNavigationAndComposerReachable() {
        defer { XCUIDevice.shared.orientation = .portrait }
        launch(arguments: ["-uiTesting", "-uiTestSignedIn", "-uiTestPopulated"])

        XCTAssertTrue(app.buttons["chat.history"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(waitForLandscape(timeout: 5))
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        _ = app.screenshot()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        XCTAssertTrue(app.buttons["chat.history"].isHittable)
        XCTAssertTrue(app.buttons["chat.actions"].isHittable)
        XCTAssertTrue(app.buttons["composer.add"].isHittable)
        XCTAssertTrue(app.textViews["composer.text"].isHittable)
        capture("chat-landscape")
    }

    func testStopThenImmediateResendKeepsReplacementStreamActive() {
        launch(arguments: [
            "-uiTesting",
            "-uiTestSignedIn",
            "-uiTestDelayFirstToken"
        ])

        let composer = app.textViews["composer.text"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        dismissKeyboardTutorialIfNeeded()
        composer.typeText("First request")
        app.buttons["composer.send"].tap()

        let stop = app.buttons["composer.stop"]
        XCTAssertTrue(stop.waitForExistence(timeout: 2))
        stop.tap()
        XCTAssertTrue(app.buttons["composer.send"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.otherElements["message.assistant"].waitForNonExistence(timeout: 2),
            "Stopping before the first token must not leave a blank response"
        )

        composer.tap()
        composer.typeText("Replacement request")
        app.buttons["composer.send"].tap()
        XCTAssertTrue(stop.waitForExistence(timeout: 2))
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        XCTAssertTrue(stop.exists, "The cancelled task must not clear the replacement stream")
        XCTAssertTrue(app.buttons["composer.send"].waitForExistence(timeout: 8))
    }

    func testSignedOutSurfacePassesAutomatedAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("XCTest accessibility audits require iOS 17 or later")
        }

        launch(arguments: ["-uiTesting"])
        XCTAssertTrue(app.buttons["login.continue"].waitForExistence(timeout: 5))
        try auditCurrentSurface()
    }

    func testOAuthDeviceCodeSurfacePassesAutomatedAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("XCTest accessibility audits require iOS 17 or later")
        }

        launch(arguments: ["-uiTesting", "-uiTestDeviceCode"])
        XCTAssertTrue(app.staticTexts["login.code"].waitForExistence(timeout: 5))
        try auditCurrentSurface()
    }

    func testChatSurfacePassesAutomatedAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("XCTest accessibility audits require iOS 17 or later")
        }

        launch(arguments: ["-uiTesting", "-uiTestSignedIn", "-uiTestPopulated"])
        XCTAssertTrue(app.buttons["chat.history"].waitForExistence(timeout: 5))
        try auditCurrentSurface()
    }

    func testHistorySurfacePassesAutomatedAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("XCTest accessibility audits require iOS 17 or later")
        }

        launch(arguments: ["-uiTesting", "-uiTestSignedIn", "-uiTestPopulated"])
        XCTAssertTrue(app.buttons["chat.history"].waitForExistence(timeout: 5))
        app.buttons["chat.history"].tap()
        XCTAssertTrue(app.buttons["history.done"].waitForExistence(timeout: 3))
        try auditCurrentSurface()
    }

    func testPromptLibrarySurfacePassesAutomatedAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("XCTest accessibility audits require iOS 17 or later")
        }

        launch(arguments: ["-uiTesting", "-uiTestSignedIn", "-uiTestPopulated"])
        XCTAssertTrue(app.buttons["chat.actions"].waitForExistence(timeout: 5))
        app.buttons["chat.actions"].tap()
        app.buttons["Prompt library"].tap()
        XCTAssertTrue(app.buttons["prompts.cancel"].waitForExistence(timeout: 3))
        try auditCurrentSurface()
    }

    func testSettingsSurfacePassesAutomatedAccessibilityAudit() throws {
        guard #available(iOS 17.0, *) else {
            throw XCTSkip("XCTest accessibility audits require iOS 17 or later")
        }

        launch(arguments: ["-uiTesting", "-uiTestSignedIn", "-uiTestPopulated"])
        XCTAssertTrue(app.buttons["chat.actions"].waitForExistence(timeout: 5))
        app.buttons["chat.actions"].tap()
        app.buttons["Response settings"].tap()
        XCTAssertTrue(app.buttons["settings.done"].waitForExistence(timeout: 3))
        try auditCurrentSurface()
    }

    private func launch(arguments: [String]) {
        app.launchArguments = arguments
        app.launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "0"
        app.launch()
    }

    @available(iOS 17.0, *)
    private func auditCurrentSurface() throws {
        // Apple recommends continuing after an audit finding so one element
        // cannot hide the other issues on the same visible surface.
        continueAfterFailure = true
        try app.performAccessibilityAudit()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func dismissKeyboardTutorialIfNeeded() {
        let tutorialContinue = app.buttons["Continue"]
        if tutorialContinue.waitForExistence(timeout: 1) {
            tutorialContinue.tap()
            XCTAssertTrue(tutorialContinue.waitForNonExistence(timeout: 2))
        }
    }

    private func waitForLandscape(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let frame = app.windows.firstMatch.frame
            if frame.width > frame.height { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return false
    }

    private func pauseForVideo(_ duration: TimeInterval = 0.55) {
        RunLoop.current.run(until: Date().addingTimeInterval(duration))
    }

    private func signalVideoTour(_ state: String) {
        let marker = "CHATGPT_LEGACY_VIDEO_\(state)\n"
        FileHandle.standardError.write(Data(marker.utf8))
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
