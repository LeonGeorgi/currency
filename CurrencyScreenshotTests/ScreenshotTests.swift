import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {
    func testLocalizedScreenshots() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let languages = [("de", "de_DE"), ("en", "en_US"), ("ja", "ja_JP"), ("es", "es_ES"), ("fr", "fr_FR")]

        for (language, locale) in languages {
            let app = XCUIApplication()
            app.launchArguments = ["--screenshots", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
            app.launch()
            waitForRates(in: app)
            capture("\(language)--overview-light")

            app.buttons["comparison-JPY"].tap()
            XCTAssertTrue(app.staticTexts["history-summary"].waitForExistence(timeout: 10))
            capture("\(language)--history")

            app.navigationBars.buttons.element(boundBy: 0).tap()
            app.buttons["edit-currencies"].tap()
            XCTAssertFalse(app.buttons["comparison-USD"].exists)
            capture("\(language)--editing")
            app.terminate()

            app.launchArguments.append("--screenshot-dark")
            app.launch()
            waitForRates(in: app)
            capture("\(language)--overview-dark")
            app.terminate()
        }
    }

    private func waitForRates(in app: XCUIApplication) {
        let comparison = app.buttons["comparison-USD"]
        XCTAssertTrue(comparison.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "116"), object: comparison)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
    }

    private func capture(_ name: String) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let window = XCUIApplication().windows.firstMatch
        let bannerStart = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12))
        let top = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.01))

        @MainActor func hasSystemBanner() -> Bool {
            springboard.otherElements["NotificationShortLookView"].exists ||
                springboard.descendants(matching: .any).matching(
                    NSPredicate(format: "label CONTAINS %@", "Ready for Apple Intelligence")
                ).firstMatch.exists
        }

        // Fresh simulator runtimes can announce that Apple Intelligence is ready.
        // Swipe the banner area upward; without a banner this only touches the navigation bar.
        // Check both sides of the screenshot to catch notifications arriving during capture.
        for _ in 0..<3 {
            bannerStart.press(forDuration: 0.05, thenDragTo: top)
            Thread.sleep(forTimeInterval: 0.4)
            guard !hasSystemBanner() else { continue }
            let screenshot = XCUIScreen.main.screenshot()
            guard !hasSystemBanner() else { continue }
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            return
        }
        XCTFail("A system notification is covering screenshot \(name)")
    }
}
