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
}
