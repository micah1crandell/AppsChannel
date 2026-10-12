import XCTest
import SwiftUI
import AppKit
@testable import AppsChannel

final class ClassicLauncherAndDaemonTests: XCTestCase {

    override func setUp() {
        super.setUp()
        AppDelegate.isExplicitQuit = false
    }

    override func tearDown() {
        AppDelegate.isExplicitQuit = false
        super.tearDown()
    }

    // MARK: - 1. LauncherMode Model Tests
    func testLauncherModeCasesAndAliases() {
        XCTAssertEqual(LauncherMode(rawValue: "classicLauncher"), .classicLauncher)
        XCTAssertEqual(LauncherMode(rawValue: "classic"), .classicLauncher)
        XCTAssertEqual(LauncherMode(rawValue: "raycast"), .classicLauncher)
        XCTAssertEqual(LauncherMode(rawValue: "list"), .classicLauncher)

        XCTAssertEqual(LauncherMode(rawValue: "quickLauncher"), .quickLauncher)
        XCTAssertEqual(LauncherMode(rawValue: "quick"), .quickLauncher)
        XCTAssertEqual(LauncherMode(rawValue: "hud"), .quickLauncher)

        XCTAssertEqual(LauncherMode(rawValue: "fullScreen"), .fullScreen)
        XCTAssertEqual(LauncherMode(rawValue: "fullscreen"), .fullScreen)
        XCTAssertEqual(LauncherMode(rawValue: "main"), .fullScreen)
        XCTAssertEqual(LauncherMode(rawValue: "mainApp"), .fullScreen)

        XCTAssertNil(LauncherMode(rawValue: "nonexistent_mode"))
    }

    func testLauncherModeProperties() {
        for mode in LauncherMode.allCases {
            XCTAssertFalse(mode.id.isEmpty)
            XCTAssertFalse(mode.title.isEmpty)
            XCTAssertFalse(mode.subtitle.isEmpty)
            XCTAssertFalse(mode.iconName.isEmpty)
        }

        XCTAssertEqual(LauncherMode.classicLauncher.title, "Classic Launcher")
        XCTAssertEqual(LauncherMode.quickLauncher.title, "Quick HUD")
        XCTAssertEqual(LauncherMode.fullScreen.title, "Channel Window")
    }

    // MARK: - 2. Daemon & Soft-Quit Lifecycle Tests
    @MainActor
    func testDaemonBackgroundSoftQuitWhenEnabled() {
        let delegate = AppDelegate()
        AppDelegate.isExplicitQuit = false

        // When keepRunningInBackgroundOnQuit is true (default), terminate must be canceled
        UserDefaults.standard.set(true, forKey: "keepRunningInBackgroundOnQuit")
        let reply = delegate.applicationShouldTerminate(NSApp)
        XCTAssertEqual(reply, .terminateCancel, "⌘Q should be canceled to keep background hotkeys alive")
    }

    @MainActor
    func testDaemonHardQuitWhenDisabled() {
        let delegate = AppDelegate()
        AppDelegate.isExplicitQuit = false

        // When user disables keepRunningInBackgroundOnQuit, app must terminate immediately on ⌘Q
        UserDefaults.standard.set(false, forKey: "keepRunningInBackgroundOnQuit")
        let reply = delegate.applicationShouldTerminate(NSApp)
        XCTAssertEqual(reply, .terminateNow, "⌘Q should terminate app if keepRunningInBackgroundOnQuit is disabled")

        // Reset to default
        UserDefaults.standard.set(true, forKey: "keepRunningInBackgroundOnQuit")
    }

    @MainActor
    func testExplicitQuitOverridesKeepRunningSetting() {
        let delegate = AppDelegate()

        // Even if keepRunningInBackgroundOnQuit is true, explicit quit must terminate now
        UserDefaults.standard.set(true, forKey: "keepRunningInBackgroundOnQuit")
        AppDelegate.isExplicitQuit = true

        let reply = delegate.applicationShouldTerminate(NSApp)
        XCTAssertEqual(reply, .terminateNow, "Explicit quit must terminate even if keepRunningInBackgroundOnQuit is enabled")

        AppDelegate.isExplicitQuit = false
    }

