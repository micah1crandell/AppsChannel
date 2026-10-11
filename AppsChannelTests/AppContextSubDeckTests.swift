import XCTest
import AppKit
import SwiftUI
@testable import AppsChannel

final class AppContextSubDeckTests: XCTestCase {

    func testDetectClipboardContext() {
        let service = AppContextSubDeckService.shared

        // 1. Built-in system action
        let clipboardActionApp = DiscoveredApp(
            name: "Clipboard History",
            url: URL(fileURLWithPath: "/System/Applications/Finder.app"),
            bundleIdentifier: nil,
            icon: NSImage(),
            category: "UTILITIES",
            tagBadge: "SYS",
            sizeString: "—",
            accentColor: .green,
            systemAction: .clipboardHistory
        )
        XCTAssertEqual(service.detectContext(for: clipboardActionApp), .clipboard)

        // 2. Third-party clipboard manager bundle ID
        let maccyApp = DiscoveredApp(
            name: "Maccy",
            url: URL(fileURLWithPath: "/Applications/Maccy.app"),
            bundleIdentifier: "org.p0deje.Maccy",
            icon: NSImage(),
            category: "UTILITIES",
            tagBadge: "CLIP",
            sizeString: "10 MB",
            accentColor: .blue
        )
        XCTAssertEqual(service.detectContext(for: maccyApp), .clipboard)
    }

    func testDetectSystemActionContext() {
        let service = AppContextSubDeckService.shared

        let emptyTrashApp = DiscoveredApp(
            name: "Empty Trash",
            url: URL(fileURLWithPath: "/System/Applications/Finder.app"),
            bundleIdentifier: nil,
            icon: NSImage(),
            category: "UTILITIES",
            tagBadge: "SYS",
            sizeString: "—",
            accentColor: .red,
            systemAction: .emptyTrash
        )
        XCTAssertEqual(service.detectContext(for: emptyTrashApp), .systemAction)

        let windowActionApp = DiscoveredApp(
            name: "Snap Left",
            url: URL(fileURLWithPath: "/System/Applications/Finder.app"),
            bundleIdentifier: nil,
            icon: NSImage(),
            category: "WINDOW",
            tagBadge: "WIN",
            sizeString: "—",
            accentColor: .indigo,
            windowAction: .leftHalf
        )
        XCTAssertEqual(service.detectContext(for: windowActionApp), .systemAction)
    }

    func testDetectBrowserContext() {
        let service = AppContextSubDeckService.shared

        let safariApp = DiscoveredApp(
            name: "Safari",
            url: URL(fileURLWithPath: "/Applications/Safari.app"),
            bundleIdentifier: "com.apple.Safari",
            icon: NSImage(),
            category: "WEB",
            tagBadge: "WEB",
            sizeString: "30 MB",
            accentColor: .blue
        )
        XCTAssertEqual(service.detectContext(for: safariApp), .browser)

        let customBrowser = DiscoveredApp(
            name: "CustomWebBrowser",
            url: URL(fileURLWithPath: "/Applications/CustomWebBrowser.app"),
            bundleIdentifier: "com.example.browser",
            icon: NSImage(),
            category: "WEB",
            tagBadge: "WEB",
            sizeString: "80 MB",
            accentColor: .orange
        )
        XCTAssertEqual(service.detectContext(for: customBrowser), .browser)
    }

    func testDetectDeveloperContext() {
        let service = AppContextSubDeckService.shared

        let xcodeApp = DiscoveredApp(
            name: "Xcode",
            url: URL(fileURLWithPath: "/Applications/Xcode.app"),
            bundleIdentifier: "com.apple.dt.Xcode",
            icon: NSImage(),
            category: "DEVELOPER",
            tagBadge: "DEV",
            sizeString: "12 GB",
            accentColor: .blue
        )
        XCTAssertEqual(service.detectContext(for: xcodeApp), .developer)

        let terminalApp = DiscoveredApp(
            name: "Terminal",
            url: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"),
            bundleIdentifier: "com.apple.Terminal",
            icon: NSImage(),
            category: "UTILITIES",
            tagBadge: "TERM",
            sizeString: "15 MB",
            accentColor: .black
        )
        XCTAssertEqual(service.detectContext(for: terminalApp), .developer)
    }

    func testDetectMediaContext() {
        let service = AppContextSubDeckService.shared

        let musicApp = DiscoveredApp(
            name: "Music",
            url: URL(fileURLWithPath: "/System/Applications/Music.app"),
            bundleIdentifier: "com.apple.Music",
            icon: NSImage(),
            category: "AUDIO",
            tagBadge: "MUSIC",
            sizeString: "50 MB",
            accentColor: .red
        )
        XCTAssertEqual(service.detectContext(for: musicApp), .media)
    }

