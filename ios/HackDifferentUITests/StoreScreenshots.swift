//
//  StoreScreenshots.swift
//  HackDifferentUITests
//

import XCTest

/// The App Store listing screenshots, signed in with an App Review code rather than anyone's own account.
///
/// Setup: turn App Review on for the Hack Different audience and add a code on the console's App Review card. The
/// code comes from the environment, never the repository:
///
///   HACKDIFFERENT_UITEST_REVIEW_CODE     the App Review code (required)
///   HACKDIFFERENT_UITEST_SCREENSHOT_DIR  also write each capture there as a PNG (the simulator shares the Mac's disk)
///   HACKDIFFERENT_UITEST_EVENT           an event to open, by name (default: the first in the list)
///   HACKDIFFERENT_UITEST_SPACE           a space to open, by name (default: the first in the list)
///
/// Scripts/store-screenshots.sh runs it on an iPhone and an iPad simulator. Otherwise pass the variables as
/// `TEST_RUNNER_<name>=…` to xcodebuild. The Debug build talks to production. Nothing is posted, RSVPed or deleted.
@MainActor
final class StoreScreenshots: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Location and notification prompts") { alert in
            for label in ["Allow While Using App", "Allow Once", "Allow", "Don’t Allow", "Don't Allow"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }
    }

    func testListingScreens() throws {
        let code = try Self.required("HACKDIFFERENT_UITEST_REVIEW_CODE")
        app.launch()
        signOutIfNeeded()
        capture("00-sign-in")
        signIn(code: code)

        open(tab: "Events")
        waitForContent("event.row")
        capture("01-events")
        if openRow("event.row", named: Self.value("HACKDIFFERENT_UITEST_EVENT")) {
            capture("02-event")
            back()
        }

        open(tab: "Spaces")
        waitForContent("space.row")
        capture("03-spaces")
        if openRow("space.row", named: Self.value("HACKDIFFERENT_UITEST_SPACE")) {
            capture("04-space")
            back()
        }

        open(tab: "Chat")
        waitForContent("chat.row")
        capture("05-chat")
        if openRow("chat.row", named: nil) {
            settle(3)
            capture("06-chat-room")
            back()
        }

        open(tab: "Profile")
        settle()
        capture("07-profile")
    }

    // MARK: - Sign-in

    private func signOutIfNeeded() {
        let profile = app.tabBars.buttons["Profile"]
        guard profile.waitForExistence(timeout: 8) else { return }
        profile.tap()
        let signOut = app.buttons["Sign Out"]
        XCTAssertTrue(scroll(to: signOut), "Profile › Sign Out didn't appear")
        signOut.tap()
    }

    private func signIn(code: String) {
        let link = app.buttons["Have an App Review code?"]
        XCTAssertTrue(link.waitForExistence(timeout: 20),
                      "No \"Have an App Review code?\": is App Review on for the Hack Different audience?")
        link.tap()
        let field = app.textFields["Enter review code"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(code)
        app.buttons["Sign In"].tap()
        XCTAssertTrue(app.tabBars.buttons["Events"].waitForExistence(timeout: 30),
                      "The review code didn't sign in")
        app.tap() // lets the interruption monitor answer a location prompt
        settle()
    }

    // MARK: - Navigation

    private func open(tab: String) {
        let button = app.tabBars.buttons[tab]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "No \(tab) tab")
        button.tap()
        settle()
    }

    /// Opens the `identifier` row whose label contains `name`, or the first one.
    private func openRow(_ identifier: String, named name: String?) -> Bool {
        var rows = app.descendants(matching: .any).matching(identifier: identifier)
        if let name { rows = rows.matching(NSPredicate(format: "label CONTAINS[c] %@", name)) }
        let row = rows.firstMatch
        guard row.waitForExistence(timeout: 10), scroll(to: row) else { return false }
        row.tap()
        // A pushed screen has a back button; a loaded Mac can take well over the old fixed 2 s to push it.
        let pushed = app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: 15)
        settle(2)
        return pushed
    }

    private func back() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        settle()
    }

    private func waitForContent(_ identifier: String) {
        _ = app.descendants(matching: .any).matching(identifier: identifier).firstMatch.waitForExistence(timeout: 20)
        settle(2)
    }

    @discardableResult
    private func scroll(to element: XCUIElement, attempts: Int = 8) -> Bool {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    private func settle(_ seconds: TimeInterval = 1.5) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    // MARK: - Captures

    private func capture(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let dir = Self.value("HACKDIFFERENT_UITEST_SCREENSHOT_DIR") else { return }
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        let folder = URL(fileURLWithPath: dir).appendingPathComponent(device)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? shot.pngRepresentation.write(to: folder.appendingPathComponent("\(name).png"))
    }

    private static func value(_ name: String) -> String? {
        let value = ProcessInfo.processInfo.environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    private static func required(_ name: String) throws -> String {
        guard let value = value(name) else {
            throw XCTSkip("Set \(name) (TEST_RUNNER_\(name) for xcodebuild) to an App Review code")
        }
        return value
    }
}
