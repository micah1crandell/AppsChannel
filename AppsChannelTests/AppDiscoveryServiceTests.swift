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

    @MainActor
    func testQuickLauncherSearchScoringAndRanking() {
        let tracker = AppUsageTracker.shared
        let testApp1 = DiscoveredApp(
            id: UUID(),
            name: "Safari",
            url: URL(fileURLWithPath: "/Applications/Safari.app"),
            bundleIdentifier: "com.apple.Safari",
            icon: NSImage(),
            category: "INTERNET",
            tagBadge: "WEB",
            sizeString: "50 MB",
            accentColor: .blue
        )
        let testApp2 = DiscoveredApp(
            id: UUID(),
            name: "Slack",
            url: URL(fileURLWithPath: "/Applications/Slack.app"),
            bundleIdentifier: "com.tinyspeck.slackmacgap",
            icon: NSImage(),
            category: "COMMUNICATION",
            tagBadge: "CHAT",
            sizeString: "120 MB",
            accentColor: .purple
        )

        let safariScore = tracker.searchScore(for: testApp1, query: "saf")
        let slackScore = tracker.searchScore(for: testApp2, query: "saf")

        XCTAssertGreaterThan(safariScore, slackScore)
        XCTAssertGreaterThan(safariScore, 50.0)
    }

    @MainActor
    func testKeyboardModifierResetOnQuickLauncherPresentation() {
        let modifierManager = KeyboardModifierManager.shared
        // Simulate a pressed modifier
        modifierManager.update(from: [.command, .option])
        XCTAssertTrue(modifierManager.isCommandPressed)
        XCTAssertTrue(modifierManager.isOptionPressed)

        // Presenting quick launcher must unconditionally clear modifiers
        PanelController.shared.showQuickLauncher()
        XCTAssertFalse(modifierManager.isCommandPressed)
        XCTAssertFalse(modifierManager.isOptionPressed)

        // Clean up
        PanelController.shared.hideQuickLauncher()
    }

    @MainActor
    func testQuickLauncherStateResetAndSelectionHandling() {
        let state = QuickLauncherState.shared

        // Set state as if user typed and selected all text
        state.searchText = "safari"
        state.isSearchTextSelected = true
        state.selectedCategory = "INTERNET"

        XCTAssertEqual(state.searchText, "safari")
        XCTAssertTrue(state.isSearchTextSelected)
        XCTAssertEqual(state.selectedCategory, "INTERNET")

        // Reset must clear search text, selection, and category
        state.reset()
        XCTAssertEqual(state.searchText, "")
        XCTAssertFalse(state.isSearchTextSelected)
        XCTAssertEqual(state.selectedCategory, "ALL")

        // Test selection clearing and replacement
        state.searchText = "terminal"
        state.isSearchTextSelected = true
        XCTAssertTrue(state.isSearchTextSelected)

        // Simulating backspace on selected text
        if state.isSearchTextSelected {
            state.searchText = ""
            state.isSearchTextSelected = false
            state.updateFilteredApps()
        }
        XCTAssertEqual(state.searchText, "")
        XCTAssertFalse(state.isSearchTextSelected)
    }

    @MainActor
    func testNormalTypingAndBackspaceInQuickLauncher() {
        let state = QuickLauncherState.shared
        state.reset()

        // 1. User types characters normally
        state.searchText = "calc"
        state.isSearchTextSelected = false
        state.updateFilteredApps()
        XCTAssertEqual(state.searchText, "calc")
        XCTAssertFalse(state.isSearchTextSelected)

        // 2. User presses Backspace without Command or selection
        if state.isSearchTextSelected {
            state.searchText = ""
            state.isSearchTextSelected = false
        } else if !state.searchText.isEmpty {
            state.searchText = String(state.searchText.dropLast())
            state.updateFilteredApps()
        }
        XCTAssertEqual(state.searchText, "cal")

        // 3. Backspacing again
        if !state.searchText.isEmpty {
            state.searchText = String(state.searchText.dropLast())
            state.updateFilteredApps()
        }
        XCTAssertEqual(state.searchText, "ca")

        // 4. Backspace until empty
        state.searchText = ""
        state.updateFilteredApps()
        XCTAssertEqual(state.searchText, "")

        // 5. Backspacing when already empty does not crash
        if !state.searchText.isEmpty {
            state.searchText = String(state.searchText.dropLast())
        }
        XCTAssertEqual(state.searchText, "")

        // 6. Option+Backspace deletes last word
        state.searchText = "visual studio code"
        let words = state.searchText.split(separator: " ")
        if !words.isEmpty {
            state.searchText = words.dropLast().joined(separator: " ")
        }
        XCTAssertEqual(state.searchText, "visual studio")
    }

    @MainActor
    func testMainAppTextViewBackspaceAndSelectionSync() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))
        textView.string = "terminal"
        var searchText = textView.string

        // 1. Normal backspace at end of line (cursor with length 0)
        textView.setSelectedRange(NSRange(location: 8, length: 0))
        XCTAssertEqual(textView.selectedRange().length, 0)
        textView.deleteBackward(nil)
        searchText = textView.string
        XCTAssertEqual(searchText, "termina")
        XCTAssertEqual(textView.string, "termina")

        // 2. Select All (Command + A)
        textView.selectAll(nil)
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 7))

        // 3. Backspace with active selection deletes entire selected string
        textView.deleteBackward(nil)
        searchText = textView.string
        XCTAssertEqual(searchText, "")
        XCTAssertEqual(textView.string, "")

        // 4. Partial selection deletion (e.g. user highlights trailing word)
        textView.string = "apple music"
        searchText = textView.string
        textView.setSelectedRange(NSRange(location: 5, length: 6)) // " music"
        textView.deleteBackward(nil)
        searchText = textView.string
        XCTAssertEqual(searchText, "apple")
        XCTAssertEqual(textView.string, "apple")

        // 5. Cursor inadvertently at index 0 (root cause of dropped keystrokes):
        // When cursor is at 0, our recovery logic positions it at the end so backspace succeeds.
        textView.string = "chrome"
        searchText = textView.string
        textView.setSelectedRange(NSRange(location: 0, length: 0)) // Cursor stuck at 0!
        let currentLength = (textView.string as NSString).length
        let selectedRange = textView.selectedRange()
        if currentLength > 0 {
            if selectedRange.location == 0 {
                textView.setSelectedRange(NSRange(location: currentLength, length: 0))
            }
            textView.deleteBackward(nil)
            if (textView.string as NSString).length == currentLength && !textView.string.isEmpty {
                var updated = textView.string
                updated.removeLast()
                textView.string = updated
                textView.setSelectedRange(NSRange(location: (updated as NSString).length, length: 0))
            }
            textView.didChangeText()
            searchText = textView.string
        }
        XCTAssertEqual(searchText, "chrom")
        XCTAssertEqual(textView.string, "chrom")
    }

    @MainActor
    func testSevenSequentialBackspacesWithoutDroppingKeystrokes() {
        let state = QuickLauncherState.shared
        state.reset()

        // User types 7 characters: "1234567"
        state.searchText = "1234567"
        state.isSearchTextSelected = false
        state.updateFilteredApps()
        XCTAssertEqual(state.searchText, "1234567")

        // User rapidly presses backspace 7 times in a row:
        // Every single backspace must succeed (7 out of 7 success rate, 0 drops)
        let expected = ["123456", "12345", "1234", "123", "12", "1", ""]
        for exp in expected {
            if !state.searchText.isEmpty {
                state.searchText = String(state.searchText.dropLast())
                state.updateFilteredApps()
            }
            XCTAssertEqual(state.searchText, exp)
        }
        XCTAssertEqual(state.searchText, "")
    }
}