    func testDetectAppGlanceFallback() {
        let service = AppContextSubDeckService.shared

        let calculatorApp = DiscoveredApp(
            name: "Calculator",
            url: URL(fileURLWithPath: "/System/Applications/Calculator.app"),
            bundleIdentifier: "com.apple.calculator",
            icon: NSImage(),
            category: "UTILITIES",
            tagBadge: "CALC",
            sizeString: "5 MB",
            accentColor: .orange
        )
        // Calculator does not declare documents or media -> defaults to rich App Glance Inspector
        XCTAssertEqual(service.detectContext(for: calculatorApp), .appGlance)
    }

    @MainActor
    func testExtractGlanceInfo() {
        let calcURL = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        let calcApp = DiscoveredApp(
            name: "Calculator",
            url: calcURL,
            bundleIdentifier: "com.apple.calculator",
            icon: NSImage(),
            category: "UTILITIES",
            tagBadge: "CALC",
            sizeString: "8.2 MB",
            accentColor: .orange
        )

        let glance = AppContextSubDeckService.extractGlanceInfo(for: calcApp)
        XCTAssertFalse(glance.architectureBadge.isEmpty)
        XCTAssertFalse(glance.versionString.isEmpty)
        XCTAssertEqual(glance.bundleSizeString, "8.2 MB")
        XCTAssertEqual(glance.bundleIdentifier, "com.apple.calculator")
    }

    func testAppContextKindMetadataCompleteness() {
        for kind in AppContextKind.allCases {
            XCTAssertFalse(kind.title.isEmpty)
            XCTAssertFalse(kind.systemIcon.isEmpty)
            XCTAssertFalse(kind.buttonLabel.isEmpty)
            XCTAssertTrue(kind.buttonLabel.contains("⌘↓"))
        }
    }

    @MainActor
    func testExtractGlanceInfoNonFileURLDoesNotCrash() {
        let snapApp = DiscoveredApp(
            name: "Left Half",
            url: URL(string: "window-snap://left_half")!,
            bundleIdentifier: "com.micahcrandell.AppsChannel.windowAction.left_half",
            icon: NSImage(),
            category: "Window Management",
            tagBadge: "Snap",
            sizeString: "Action",
            accentColor: .blue,
            windowAction: .leftHalf
        )

        let glance = AppContextSubDeckService.extractGlanceInfo(for: snapApp)
        XCTAssertEqual(glance.architectureBadge, "Window Action")
        XCTAssertEqual(glance.versionString, "Window Snapping")
        XCTAssertFalse(glance.bundlePath.isEmpty)

        let webBookmarkApp = DiscoveredApp(
            name: "GitHub",
            url: URL(string: "https://github.com")!,
            bundleIdentifier: nil,
            icon: NSImage(),
            category: "Bookmarks",
            tagBadge: "WEB",
            sizeString: "Link",
            accentColor: .purple
        )

        let bookmarkGlance = AppContextSubDeckService.extractGlanceInfo(for: webBookmarkApp)
        XCTAssertEqual(bookmarkGlance.architectureBadge, "System Trigger")
        XCTAssertEqual(bookmarkGlance.bundlePath, "https://github.com")
    }

    @MainActor
    func testLoadContextNonFileURLDoesNotCrash() async {
        let service = AppContextSubDeckService.shared
        let snapApp = DiscoveredApp(
            name: "Maximize",
            url: URL(string: "window-snap://maximize")!,
            bundleIdentifier: "com.micahcrandell.AppsChannel.windowAction.maximize",
            icon: NSImage(),
            category: "Window Management",
            tagBadge: "Snap",
            sizeString: "Action",
            accentColor: .blue,
            windowAction: .maximize
        )

        await service.loadContext(for: snapApp)
        XCTAssertEqual(service.contextKind, .systemAction)
        XCTAssertNotNil(service.appGlanceInfo)
        XCTAssertFalse(service.isLoading)
    }

    func testBrowserURLItemModelAndDomainExtraction() {
        let item1 = BrowserURLItem(
            title: "Apple Developer",
            url: URL(string: "https://developer.apple.com/documentation/swiftui")!,
            isPinned: true
        )
        XCTAssertEqual(item1.title, "Apple Developer")
        XCTAssertEqual(item1.domain, "developer.apple.com")
        XCTAssertTrue(item1.isPinned)

        let item2 = BrowserURLItem(
            title: "",
            url: URL(string: "https://www.github.com/apple/swift")!
        )
        XCTAssertEqual(item2.domain, "github.com")
        XCTAssertEqual(item2.title, "github.com")
        XCTAssertFalse(item2.isPinned)
    }

