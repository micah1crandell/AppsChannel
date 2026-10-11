import XCTest
import SwiftUI
@testable import AppsChannel

@MainActor
final class SystemActionServiceTests: XCTestCase {

    func testAllSystemActionCasesExistAndAreComplete() {
        let allCases = SystemActionType.allCases
        XCTAssertEqual(allCases.count, 10)

        let expectedCases: [SystemActionType] = [
            .lockScreen,
            .sleep,
            .restart,
            .shutDown,
            .emptyTrash,
            .toggleDarkMode,
            .toggleMute,
            .toggleWifi,
            .bluetoothSettings,
            .clipboardHistory
        ]

        for expected in expectedCases {
            XCTAssertTrue(allCases.contains(expected), "Missing system action: \(expected)")
            XCTAssertFalse(expected.title.isEmpty)
            XCTAssertFalse(expected.subtitle.isEmpty)
            XCTAssertFalse(expected.iconSymbolName.isEmpty)
            XCTAssertFalse(expected.keywords.isEmpty)
        }
    }

    func testDeterministicFixedIdsAreUnique() {
        let ids = SystemActionType.allCases.map { $0.fixedId }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "Each system action must have a globally unique deterministic UUID")
    }

    func testDestructiveFlags() {
        XCTAssertTrue(SystemActionType.restart.isDestructive)
        XCTAssertTrue(SystemActionType.shutDown.isDestructive)

        XCTAssertFalse(SystemActionType.lockScreen.isDestructive)
        XCTAssertFalse(SystemActionType.sleep.isDestructive)
        XCTAssertFalse(SystemActionType.emptyTrash.isDestructive)
        XCTAssertFalse(SystemActionType.toggleDarkMode.isDestructive)
        XCTAssertFalse(SystemActionType.toggleMute.isDestructive)
        XCTAssertFalse(SystemActionType.toggleWifi.isDestructive)
        XCTAssertFalse(SystemActionType.bluetoothSettings.isDestructive)
        XCTAssertFalse(SystemActionType.clipboardHistory.isDestructive)
    }

    func testToDiscoveredAppConversion() {
        for action in SystemActionType.allCases {
            let app = action.toDiscoveredApp()
            XCTAssertEqual(app.id, action.fixedId)
            XCTAssertEqual(app.name, action.title)
            XCTAssertEqual(app.category, "SYSTEM")
            XCTAssertEqual(app.tagBadge, "ACTION")
            XCTAssertEqual(app.systemAction, action)
            XCTAssertEqual(app.url.scheme, "systemaction")
            XCTAssertEqual(app.url.host, action.rawValue)
            XCTAssertFalse(app.isSeparator)
            XCTAssertFalse(app.isAppsChannelApp)
            XCTAssertNotNil(app.icon)
        }
    }

    func testDiscoveredAppEqualityForSystemActions() {
        let app1 = SystemActionType.lockScreen.toDiscoveredApp()
        let app1Duplicate = SystemActionType.lockScreen.toDiscoveredApp()
        let app2 = SystemActionType.sleep.toDiscoveredApp()

        XCTAssertEqual(app1, app1Duplicate)
        XCTAssertNotEqual(app1, app2)
        XCTAssertEqual(app1.hashValue, app1Duplicate.hashValue)
    }

    func testKeywordsSearchRelevance() {
        let lockApp = SystemActionType.lockScreen.toDiscoveredApp()
        let scoreLock = AppUsageTracker.shared.searchScore(for: lockApp, query: "lock")
        XCTAssertGreaterThan(scoreLock, 100.0, "Typing 'lock' should yield a high relevance score for Lock Screen")

        let trashApp = SystemActionType.emptyTrash.toDiscoveredApp()
        let scoreTrash = AppUsageTracker.shared.searchScore(for: trashApp, query: "trash")
        XCTAssertGreaterThan(scoreTrash, 100.0, "Typing 'trash' should yield a high relevance score for Empty Trash")

        let muteApp = SystemActionType.toggleMute.toDiscoveredApp()
        let scoreMute = AppUsageTracker.shared.searchScore(for: muteApp, query: "mute")
        XCTAssertGreaterThan(scoreMute, 100.0, "Typing 'mute' should yield a high relevance score for Toggle Mute")
    }

    func testSystemActionServiceSingletonAndApps() {
        let service = SystemActionService.shared
        XCTAssertEqual(service.allActionApps.count, 10)
    }
}
