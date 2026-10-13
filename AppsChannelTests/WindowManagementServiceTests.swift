import XCTest
import SwiftUI
@testable import AppsChannel

@MainActor
final class WindowManagementServiceTests: XCTestCase {

    func testAllWindowSnappingActionsCoverage() {
        let allCases = WindowSnappingAction.allCases
        XCTAssertEqual(allCases.count, 52, "All 52 window snapping actions must be defined")

        for action in allCases {
            XCTAssertFalse(action.rawValue.isEmpty)
            XCTAssertFalse(action.title.isEmpty)
            XCTAssertFalse(action.keywords.isEmpty)
            XCTAssertTrue(action.keywords.contains("window"))
            XCTAssertTrue(action.keywords.contains("snap"))
        }
    }

    func testCategoriesCoverage() {
        let categories = WindowActionCategory.allCases
        XCTAssertEqual(categories.count, 9)

        let expectedCategories: [WindowActionCategory] = [
            .halves, .thirds, .fourths, .quarters, .sixths,
            .maximize, .resizeAndMove, .displays, .system
        ]

        for cat in expectedCategories {
            XCTAssertTrue(categories.contains(cat))
            let actionsInCat = WindowSnappingAction.allCases.filter { $0.category == cat }
            XCTAssertFalse(actionsInCat.isEmpty, "Category \(cat) must have associated actions")
        }
    }

    func testTargetFrameCalculationHalves() {
        let screenRect = CGRect(x: 0, y: 25, width: 1920, height: 1055)
        let primaryHeight: CGFloat = 1080.0
        let currentWindow = CGRect(x: 200, y: 200, width: 800, height: 600)

        // Left Half
        let leftHalf = WindowManagementService.calculateTargetFrame(
            action: .leftHalf,
            currentFrame: currentWindow,
            screenVisibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1055),
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(leftHalf.origin.x, 0)
        XCTAssertEqual(leftHalf.width, 960)
        XCTAssertEqual(leftHalf.height, 1055)

        // Right Half
        let rightHalf = WindowManagementService.calculateTargetFrame(
            action: .rightHalf,
            currentFrame: currentWindow,
            screenVisibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1055),
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(rightHalf.origin.x, 960)
        XCTAssertEqual(rightHalf.width, 960)
        XCTAssertEqual(rightHalf.height, 1055)

        // Top Half
        let topHalf = WindowManagementService.calculateTargetFrame(
            action: .topHalf,
            currentFrame: currentWindow,
            screenVisibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1055),
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(topHalf.origin.x, 0)
        XCTAssertEqual(topHalf.width, 1920)
        XCTAssertEqual(topHalf.height, 1055 / 2)

        // Bottom Half
        let bottomHalf = WindowManagementService.calculateTargetFrame(
            action: .bottomHalf,
            currentFrame: currentWindow,
            screenVisibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1055),
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(bottomHalf.origin.x, 0)
        XCTAssertEqual(bottomHalf.origin.y, 25 + 1055 / 2)
        XCTAssertEqual(bottomHalf.width, 1920)
        XCTAssertEqual(bottomHalf.height, 1055 / 2)

        // Center Half
        let centerHalf = WindowManagementService.calculateTargetFrame(
            action: .centerHalf,
            currentFrame: currentWindow,
            screenVisibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1055),
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(centerHalf.origin.x, 480)
        XCTAssertEqual(centerHalf.width, 960)
        XCTAssertEqual(centerHalf.height, 1055)
    }