    @MainActor
    func testLoadContextForBrowserPopulatesURLs() async {
        let service = AppContextSubDeckService.shared
        let arcApp = DiscoveredApp(
            name: "Arc",
            url: URL(fileURLWithPath: "/Applications/Arc.app"),
            bundleIdentifier: "company.thebrowser.Browser",
            icon: NSImage(),
            category: "WEB",
            tagBadge: "WEB",
            sizeString: "120 MB",
            accentColor: .pink
        )

        await service.loadContext(for: arcApp)
        XCTAssertEqual(service.contextKind, .browser)
        XCTAssertFalse(service.isLoading)
        // Check that either URLs were discovered from Arc sidebar or fallbacks were provided
        XCTAssertFalse(service.recentURLs.isEmpty)
        XCTAssertTrue(service.recentURLs.first?.url.scheme == "https" || service.recentURLs.first?.url.scheme == "http")
    }

    @MainActor
    func testSubDeckPresentationAndToggle() {
        let service = AppContextSubDeckService.shared
        let dummyApp = DiscoveredApp(
            name: "Test App",
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            bundleIdentifier: "com.test.app",
            icon: NSImage(),
            category: "UTILITIES",
            tagBadge: "TEST",
            sizeString: "10 MB",
            accentColor: .blue
        )

        // Ensure clean initial state
        service.closeSubDeck()
        XCTAssertFalse(service.isSubDeckVisible)
        XCTAssertNil(service.focusedLocation)

        // Open Sub-Deck
        service.openSubDeck(for: dummyApp)
        XCTAssertTrue(service.isSubDeckVisible)
        XCTAssertEqual(service.focusedLocation, SubDeckLocation(row: 0, column: 0))

        // Toggle Sub-Deck (should close)
        service.toggleSubDeck(for: dummyApp)
        XCTAssertFalse(service.isSubDeckVisible)
        XCTAssertNil(service.focusedLocation)

        // Toggle Sub-Deck (should open)
        service.toggleSubDeck(for: dummyApp)
        XCTAssertTrue(service.isSubDeckVisible)
        XCTAssertEqual(service.focusedLocation, SubDeckLocation(row: 0, column: 0))

        // Close Sub-Deck
        service.closeSubDeck()
        XCTAssertFalse(service.isSubDeckVisible)
        XCTAssertNil(service.focusedLocation)
    }

    @MainActor
    func testFocusNavigationUpDownLeftRight() {
        let service = AppContextSubDeckService.shared
        let dummyApp = DiscoveredApp(
            name: "Test App",
            url: URL(fileURLWithPath: "/Applications/Test.app"),
            bundleIdentifier: "com.test.app",
            icon: NSImage(),
            category: "UTILITIES",
            tagBadge: "TEST",
            sizeString: "10 MB",
            accentColor: .blue
        )

        // Start closed
        service.closeSubDeck()

        // Move down from carousel opens sub-deck with focus on row 0, col 0
        service.moveFocusDown(for: dummyApp)
        XCTAssertTrue(service.isSubDeckVisible)
        XCTAssertEqual(service.focusedLocation, SubDeckLocation(row: 0, column: 0))

        // Move down again if next row available
        let rows = service.availableRows(for: dummyApp)
        if rows.count > 1 {
            service.moveFocusDown(for: dummyApp)
            XCTAssertEqual(service.focusedLocation?.row, 1)

            // Move up back to row 0
            service.moveFocusUp(for: dummyApp)
            XCTAssertEqual(service.focusedLocation?.row, 0)
        }

        // From row 0, moveFocusUp returns focus back to carousel tile (focusedLocation = nil)
        service.moveFocusUp(for: dummyApp)
        XCTAssertNil(service.focusedLocation)
        XCTAssertTrue(service.isSubDeckVisible) // Subdeck remains open

        // Move down from carousel re-enters subdeck at row 0
        service.moveFocusDown(for: dummyApp)
        XCTAssertEqual(service.focusedLocation, SubDeckLocation(row: 0, column: 0))

        // Horizontal navigation
        if let maxCols = rows.first, maxCols > 1 {
            service.moveFocusRight(for: dummyApp)
            XCTAssertEqual(service.focusedLocation?.column, 1)

            service.moveFocusLeft()
            XCTAssertEqual(service.focusedLocation?.column, 0)
        }

        // Clean up
        service.closeSubDeck()
    }
}

