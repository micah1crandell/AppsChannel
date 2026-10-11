import XCTest
import AppKit
@testable import AppsChannel

@MainActor
final class KeyboardModifierManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        KeyboardModifierManager.shared.reset()
    }

    override func tearDown() {
        KeyboardModifierManager.shared.reset()
        super.tearDown()
    }

    func testInitialStateIsClean() {
        let manager = KeyboardModifierManager.shared
        XCTAssertFalse(manager.isCommandPressed)
        XCTAssertFalse(manager.isOptionPressed)
        XCTAssertFalse(manager.isShiftPressed)
        XCTAssertFalse(manager.isControlPressed)
        XCTAssertFalse(manager.hasActiveModifier)
        XCTAssertNil(manager.primaryActionHint)
    }

    func testCommandModifierDetection() {
        let manager = KeyboardModifierManager.shared
        manager.update(from: .command)

        XCTAssertTrue(manager.isCommandPressed)
        XCTAssertFalse(manager.isOptionPressed)
        XCTAssertFalse(manager.isShiftPressed)
        XCTAssertTrue(manager.hasActiveModifier)
        XCTAssertEqual(manager.activeModifierSymbol, "⌘")

        let hint = manager.primaryActionHint
        XCTAssertNotNil(hint)
        XCTAssertEqual(hint?.label, "Reveal in Finder")
        XCTAssertEqual(hint?.key, "⌘↵")
        XCTAssertEqual(hint?.icon, "folder.fill")
    }

    func testOptionModifierDetection() {
        let manager = KeyboardModifierManager.shared
        manager.update(from: .option)

        XCTAssertFalse(manager.isCommandPressed)
        XCTAssertTrue(manager.isOptionPressed)
        XCTAssertFalse(manager.isShiftPressed)
        XCTAssertTrue(manager.hasActiveModifier)
        XCTAssertEqual(manager.activeModifierSymbol, "⌥")

        let hint = manager.primaryActionHint
        XCTAssertNotNil(hint)
        XCTAssertEqual(hint?.label, "Recent Documents")
        XCTAssertEqual(hint?.key, "⌥↵")
        XCTAssertEqual(hint?.icon, "clock.arrow.circlepath")
    }

    func testShiftModifierDetection() {
        let manager = KeyboardModifierManager.shared
        manager.update(from: .shift)

        XCTAssertFalse(manager.isCommandPressed)
        XCTAssertFalse(manager.isOptionPressed)
        XCTAssertTrue(manager.isShiftPressed)
        XCTAssertTrue(manager.hasActiveModifier)
        XCTAssertEqual(manager.activeModifierSymbol, "⇧")

        let hint = manager.primaryActionHint
        XCTAssertNotNil(hint)
        XCTAssertEqual(hint?.label, "Copy Path")
        XCTAssertEqual(hint?.key, "⇧↵")
        XCTAssertEqual(hint?.icon, "doc.on.doc.fill")
    }

    func testResetClearsAllModifiers() {
        let manager = KeyboardModifierManager.shared
        manager.update(from: [.command, .option, .shift])
        XCTAssertTrue(manager.hasActiveModifier)

        manager.reset()
        XCTAssertFalse(manager.isCommandPressed)
        XCTAssertFalse(manager.isOptionPressed)
        XCTAssertFalse(manager.isShiftPressed)
        XCTAssertFalse(manager.hasActiveModifier)
        XCTAssertNil(manager.primaryActionHint)
    }
}
