import XCTest

@MainActor
final class ScreenshotTests: XCTestCase {
    func testAppearanceAndAlternateIconsPersist() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--screenshots", "--test-app-icons", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        waitForRates(in: app)

        func openSettings() {
            app.buttons["Mehr"].tap()
            app.buttons["open-settings"].tap()
            XCTAssertTrue(app.buttons["accent-original"].waitForExistence(timeout: 5))
        }

        func colorButton(_ color: String) -> XCUIElement {
            let button = app.buttons["accent-\(color)"]
            for _ in 0..<5 {
                if button.isHittable { break }
                app.swipeDown()
            }
            for _ in 0..<5 {
                if button.isHittable { break }
                app.swipeUp()
            }
            return button
        }

        func select(_ color: String) {
            let button = colorButton(color)
            button.tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let systemAlert = springboard.alerts.firstMatch
            if systemAlert.waitForExistence(timeout: 3) {
                systemAlert.buttons.firstMatch.tap()
                XCTAssertTrue(systemAlert.waitForNonExistence(timeout: 5))
            }
            let appAlert = app.alerts.firstMatch
            if appAlert.exists {
                XCTAssertFalse(app.alerts["Die Farbe konnte nicht geändert werden."].exists)
                appAlert.buttons.firstMatch.tap()
                XCTAssertTrue(appAlert.waitForNonExistence(timeout: 5))
            }
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 10), .completed)
            XCTAssertFalse(app.alerts["Die Farbe konnte nicht geändert werden."].exists)
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true AND enabled == true"), object: button)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 10), .completed)
        }

        openSettings()
        select("orange")
        select("blue")
        XCTAssertEqual(app.images["current-icon-preview"].value as? String, "Blau")
        let settingsImage = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        settingsImage.name = "appearance-blue-settings"
        settingsImage.lifetime = .keepAlways
        add(settingsImage)
        app.buttons["Fertig"].tap()
        let overviewImage = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        overviewImage.name = "appearance-blue-overview"
        overviewImage.lifetime = .keepAlways
        add(overviewImage)
        app.terminate()
        app.launchArguments.append("--keep-screenshot-settings")
        app.launch()
        waitForRates(in: app)
        openSettings()
        XCTAssertTrue(colorButton("blue").isSelected)
        for _ in 0..<5 {
            if app.buttons["accent-original"].isHittable { break }
            app.swipeDown()
        }
        select("original")
        app.buttons["Fertig"].tap()
        app.terminate()
    }

    func testAmountPresets() {
        let app = XCUIApplication()
        app.launchArguments = ["--screenshots", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        waitForRates(in: app)
        let presets = app.scrollViews["amount-presets"]
        XCTAssertTrue(presets.waitForExistence(timeout: 5))
        let twenty = app.buttons["amount-preset-20.0"]
        XCTAssertTrue(twenty.waitForExistence(timeout: 5))
        twenty.tap()
        XCTAssertTrue(twenty.isSelected)
        XCTAssertEqual((app.textFields.firstMatch.value as? String)?.replacingOccurrences(of: "\u{00a0}", with: " "), "20 €")
        XCTAssertTrue(app.buttons["comparison-JPY"].label.contains("3.289,6"))

        let one = app.buttons["amount-preset-1.0"]
        for _ in 0..<5 {
            if one.isHittable { break }
            presets.swipeRight()
        }
        XCTAssertTrue(one.isHittable)
        one.tap()
        XCTAssertTrue(one.isSelected)
        XCTAssertTrue(app.buttons["comparison-JPY"].label.contains("164,48"))

        app.buttons["JPY zur Hauptwährung machen"].tap()
        let hundred = app.buttons["amount-preset-100.0"]
        XCTAssertTrue(hundred.waitForExistence(timeout: 5))
        for _ in 0..<5 {
            if hundred.isHittable { break }
            presets.swipeRight()
        }
        hundred.tap()
        XCTAssertTrue(hundred.isSelected)
        XCTAssertEqual((app.textFields.firstMatch.value as? String)?.replacingOccurrences(of: "\u{00a0}", with: " "), "100 ¥")
        XCTAssertTrue(app.buttons["amount-preset-500.0"].exists)
        XCTAssertFalse(app.buttons["amount-preset-1.0"].exists)
        app.terminate()
    }

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
            let calculation = app.descendants(matching: .any).matching(identifier: "mental-calculation").firstMatch
            XCTAssertTrue(calculation.waitForExistence(timeout: 10))
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "mental-direction").firstMatch.exists)
            capture("\(language)--mental-math")
            for _ in 0..<5 {
                if app.switches["chart-starts-at-zero"].isHittable { break }
                app.swipeUp()
            }
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
