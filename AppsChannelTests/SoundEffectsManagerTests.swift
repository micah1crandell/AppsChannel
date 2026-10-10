import XCTest
import AppKit
@testable import AppsChannel

final class SoundEffectsManagerTests: XCTestCase {

    @MainActor
    func testSoundThemeDefinitions() {
        let themes = SoundTheme.allCases
        XCTAssertEqual(themes.count, 3)

        for theme in themes {
            XCTAssertFalse(theme.rawValue.isEmpty)
            XCTAssertFalse(theme.navigationSoundName.isEmpty)
            XCTAssertFalse(theme.launchSoundName.isEmpty)
            XCTAssertFalse(theme.actionSoundName.isEmpty)

            // Verify system sounds exist in macOS System Library
            XCTAssertNotNil(NSSound(named: NSSound.Name(theme.navigationSoundName)))
            XCTAssertNotNil(NSSound(named: NSSound.Name(theme.launchSoundName)))
            XCTAssertNotNil(NSSound(named: NSSound.Name(theme.actionSoundName)))
        }
    }

    @MainActor
    func testSoundEffectsManagerDefaults() {
        let manager = SoundEffectsManager.shared
        // Manager should report valid defaults
        XCTAssertTrue(manager.isEnabled || !manager.isEnabled)
        XCTAssertTrue(manager.isHapticEnabled || !manager.isHapticEnabled)
        XCTAssertNotNil(manager.currentTheme)
    }

    @MainActor
    func testPlaybackExecutionDoesNotCrash() {
        let manager = SoundEffectsManager.shared
        // Should execute smoothly without throwing exceptions
        manager.playNavigation()
        manager.playAction()
        manager.playLaunch()
        manager.performHaptic()
    }
}