    func testTargetFrameCalculationThirdsAndTwoThirds() {
        let primaryHeight: CGFloat = 1080.0
        let currentWindow = CGRect(x: 100, y: 100, width: 500, height: 400)
        let visibleFrame = CGRect(x: 0, y: 0, width: 1800, height: 1000)

        // First Third
        let firstThird = WindowManagementService.calculateTargetFrame(
            action: .firstThird,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(firstThird.origin.x, 0)
        XCTAssertEqual(firstThird.width, 600)

        // Center Third
        let centerThird = WindowManagementService.calculateTargetFrame(
            action: .centerThird,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(centerThird.origin.x, 600)
        XCTAssertEqual(centerThird.width, 600)

        // Last Third
        let lastThird = WindowManagementService.calculateTargetFrame(
            action: .lastThird,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(lastThird.origin.x, 1200)
        XCTAssertEqual(lastThird.width, 600)

        // First Two Thirds
        let firstTwoThirds = WindowManagementService.calculateTargetFrame(
            action: .firstTwoThirds,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(firstTwoThirds.origin.x, 0)
        XCTAssertEqual(firstTwoThirds.width, 1200)

        // Center Two Thirds
        let centerTwoThirds = WindowManagementService.calculateTargetFrame(
            action: .centerTwoThirds,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(centerTwoThirds.origin.x, 300)
        XCTAssertEqual(centerTwoThirds.width, 1200)
    }

    func testTargetFrameCalculationMaximizeAndCenter() {
        let primaryHeight: CGFloat = 1080.0
        let currentWindow = CGRect(x: 100, y: 100, width: 800, height: 600)
        let visibleFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // Maximize
        let maxFrame = WindowManagementService.calculateTargetFrame(
            action: .maximize,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(maxFrame.origin.x, 0)
        XCTAssertEqual(maxFrame.origin.y, 0)
        XCTAssertEqual(maxFrame.width, 1920)
        XCTAssertEqual(maxFrame.height, 1080)

        // Almost Maximize
        let almostMax = WindowManagementService.calculateTargetFrame(
            action: .almostMaximize,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(almostMax.origin.x, 28)
        XCTAssertEqual(almostMax.origin.y, 28)
        XCTAssertEqual(almostMax.width, 1920 - 56)
        XCTAssertEqual(almostMax.height, 1080 - 56)

        // Center
        let centered = WindowManagementService.calculateTargetFrame(
            action: .center,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(centered.origin.x, (1920 - 800) / 2)
        XCTAssertEqual(centered.origin.y, (1080 - 600) / 2)
        XCTAssertEqual(centered.width, 800)
        XCTAssertEqual(centered.height, 600)

        // Maximize Height
        let maxHeight = WindowManagementService.calculateTargetFrame(
            action: .maximizeHeight,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(maxHeight.origin.x, 100)
        XCTAssertEqual(maxHeight.origin.y, 0)
        XCTAssertEqual(maxHeight.width, 800)
        XCTAssertEqual(maxHeight.height, 1080)

        // Maximize Width
        let maxWidth = WindowManagementService.calculateTargetFrame(
            action: .maximizeWidth,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(maxWidth.origin.x, 0)
        XCTAssertEqual(maxWidth.origin.y, 100)
        XCTAssertEqual(maxWidth.width, 1920)
        XCTAssertEqual(maxWidth.height, 600)
    }

    func testTargetFrameCalculationResizeAndNudge() {
        let primaryHeight: CGFloat = 1080.0
        let currentWindow = CGRect(x: 500, y: 300, width: 800, height: 600)
        let visibleFrame = CGRect(x: 0, y: 0, width: 1920, height: 1080)

        // Make Larger
        let larger = WindowManagementService.calculateTargetFrame(
            action: .makeLarger,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(larger.width, 860)
        XCTAssertEqual(larger.height, 660)

        // Make Smaller
        let smaller = WindowManagementService.calculateTargetFrame(
            action: .makeSmaller,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(smaller.width, 740)
        XCTAssertEqual(smaller.height, 540)

        // Move Left
        let movedLeft = WindowManagementService.calculateTargetFrame(
            action: .moveLeft,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(movedLeft.origin.x, 440)
        XCTAssertEqual(movedLeft.origin.y, 300)

        // Move Right
        let movedRight = WindowManagementService.calculateTargetFrame(
            action: .moveRight,
            currentFrame: currentWindow,
            screenVisibleFrame: visibleFrame,
            primaryScreenHeight: primaryHeight
        )
        XCTAssertEqual(movedRight.origin.x, 560)
        XCTAssertEqual(movedRight.origin.y, 300)
    }

    func testCocoaToAXCoordinateTransformation() {
        let cocoaVisibleFrame = CGRect(x: 0, y: 50, width: 1920, height: 1000)
        let primaryHeight: CGFloat = 1080.0

        let axRect = WindowManagementService.cocoaToAXRect(cocoaVisibleFrame, primaryScreenHeight: primaryHeight)

        XCTAssertEqual(axRect.origin.x, 0)
        // axY = 1080 - (50 + 1000) = 30 (top menubar height)
        XCTAssertEqual(axRect.origin.y, 30)
        XCTAssertEqual(axRect.width, 1920)
        XCTAssertEqual(axRect.height, 1000)
    }

    func testConfigurationPersistenceAndDefaults() {
        let service = WindowManagementService.shared

        // Verify Left Half default key combo
        let leftHalfConf = service.config(for: .leftHalf)
        XCTAssertEqual(leftHalfConf.hotkeyLabel, "⌥ [")
        XCTAssertTrue(leftHalfConf.isEnabled)

        // Verify Center default key combo
        let centerConf = service.config(for: .center)
        XCTAssertEqual(centerConf.hotkeyLabel, "⌥ \\")

        // Verify Maximize default key combo
        let maxConf = service.config(for: .maximize)
        XCTAssertEqual(maxConf.hotkeyLabel, "⌥ =")

        // Test alias setting
        service.setAlias("lh", for: .leftHalf)
        XCTAssertEqual(service.config(for: .leftHalf).alias, "lh")

        // Test enabling/disabling
        service.setEnabled(false, for: .leftHalf)
        XCTAssertFalse(service.config(for: .leftHalf).isEnabled)

        // Restore
        service.setEnabled(true, for: .leftHalf)
        XCTAssertTrue(service.config(for: .leftHalf).isEnabled)
    }

    func testAllWindowActionAppsIntegration() {
        let service = WindowManagementService.shared
        // By default, only actions with configured hotkeys are returned as tiles (11 core curated actions)
        let curatedApps = service.allWindowActionApps(requireHotkey: true)
        XCTAssertEqual(curatedApps.count, 11)

        // All 52 actions can still be retrieved when requireHotkey is false
        let allApps = service.allWindowActionApps(requireHotkey: false)
        XCTAssertEqual(allApps.count, 52)

        for app in curatedApps {
            XCTAssertEqual(app.category, "Window Management")
            XCTAssertEqual(app.sizeString, "Action")
            XCTAssertEqual(app.url.scheme, "window-snap")
            XCTAssertNotNil(app.windowAction)
            XCTAssertNotNil(app.icon)
            XCTAssertNotEqual(app.tagBadge, "Snap", "Curated hotkey apps must display their hotkey label as badge")
        }

        // Test unassigned search fallback
        let searchMatches = service.matchingUnassignedWindowActions(query: "third")
        XCTAssertFalse(searchMatches.isEmpty, "Search for 'third' should find unassigned third actions")
        for match in searchMatches {
            XCTAssertNil(service.config(for: match.windowAction!).keyCode, "Unassigned search match must not have a keyCode")
        }

        // Test dynamically assigning and clearing a hotkey
        XCTAssertNil(service.config(for: .firstThird).keyCode)
        service.setHotkey(keyCode: 99, carbonModifiers: 0, label: "TestKey", for: .firstThird)
        XCTAssertEqual(service.allWindowActionApps(requireHotkey: true).count, 12)
        service.clearHotkey(for: .firstThird)
        XCTAssertEqual(service.allWindowActionApps(requireHotkey: true).count, 11)
    }

    func testSearchScoringWithAliasAndKeywords() {
        let service = WindowManagementService.shared
        service.setAlias("splitl", for: .leftHalf)

        let actionApps = service.allWindowActionApps(requireHotkey: true)
        guard let leftHalfApp = actionApps.first(where: { $0.windowAction == .leftHalf }) else {
            XCTFail("Missing left half action app")
            return
        }

        // Test custom alias scoring
        let aliasScore = AppUsageTracker.shared.searchScore(for: leftHalfApp, query: "splitl")
        XCTAssertGreaterThanOrEqual(aliasScore, 200.0, "Exact custom alias match must produce high score")

        // Test keyword scoring
        let keywordScore = AppUsageTracker.shared.searchScore(for: leftHalfApp, query: "split left")
        XCTAssertGreaterThanOrEqual(keywordScore, 100.0, "Keyword search must produce high score")
    }
}
