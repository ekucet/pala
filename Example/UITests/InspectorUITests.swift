import XCTest

final class InspectorUITests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["pala.bubble"].waitForExistence(timeout: 5))
        return app
    }

    private func openMenu(_ app: XCUIApplication) {
        app.buttons["pala.bubble"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.4))
    }

    /// Hub bubble → menu.
    func testHubMenu() {
        let app = launch()
        openMenu(app)
        XCTAssertTrue(app.buttons["pala.menu.UI Inspector"].exists)
        add(named: "doc-hub-menu")
    }

    /// Menu → UI Inspector → tap an element to browse. Even with Grid on, the
    /// inspector must show the APP element, not Pala's own overlay.
    func testInspectorFromHub() {
        let app = launch()
        openMenu(app)
        app.buttons["pala.menu.Grid"].tap()          // grid overlay on (menu stays)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        app.buttons["pala.menu.UI Inspector"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        app.staticTexts["loginButton"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        add(named: "doc-inspector")
        XCTAssertTrue(app.staticTexts["Sign In Button"].waitForExistence(timeout: 2),
                      "Inspector should show the app element")
        XCTAssertFalse(app.staticTexts["FramesOverlayView"].exists,
                       "Inspector must not inspect Pala's own overlays")
    }

    /// Menu → Inspect all (should outline SwiftUI-drawn elements too).
    func testInspectAll() {
        let app = launch()
        openMenu(app)
        app.buttons["pala.menu.Inspect all"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        add(named: "doc-inspect-all")
    }

    /// Menu → Grid + Show frames.
    func testLayoutOverlays() {
        let app = launch()
        openMenu(app)
        app.buttons["pala.menu.Grid"].tap()          // menu stays open (rebuilt)
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        app.buttons["pala.menu.Show frames"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        // close the menu to see the overlays cleanly
        app.buttons["pala.bubble"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        add(named: "doc-layout")
    }

    /// Regression: with the host app's sendEvent-observer window present, tapping a
    /// button must still fire its action (the log only appears if the tap worked).
    func testTapDeliveryWithObserverWindow() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["taps: 0"].waitForExistence(timeout: 3))
        app.buttons["logButton"].tap()
        // The counter only changes if the tap actually reached the button.
        XCTAssertTrue(app.staticTexts["taps: 1"].waitForExistence(timeout: 2),
                      "Tap did not reach the button — event delivery is broken")
    }

    /// Does palaInspect still register when applied INSIDE a custom modifier
    /// (like the host app's TypographyModifier)?
    func testInspectInsideCustomModifier() {
        let app = launch()
        openMenu(app)
        app.buttons["pala.menu.UI Inspector"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        app.staticTexts["typoTest"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        add(named: "doc-typo-modifier")
        XCTAssertTrue(app.staticTexts["DemoTypo"].waitForExistence(timeout: 2),
                      "palaInspect inside a custom modifier did not register")
    }

    /// The bridge path: a modifier that writes to Pala's shared store WITHOUT
    /// importing Pala must still surface the font in the inspector card.
    func testBridgeCaptureWithoutImport() {
        let app = launch()
        openMenu(app)
        app.buttons["pala.menu.UI Inspector"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        app.staticTexts["bridgeTest"].tap()
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        add(named: "doc-bridge")
        XCTAssertTrue(app.staticTexts["Courier · 18pt"].waitForExistence(timeout: 2),
                      "Bridge-written font did not surface in the inspector card")
    }

    private func add(named name: String) {
        let att = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }
}
