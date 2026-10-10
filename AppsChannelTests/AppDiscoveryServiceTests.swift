import XCTest
@testable import AppsChannel

final class AppDiscoveryServiceTests: XCTestCase {

    @MainActor
    func testDiscoveredAppSelfIdentification() {
        let appsChannelApp = DiscoveredApp(
            id: UUID(),
            name: "AppsChannel",
            url: URL(fileURLWithPath: "/Applications/AppsChannel.app"),
            bundleIdentifier: "com.micahcrandell.AppsChannel",
            icon: NSImage(),
            category: "Utilities",
            tagBadge: "UTIL",
            sizeString: "25 MB",
            accentColor: .white
        )

        XCTAssertTrue(appsChannelApp.isAppsChannelApp)

        let safariApp = DiscoveredApp(
            id: UUID(),
            name: "Safari",
            url: URL(fileURLWithPath: "/Applications/Safari.app"),
            bundleIdentifier: "com.apple.Safari",
            icon: NSImage(),
            category: "Productivity",
            tagBadge: "WEB",
            sizeString: "40 MB",
            accentColor: .blue
        )

        XCTAssertFalse(safariApp.isAppsChannelApp)
    }

    @MainActor
    func testDiscoveredAppEqualityAndHashing() {
        let url1 = URL(fileURLWithPath: "/Applications/TestApp.app")
        let url2 = URL(fileURLWithPath: "/Applications/OtherApp.app")

        let appA = DiscoveredApp(
            id: UUID(),
            name: "Test App",
            url: url1,
            bundleIdentifier: "com.test.app",
            icon: NSImage(),
            category: "Utilities",
            tagBadge: "UTIL",
            sizeString: "10 MB",
            accentColor: .gray
        )

        let appB = DiscoveredApp(
            id: UUID(),
            name: "Different Name Same URL",
            url: url1,
            bundleIdentifier: "com.test.app2",
            icon: NSImage(),
            category: "Other",
            tagBadge: "OTH",
            sizeString: "10 MB",
            accentColor: .gray
        )

        let appC = DiscoveredApp(
            id: UUID(),
            name: "Test App",
            url: url2,
            bundleIdentifier: "com.test.app",
            icon: NSImage(),
            category: "Utilities",
            tagBadge: "UTIL",
            sizeString: "10 MB",
            accentColor: .gray
        )

        // Equatable is based on URL
        XCTAssertEqual(appA, appB)
        XCTAssertNotEqual(appA, appC)
    }

    @MainActor
    func testRunningApplicationTracking() {
        let service = AppDiscoveryService.shared
        service.updateRunningApplications()

        // Finder is virtually always running on macOS
        let finderBundleId = "com.apple.finder"
        XCTAssertTrue(service.runningBundleIds.contains(finderBundleId))

        let finderApp = DiscoveredApp(
            id: UUID(),
            name: "Finder",
            url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
            bundleIdentifier: finderBundleId,
            icon: NSImage(),
            category: "System",
            tagBadge: "SYS",
            sizeString: "1 MB",
            accentColor: .blue
        )

        XCTAssertTrue(service.isRunning(app: finderApp))

        // Test URL fallback when bundleIdentifier is nil
        let finderAppNoBundleId = DiscoveredApp(
            id: UUID(),
            name: "Finder",
            url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"),
            bundleIdentifier: nil,
            icon: NSImage(),
            category: "System",
            tagBadge: "SYS",
            sizeString: "1 MB",
            accentColor: .blue
        )
        XCTAssertTrue(service.isRunning(app: finderAppNoBundleId))

        let fakeApp = DiscoveredApp(
            id: UUID(),
            name: "FakeApp",
            url: URL(fileURLWithPath: "/Applications/FakeApp999999.app"),
            bundleIdentifier: "com.fake.app.nonexistent999",
            icon: NSImage(),
            category: "Unknown",
            tagBadge: "UNK",
            sizeString: "0 MB",
            accentColor: .gray
        )

        XCTAssertFalse(service.isRunning(app: fakeApp))
    }

    @MainActor
    func testHiddenAppsSeparatorProperties() {
        let separator = DiscoveredApp.hiddenAppsSeparator
        XCTAssertTrue(separator.isSeparator)
        XCTAssertTrue(separator.isAppsChannelApp)
        XCTAssertEqual(separator.name, "Hidden Apps")
        XCTAssertEqual(separator.category, "SECTION")
        XCTAssertEqual(separator.sizeString, "|")
    }

