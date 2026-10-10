import XCTest
import SwiftUI
@testable import AppsChannel

final class ShortcutMappingManagerTests: XCTestCase {

    @MainActor
    func testDefaultGroupShortcutsFallback() {
        let manager = ShortcutMappingManager.shared
        manager.resetGroupShortcuts()

        let categories = ["ALL", "DEVELOPER", "PRODUCTIVITY", "INTERNET", "DESIGN & ART", "SYSTEM & UTILITY", "AUDIO DAW", "VIDEO STUDIO"]

        XCTAssertEqual(manager.category(forSlot: 1, availableCategories: categories), "ALL")
        XCTAssertEqual(manager.category(forSlot: 2, availableCategories: categories), "DEVELOPER")
        XCTAssertEqual(manager.category(forSlot: 3, availableCategories: categories), "PRODUCTIVITY")
        XCTAssertEqual(manager.category(forSlot: 8, availableCategories: categories), "VIDEO STUDIO")
        XCTAssertNil(manager.category(forSlot: 9, availableCategories: categories))
    }

    @MainActor
    func testCustomGroupShortcutsOverrideAndReset() {
        let manager = ShortcutMappingManager.shared
        manager.resetGroupShortcuts()

        let categories = ["ALL", "DEVELOPER", "PRODUCTIVITY", "INTERNET"]

        // Custom assignment: Slot 1 -> "DEVELOPER", Slot 2 -> "ALL"
        manager.setGroupShortcut(category: "DEVELOPER", forSlot: 1)
        manager.setGroupShortcut(category: "ALL", forSlot: 2)

        XCTAssertEqual(manager.category(forSlot: 1, availableCategories: categories), "DEVELOPER")
        XCTAssertEqual(manager.category(forSlot: 2, availableCategories: categories), "ALL")

        // Reset to default
        manager.resetGroupShortcuts()
        XCTAssertEqual(manager.category(forSlot: 1, availableCategories: categories), "ALL")
        XCTAssertEqual(manager.category(forSlot: 2, availableCategories: categories), "DEVELOPER")
    }

    @MainActor
    func testCustomChannelSlotAssignmentAndReset() {
        let manager = ShortcutMappingManager.shared
        manager.resetChannelSlots()

        // Unassigned slots should report nil path
        XCTAssertNil(manager.assignedAppPath(forSlot: 1))
        XCTAssertNil(manager.assignedAppPath(forSlot: 9))

        // Assign slot 1 and slot 5
        let testPath1 = "/Applications/TestApp1.app"
        let testPath5 = "/Applications/TestApp5.app"
        manager.setChannelSlot(appPath: testPath1, forSlot: 1)
        manager.setChannelSlot(appPath: testPath5, forSlot: 5)

        XCTAssertEqual(manager.assignedAppPath(forSlot: 1), testPath1)
        XCTAssertEqual(manager.assignedAppPath(forSlot: 5), testPath5)
        XCTAssertNil(manager.assignedAppPath(forSlot: 2))

        // Reset
        manager.resetChannelSlots()
        XCTAssertNil(manager.assignedAppPath(forSlot: 1))
        XCTAssertNil(manager.assignedAppPath(forSlot: 5))
    }

    @MainActor
    func testAssignedAppResolution() {
        let manager = ShortcutMappingManager.shared
        manager.resetChannelSlots()

        let appURL = URL(fileURLWithPath: "/Applications/Calculator.app")
        let app = DiscoveredApp(
            id: UUID(),
            name: "Calculator",
            url: appURL,
            bundleIdentifier: "com.apple.calculator",
            icon: NSImage(),
            category: "UTILITY",
            tagBadge: "Calc",
            sizeString: "10 MB",
            accentColor: .white
        )

        manager.setChannelSlot(appPath: appURL.path, forSlot: 3)
        let resolved = manager.assignedApp(forSlot: 3, in: [app])
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.name, "Calculator")

        // Slot 4 unassigned
        XCTAssertNil(manager.assignedApp(forSlot: 4, in: [app]))

        manager.resetChannelSlots()
    }
}
