//
//  ReviewRecording.swift
//  HackDifferentUITests
//

import XCTest

/// The screen recording App Review asks for under Guideline 2.1: one unhurried pass through the app from launch,
/// signed in with an App Review code. Scripts/review-recording.sh records it on a simulator, or runs it on a plugged-in
/// iPhone (start the phone's Screen Recording during the countdown) for the final take.
///
/// It shows each flow the reviewer asked about without changing anyone else's data:
///   - launch, sign-in with the review code
///   - Events, an event's details, an RSVP (on the review account itself)
///   - Spaces and a space's details
///   - Chat: a read-only Discord room, Report and Block on someone's message (each dialog is shown, then cancelled,
///     so no real person is reported or blocked), and Reply on Discord
///   - Profile: My RSVPs, Connect Discord, Terms of Use, Privacy Policy, and Delete Account up to its confirmation,
///     cancelled so the review account keeps working
///
/// Settings come from the environment (`TEST_RUNNER_<name>` for xcodebuild), never the repository:
///
///   HACKDIFFERENT_UITEST_REVIEW_CODE   the App Review code (required)
///   HACKDIFFERENT_UITEST_START_DELAY   seconds on the home screen before launch (default 3), time to start recording
///   HACKDIFFERENT_UITEST_PACE          multiplies every pause (default 1; 1.5 reads more slowly)
///   HACKDIFFERENT_UITEST_EVENT         an event to open, by name (default: the first in the list)
///   HACKDIFFERENT_UITEST_SPACE         a space to open, by name (default: the first in the list)
///   HACKDIFFERENT_UITEST_ROOM          a chat room to open, by name (default: the first room with messages)
///   HACKDIFFERENT_UITEST_OPEN_LINKS    0 to skip opening Reply on Discord, Terms and Privacy in Safari
@MainActor
final class ReviewRecording: XCTestCase {
    private var app: XCUIApplication!
    private var pace: Double = 1

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        pace = Self.value("HACKDIFFERENT_UITEST_PACE").flatMap(Double.init) ?? 1
        addUIInterruptionMonitor(withDescription: "Location and notification prompts") { alert in
            for label in ["Allow While Using App", "Allow Once", "Allow", "Don’t Allow", "Don't Allow"] {
                let button = alert.buttons[label]
                if button.exists { button.tap(); return true }
            }
            return false
        }
    }

    func testReviewWalkthrough() throws {
        let code = try Self.required("HACKDIFFERENT_UITEST_REVIEW_CODE")

        // Start signed out, then put the home screen up so the recording begins before the app launches.
        app.launch()
        signOutIfNeeded()
        app.terminate()
        XCUIDevice.shared.press(.home)
        pause(Self.value("HACKDIFFERENT_UITEST_START_DELAY").flatMap(Double.init) ?? 3, scaled: false)

        app.launch()
        pause(2)
        signIn(code: code)

        events()
        spaces()
        chat()
        profile()
        pause(2)
    }

    // MARK: - The walkthrough

    private func events() {
        open(tab: "Events")
        waitForContent("event.row")
        pause(2)
        app.swipeUp(); pause(1); app.swipeDown(); pause(1)
        guard openRow("event.row", named: Self.value("HACKDIFFERENT_UITEST_EVENT")) else {
            XCTFail("No event to open"); return
        }
        pause(2)
        let going = app.buttons["Going"]
        if scroll(to: going) {
            pause(1)
            going.tap()
            pause(2.5)
        }
        app.swipeUp(); pause(1.5)
        back()
    }

    private func spaces() {
        open(tab: "Spaces")
        waitForContent("space.row")
        pause(2)
        guard openRow("space.row", named: Self.value("HACKDIFFERENT_UITEST_SPACE")) else {
            XCTFail("No space to open"); return
        }
        pause(2)
        app.swipeUp(); pause(1.5)
        back()
    }

    private func chat() {
        open(tab: "Chat")
        waitForContent("chat.row")
        pause(2)
        guard openRoomWithMessages() else { XCTFail("No chat room with someone else's message"); return }
        pause(2.5)

        // Report: show the reasons, then cancel.
        guard longPressOthersMessage(showing: "Report message") else {
            XCTFail("No Report message on anyone's message"); return
        }
        pause(1.5)
        app.buttons["Report message"].tap()
        pause(2.5)
        cancelDialog()

        // Block: only for senders with an account here; show the confirmation, then cancel.
        if longPressOthersMessage(showing: "Block") {
            pause(1.5)
            app.buttons["Block"].tap()
            pause(2.5)
            cancelDialog()
        }

        let reply = app.buttons["Reply on Discord"]
        if reply.waitForExistence(timeout: 5) {
            pause(1.5)
            if Self.openLinks {
                reply.tap()
                returnToApp()
            }
        }
        back()
    }

    private func profile() {
        open(tab: "Profile")
        pause(2.5)
        for label in ["Terms of Use", "Privacy Policy"] {
            let link = app.buttons[label].exists ? app.buttons[label] : app.links[label]
            guard scroll(to: link) else { continue }
            pause(1)
            if Self.openLinks {
                link.tap()
                returnToApp()
            }
        }
        let delete = app.buttons["Delete Account"]
        XCTAssertTrue(scroll(to: delete), "Profile › Delete Account didn't appear")
        pause(1.5)
        delete.tap()
        pause(3)
        cancelDialog()
        pause(1)
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists, "Cancelling Delete Account should keep the account")
    }

    // MARK: - Chat helpers

    /// Opens the named room, else the first room that shows someone else's message with Report on it.
    private func openRoomWithMessages() -> Bool {
        if let name = Self.value("HACKDIFFERENT_UITEST_ROOM") {
            return openRow("chat.row", named: name)
        }
        let rows = app.descendants(matching: .any).matching(identifier: "chat.row")
        for index in 0..<min(rows.count, 8) {
            let row = rows.element(boundBy: index)
            guard scroll(to: row) else { continue }
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
            _ = app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: 15)
            pause(3)
            if messageTexts().count > 0 { return true }
            back()
        }
        return false
    }

    /// Long-presses messages from the newest up until one's menu offers `action`, leaving that menu open.
    private func longPressOthersMessage(showing action: String) -> Bool {
        for text in messageTexts().reversed().prefix(8) {
            guard text.isHittable else { continue }
            text.press(forDuration: 1.2)
            if app.buttons[action].waitForExistence(timeout: 3) { return true }
            dismissMenu()
        }
        return false
    }

    /// The room's message bodies: longer static texts, without the room's own explanations.
    private func messageTexts() -> [XCUIElement] {
        let predicate = NSPredicate(
            format: "label.length > 12 AND NOT (label BEGINSWITH 'This room mirrors') AND NOT (label CONTAINS 'Discord channel')"
        )
        let texts = app.scrollViews.firstMatch.staticTexts.matching(predicate)
        return (0..<min(texts.count, 40)).map { texts.element(boundBy: $0) }.filter { $0.exists }
    }

    private func dismissMenu() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        pause(0.5)
    }

    private func cancelDialog() {
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 5) { cancel.tap() } else { dismissMenu() }
        pause(1.5)
    }

    // MARK: - Sign-in

    private func signOutIfNeeded() {
        let profile = app.tabBars.buttons["Profile"]
        guard profile.waitForExistence(timeout: 8) else { return }
        profile.tap()
        let signOut = app.buttons["Sign Out"]
        XCTAssertTrue(scroll(to: signOut), "Profile › Sign Out didn't appear")
        signOut.tap()
        _ = app.buttons["Have an App Review code?"].waitForExistence(timeout: 10)
    }

    private func signIn(code: String) {
        let link = app.buttons["Have an App Review code?"]
        XCTAssertTrue(link.waitForExistence(timeout: 20),
                      "No \"Have an App Review code?\": is App Review on for the Hack Different audience?")
        pause(1.5)
        link.tap()
        let field = app.textFields["Enter review code"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(code)
        pause(1)
        app.buttons["Sign In"].tap()
        XCTAssertTrue(app.tabBars.buttons["Events"].waitForExistence(timeout: 30),
                      "The review code didn't sign in")
        app.tap() // lets the interruption monitor answer a location prompt
        pause(2)
    }

    // MARK: - Navigation

    private func open(tab: String) {
        let button = app.tabBars.buttons[tab]
        XCTAssertTrue(button.waitForExistence(timeout: 10), "No \(tab) tab")
        button.tap()
        pause(1)
    }

    /// Opens the `identifier` row whose label contains `name`, or the first one.
    private func openRow(_ identifier: String, named name: String?) -> Bool {
        var rows = app.descendants(matching: .any).matching(identifier: identifier)
        if let name { rows = rows.matching(NSPredicate(format: "label CONTAINS[c] %@", name)) }
        let row = rows.firstMatch
        guard row.waitForExistence(timeout: 10), scroll(to: row) else { return false }
        // A centre tap on a space row doesn't open it under XCUITest; left of centre opens every row type.
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
        return app.navigationBars.buttons.element(boundBy: 0).waitForExistence(timeout: 15)
    }

    private func back() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
        pause(1.5)
    }

    /// A link opened Safari (or Discord): give it a moment on screen, then come back to the app.
    private func returnToApp() {
        pause(4)
        app.activate()
        _ = app.wait(for: .runningForeground, timeout: 10)
        pause(1.5)
    }

    private func waitForContent(_ identifier: String) {
        _ = app.descendants(matching: .any).matching(identifier: identifier).firstMatch.waitForExistence(timeout: 20)
        pause(1)
    }

    @discardableResult
    private func scroll(to element: XCUIElement, attempts: Int = 8) -> Bool {
        for _ in 0..<attempts {
            if element.exists && element.isHittable { return true }
            app.swipeUp()
        }
        return element.exists && element.isHittable
    }

    private func pause(_ seconds: TimeInterval, scaled: Bool = true) {
        RunLoop.current.run(until: Date().addingTimeInterval(scaled ? seconds * pace : seconds))
    }

    // MARK: - Environment

    private static var openLinks: Bool { value("HACKDIFFERENT_UITEST_OPEN_LINKS") != "0" }

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