    @MainActor
    func testURLSchemeQuitAction() {
        let delegate = AppDelegate()
        AppDelegate.isExplicitQuit = false

        guard let quitURL = URL(string: "appschannel://quit") else {
            XCTFail("Failed to construct quit URL")
            return
        }

        // handleURL should set isExplicitQuit to true
        delegate.handleURL(quitURL)
        XCTAssertTrue(AppDelegate.isExplicitQuit, "appschannel://quit should trigger complete termination")

        AppDelegate.isExplicitQuit = false

        guard let exitURL = URL(string: "appschannel://exit") else {
            XCTFail("Failed to construct exit URL")
            return
        }

        delegate.handleURL(exitURL)
        XCTAssertTrue(AppDelegate.isExplicitQuit, "appschannel://exit should trigger complete termination")

        AppDelegate.isExplicitQuit = false
    }

    // MARK: - 3. Classic Launcher State & Ranking Tests
    @MainActor
    func testClassicLauncherStateInitialSections() {
        let state = ClassicLauncherState.shared
        state.reset()

        XCTAssertEqual(state.searchText, "")
        XCTAssertEqual(state.selectedIndex, 0)
        XCTAssertEqual(state.selectedCategory, "ALL")
        XCTAssertFalse(state.isActionsMenuPresented)

        XCTAssertFalse(state.sections.isEmpty, "Classic launcher should populate sections on init")
        XCTAssertFalse(state.flatItems.isEmpty, "Flat items should contain discovered apps & commands")

        // Suggestions section should have up to 4 items
        if let suggestionsSection = state.sections.first(where: { $0.id == "suggestions" }) {
            XCTAssertLessThanOrEqual(suggestionsSection.items.count, 4)
            for item in suggestionsSection.items {
                XCTAssertEqual(item.kind, .suggestion)
                XCTAssertEqual(item.badge, "Suggestion")
            }
        }
    }

    @MainActor
    func testClassicLauncherSearchFiltering() {
        let state = ClassicLauncherState.shared
        state.reset()

        // Filter for empty trash or system command
        state.searchText = "Trash"
        state.updateSections()

        XCTAssertFalse(state.flatItems.isEmpty, "Searching for 'Trash' should find system commands or applications")
        let matchingItem = state.flatItems.first { $0.name.localizedCaseInsensitiveContains("Trash") || $0.subtitle.localizedCaseInsensitiveContains("Trash") }
        XCTAssertNotNil(matchingItem, "Should find matching Trash item")
        XCTAssertEqual(state.selectedIndex, 0, "Selected index should be reset to 0 on new query")

        // Filter for nonexistent query
        state.searchText = "__NonExistentAppOrCommandXYZ_999__"
        state.updateSections()
        XCTAssertTrue(state.flatItems.isEmpty, "Nonexistent query should yield empty list")
        XCTAssertFalse(state.isActionsMenuPresented, "Actions menu should be dismissed when no items match")
        XCTAssertEqual(state.selectedIndex, 0)
    }

    @MainActor
    func testClassicLauncherCategoryFiltering() {
        let state = ClassicLauncherState.shared
        state.reset()

        state.selectedCategory = "SYSTEM"
        state.updateSections()

        for section in state.sections {
            if section.id == "commands" {
                XCTAssertFalse(section.items.isEmpty)
                for item in section.items {
                    XCTAssertEqual(item.kind, .systemAction)
                }
            }
        }

        state.reset()
        XCTAssertEqual(state.selectedCategory, "ALL")
    }

    @MainActor
    func testClassicLauncherToastLifecycle() {
        let state = ClassicLauncherState.shared
        state.showToast(message: "Test Toast")

        XCTAssertEqual(state.toastMessage, "Test Toast")
    }

    // MARK: - 4. Floating Launcher Style Persistence
    func testFloatingLauncherStyleSync() {
        UserDefaults.standard.set("classic", forKey: "floatingLauncherStyle")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "floatingLauncherStyle"), "classic")

        UserDefaults.standard.set("quick", forKey: "floatingLauncherStyle")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "floatingLauncherStyle"), "quick")

        // Reset to classic
        UserDefaults.standard.set("classic", forKey: "floatingLauncherStyle")
    }
}