    @MainActor
    func testMatchingHiddenApps() {
        let service = AppDiscoveryService.shared

        let hiddenTestApp = DiscoveredApp(
            id: UUID(),
            name: "SecretCalculatorApp",
            url: URL(fileURLWithPath: "/Applications/SecretCalculatorApp.app"),
            bundleIdentifier: "com.test.secretcalc",
            icon: NSImage(),
            category: "Utilities",
            tagBadge: "CALC",
            sizeString: "5 MB",
            accentColor: .orange
        )

        let visibleTestApp = DiscoveredApp(
            id: UUID(),
            name: "VisibleCalculatorApp",
            url: URL(fileURLWithPath: "/Applications/VisibleCalculatorApp.app"),
            bundleIdentifier: "com.test.visiblecalc",
            icon: NSImage(),
            category: "Utilities",
            tagBadge: "CALC",
            sizeString: "5 MB",
            accentColor: .blue
        )

        // Inject into allDiscoveredApps
        service.allDiscoveredApps = [hiddenTestApp, visibleTestApp]

        // Hide the secret app
        service.hideApp(hiddenTestApp)
        XCTAssertTrue(service.isHidden(app: hiddenTestApp))
        XCTAssertFalse(service.isHidden(app: visibleTestApp))

        // Empty query returns empty
        XCTAssertTrue(service.matchingHiddenApps(query: "").isEmpty)
        XCTAssertTrue(service.matchingHiddenApps(query: "   ").isEmpty)

        // Search for "Secret"
        let matchesForSecret = service.matchingHiddenApps(query: "Secret")
        XCTAssertEqual(matchesForSecret.count, 1)
        XCTAssertEqual(matchesForSecret.first?.name, "SecretCalculatorApp")
        XCTAssertTrue(matchesForSecret.first?.isHiddenApp == true)

        // Search for "Visible" matches visible app, so hidden matches should be empty
        let matchesForVisible = service.matchingHiddenApps(query: "Visible")
        XCTAssertTrue(matchesForVisible.isEmpty)

        // Search for "Calculator" matches both, but matchingHiddenApps should only return the hidden one
        let matchesForCalc = service.matchingHiddenApps(query: "Calculator")
        XCTAssertEqual(matchesForCalc.count, 1)
        XCTAssertEqual(matchesForCalc.first?.name, "SecretCalculatorApp")
        XCTAssertTrue(matchesForCalc.first?.isHiddenApp == true)

        // Clean up: Unhide secret app
        service.unhideApp(path: hiddenTestApp.url.path)
        XCTAssertFalse(service.isHidden(app: hiddenTestApp))
        XCTAssertTrue(service.matchingHiddenApps(query: "Secret").isEmpty)
    }

    func testQuickAppPathsScanIncludesStandardAndUtilityPaths() {
        let paths = AppDiscoveryService.quickAppPathsScan()
        XCTAssertFalse(paths.isEmpty)

        // Standard system apps that exist on macOS
        let finderPath = "/System/Library/CoreServices/Finder.app"
        if FileManager.default.fileExists(atPath: finderPath) {
            XCTAssertTrue(paths.contains(finderPath))
        }

        // Must find at least one installed application in /Applications or /System/Applications
        let hasSystemOrUserApps = paths.contains { $0.hasPrefix("/Applications/") || $0.hasPrefix("/System/Applications/") }
        XCTAssertTrue(hasSystemOrUserApps)
    }

    func testUniversalBuildAppIntegrity() {
        let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        if FileManager.default.fileExists(atPath: finderURL.path) {
            let app = AppDiscoveryService.buildApp(at: finderURL)
            XCTAssertNotNil(app)
            XCTAssertEqual(app?.name, "Finder")
            XCTAssertFalse(app?.isAppsChannelApp == true)
            XCTAssertEqual(app?.url, finderURL)
        }
    }

    @MainActor
    func testMenuBarManagerVisibilityToggle() {
        let manager = MenuBarManager.shared
        // Test hiding and restoring menubar presence
        manager.setVisibility(false)
        manager.setVisibility(true)
        // Should execute smoothly without crashing
        XCTAssertNotNil(manager)
    }

    @MainActor
    func testFindAppMatchingQuery() {
        let service = AppDiscoveryService.shared

        // Test empty query returns nil
        XCTAssertNil(service.findApp(matching: ""))
        XCTAssertNil(service.findApp(matching: "   "))

        // Finder is always included in allDiscoveredApps
        if let finder = service.findApp(matching: "Finder") {
            XCTAssertEqual(finder.name, "Finder")
        }

        // Test bundle ID match
        if let finderByBundle = service.findApp(matching: "com.apple.finder") {
            XCTAssertEqual(finderByBundle.bundleIdentifier, "com.apple.finder")
        }
    }

    @MainActor
    func testQuickLauncherPresentationAndDismissalIndexReset() {
        let service = AppDiscoveryService.shared
        guard !service.apps.isEmpty else { return }

        let expectedCenter = service.apps.count / 2

        // Simulate user navigating to the far right (e.g. index 290 or apps.count - 1)
        service.selectedIndex = service.apps.count - 1
        XCTAssertEqual(service.selectedIndex, service.apps.count - 1)

        // Dismissing quick launcher must reset selectedIndex back to Rank #1 center
        PanelController.shared.hideQuickLauncher()
        XCTAssertEqual(service.selectedIndex, expectedCenter, "Dismissing Quick Launcher must restore selectedIndex to Rank #1 center")

        // Simulate user searching and selecting index 0
        service.selectedIndex = 0
        XCTAssertEqual(service.selectedIndex, 0)

        // Opening quick launcher must also unconditionally reset selectedIndex back to Rank #1 center
        PanelController.shared.showQuickLauncher()
        XCTAssertEqual(service.selectedIndex, expectedCenter, "Presenting Quick Launcher must restore selectedIndex to Rank #1 center")

        // Clean up
        PanelController.shared.hideQuickLauncher()
    }
}

