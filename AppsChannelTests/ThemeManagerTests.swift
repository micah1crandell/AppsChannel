import XCTest
import SwiftUI
@testable import AppsChannel

final class ThemeManagerTests: XCTestCase {

    @MainActor
    func testAllThemeCasesExistAndHaveDescriptions() {
        for theme in AppVisualTheme.allCases {
            XCTAssertFalse(theme.rawValue.isEmpty)
            XCTAssertFalse(theme.description.isEmpty)
            XCTAssertNotNil(theme.cardBackgroundGradient)
            XCTAssertNotNil(theme.canvasBackgroundGradient)
            XCTAssertNotNil(theme.cardBorderGradient(isSelected: false))
            XCTAssertNotNil(theme.cardBorderGradient(isSelected: true))
            XCTAssertNotNil(theme.selectionGlowColor)
        }
    }

    @MainActor
    func testThemeManagerSwitching() {
        let manager = ThemeManager.shared
        let original = manager.currentTheme

        manager.setTheme(.indigoPurple)
        XCTAssertEqual(manager.currentTheme, .indigoPurple)
        XCTAssertEqual(manager.currentTheme, .gameCubeIndigo) // Test alias

        manager.setTheme(.matteWhite)
        XCTAssertEqual(manager.currentTheme, .matteWhite)
        XCTAssertEqual(manager.currentTheme, .wiiMatteWhite) // Test alias

        manager.setTheme(.cyberpunkDark)
        XCTAssertEqual(manager.currentTheme, .cyberpunkDark)

        // Restore original
        manager.setTheme(original)
    }

    func testAppVisualThemeFromStringParsing() {
        XCTAssertEqual(AppVisualTheme.from(string: "liquid-glass"), .liquidGlass)
        XCTAssertEqual(AppVisualTheme.from(string: "glass"), .liquidGlass)
        XCTAssertEqual(AppVisualTheme.from(string: "matte-white"), .matteWhite)
        XCTAssertEqual(AppVisualTheme.from(string: "white"), .matteWhite)
        XCTAssertEqual(AppVisualTheme.from(string: "wii"), .matteWhite) // Legacy compatibility
        XCTAssertEqual(AppVisualTheme.from(string: "wii-matte-white"), .matteWhite) // Legacy compatibility
        XCTAssertEqual(AppVisualTheme.from(string: "indigo"), .indigoPurple)
        XCTAssertEqual(AppVisualTheme.from(string: "purple"), .indigoPurple)
        XCTAssertEqual(AppVisualTheme.from(string: "gamecube"), .indigoPurple) // Legacy compatibility
        XCTAssertEqual(AppVisualTheme.from(string: "cyberpunk"), .cyberpunkDark)
        XCTAssertEqual(AppVisualTheme.from(string: "neon"), .cyberpunkDark)
        XCTAssertNil(AppVisualTheme.from(string: "nonexistent-theme-xyz"))
    }

    func testMainLayoutViewModeBackwardsCompatibility() {
        XCTAssertEqual(MainLayoutViewMode(rawValue: "Flat Grid"), .flatGrid)
        XCTAssertEqual(MainLayoutViewMode(rawValue: "flatGrid"), .flatGrid)
        XCTAssertEqual(MainLayoutViewMode(rawValue: "3DS Grid"), .flatGrid)
        XCTAssertEqual(MainLayoutViewMode(rawValue: "threeDSGrid"), .flatGrid)
        XCTAssertEqual(MainLayoutViewMode(rawValue: "3DS Flat Grid"), .flatGrid)
        XCTAssertEqual(MainLayoutViewMode.threeDSGrid, .flatGrid)
        XCTAssertEqual(MainLayoutViewMode.flatGrid.title, "Flat Grid")
    }
}
