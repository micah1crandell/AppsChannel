import XCTest
@testable import AppsChannel

final class HotKeyManagerTests: XCTestCase {

    @MainActor
    func testPresetShortcutsDefinition() {
        let manager = HotKeyManager.shared
        let presets = manager.presets

        XCTAssertFalse(presets.isEmpty)

        // Ensure default shortcut ⌥ + L exists
        let defaultPreset = presets.first { $0.id == "opt_l" }
        XCTAssertNotNil(defaultPreset)
        XCTAssertEqual(defaultPreset?.label, "⌥ + L")

        // Ensure other popular presets exist
        XCTAssertTrue(presets.contains { $0.id == "opt_space" })
        XCTAssertTrue(presets.contains { $0.id == "cmd_opt_space" })
    }
}
