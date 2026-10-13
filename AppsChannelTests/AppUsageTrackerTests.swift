import XCTest
@testable import AppsChannel

final class AppUsageTrackerTests: XCTestCase {

    @MainActor
    func testArrangeMiddleOutOrdering() {
        let tracker = AppUsageTracker.shared
        let input = ["Rank1", "Rank2", "Rank3", "Rank4", "Rank5"]

        let result = tracker.arrangeMiddleOut(input)

        // Count is 5, center index is 2
        XCTAssertEqual(result.arranged.count, 5)
        XCTAssertEqual(result.centerIndex, 2)

        // Center item (index 2) must be Rank 1
        XCTAssertEqual(result.arranged[2], "Rank1")

        // Radiating outward:
        // Index 3 (Center + 1) = Rank 2
        XCTAssertEqual(result.arranged[3], "Rank2")
        // Index 1 (Center - 1) = Rank 3
        XCTAssertEqual(result.arranged[1], "Rank3")
        // Index 4 (Center + 2) = Rank 4
        XCTAssertEqual(result.arranged[4], "Rank4")
        // Index 0 (Center - 2) = Rank 5
        XCTAssertEqual(result.arranged[0], "Rank5")
    }

    @MainActor
    func testMiddleOutSingleItem() {
        let tracker = AppUsageTracker.shared
        let input = ["SoloApp"]
        let result = tracker.arrangeMiddleOut(input)

        XCTAssertEqual(result.arranged, ["SoloApp"])
        XCTAssertEqual(result.centerIndex, 0)
    }

    @MainActor
    func testMiddleOutEmptyInput() {
        let tracker = AppUsageTracker.shared
        let input: [String] = []
        let result = tracker.arrangeMiddleOut(input)

        XCTAssertTrue(result.arranged.isEmpty)
        XCTAssertEqual(result.centerIndex, 0)
    }

    @MainActor
    func testCommonAliasesMatching() {
        let tracker = AppUsageTracker.shared
        let testApp = DiscoveredApp(
            id: UUID(),
            name: "Visual Studio Code",
            url: URL(fileURLWithPath: "/Applications/Visual Studio Code.app"),
            bundleIdentifier: "com.microsoft.VSCode",
            icon: NSImage(),
            category: "Developer Tools",
            tagBadge: "DEV",
            sizeString: "150 MB",
            accentColor: .blue
        )

        // Searching "code" should give high alias score
        let score = tracker.searchScore(for: testApp, query: "code")
        XCTAssertGreaterThan(score, 100.0)

        // Irrelevant search should have much lower score
        let lowScore = tracker.searchScore(for: testApp, query: "unrelated_xyz_app")
        XCTAssertLessThan(lowScore, score)
    }

    @MainActor
    func testRecordUsageAcrossAllKinds() {
        let tracker = AppUsageTracker.shared
        tracker.resetAnalytics()

        let now = Date()
        let currentMonth = AppUsageTracker.currentMonthKey(date: now)

        // 1. Record an application launch
        tracker.recordUsage(id: "/Applications/Safari.app", name: "Safari", kind: .application, date: now)
        tracker.recordUsage(id: "/Applications/Safari.app", name: "Safari", kind: .application, date: now)

        // 2. Record a window action
        tracker.recordUsage(id: "window-snap://center", name: "Center", kind: .windowAction, date: now)

        // 3. Record a custom channel
        tracker.recordUsage(id: "custom://google", name: "Google", kind: .customChannel, date: now)
        tracker.recordUsage(id: "custom://google", name: "Google", kind: .customChannel, date: now)
        tracker.recordUsage(id: "custom://google", name: "Google", kind: .customChannel, date: now)

        // 4. Record a system action
        tracker.recordUsage(id: "system://sleep", name: "Sleep", kind: .systemAction, date: now)

        // 5. Record clipboard paste
        tracker.recordUsage(id: "clipboard://paste", name: "Clipboard Paste", kind: .clipboard, date: now)

        let summary = tracker.summary(for: currentMonth)
        XCTAssertEqual(summary.totalActions, 8)
        XCTAssertEqual(summary.byKind[.application], 2)
        XCTAssertEqual(summary.byKind[.windowAction], 1)
        XCTAssertEqual(summary.byKind[.customChannel], 3)
        XCTAssertEqual(summary.byKind[.systemAction], 1)
        XCTAssertEqual(summary.byKind[.clipboard], 1)

        // Top overall item should be Google (count 3)
        XCTAssertEqual(summary.topItem?.name, "Google")
        XCTAssertEqual(summary.topItem?.count, 3)

        // Top app should be Safari (count 2)
        XCTAssertEqual(summary.topApp?.name, "Safari")
        XCTAssertEqual(summary.topApp?.count, 2)

        // Top window action should be Center (count 1)
        XCTAssertEqual(summary.topWindowAction?.name, "Center")

        // Top channel should be Google
        XCTAssertEqual(summary.topChannel?.name, "Google")

        // All-time summary should also match
        let allTime = tracker.summary(for: "all_time")
        XCTAssertEqual(allTime.totalActions, 8)
        XCTAssertEqual(allTime.topItem?.name, "Google")
    }

    @MainActor
    func testWindowActionsDoNotAffectAppRanking() {
        let tracker = AppUsageTracker.shared
        tracker.resetAnalytics()

        let now = Date()

        // Record 500 window center snaps
        for _ in 0..<500 {
            tracker.recordUsage(id: "window-snap://center", name: "Center Window", kind: .windowAction, date: now)
        }

        // Window action must NOT be in appRecords
        XCTAssertNil(tracker.stats.appRecords["window-snap://center"])

        // App usage score for a window action app tile should be -100.0
        let windowActionApp = DiscoveredApp(
            id: UUID(),
            name: "Center Window",
            url: URL(string: "window-snap://center")!,
            bundleIdentifier: "com.micahcrandell.AppsChannel.windowAction.center",
            icon: NSImage(),
            category: "Window Management",
            tagBadge: "WIN",
            sizeString: "",
            accentColor: .purple,
            windowAction: .center
        )
        XCTAssertEqual(tracker.usageScore(for: windowActionApp), -100.0)

        // An actual app launched once should have higher rank than window action
        tracker.recordUsage(id: "/Applications/Calculator.app", name: "Calculator", kind: .application, date: now)
        let calcApp = DiscoveredApp(
            id: UUID(),
            name: "Calculator",
            url: URL(fileURLWithPath: "/Applications/Calculator.app"),
            bundleIdentifier: "com.apple.calculator",
            icon: NSImage(),
            category: "Utilities",
            tagBadge: "APP",
            sizeString: "10 MB",
            accentColor: .orange
        )
        XCTAssertGreaterThan(tracker.usageScore(for: calcApp), tracker.usageScore(for: windowActionApp))
    }

    @MainActor
    func testMonthlyBucketsSeparation() {
        let tracker = AppUsageTracker.shared
        tracker.resetAnalytics()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let septDate = formatter.date(from: "2026-09-15")!
        let octDate = formatter.date(from: "2026-10-10")!

        tracker.recordUsage(id: "custom://september", name: "Sept Item", kind: .customChannel, date: septDate)
        tracker.recordUsage(id: "custom://october", name: "Oct Item", kind: .customChannel, date: octDate)
        tracker.recordUsage(id: "custom://october", name: "Oct Item", kind: .customChannel, date: octDate)

        let septSummary = tracker.summary(for: "2026-09")
        XCTAssertEqual(septSummary.totalActions, 1)
        XCTAssertEqual(septSummary.topItem?.name, "Sept Item")

        let octSummary = tracker.summary(for: "2026-10")
        XCTAssertEqual(octSummary.totalActions, 2)
        XCTAssertEqual(octSummary.topItem?.name, "Oct Item")

        let allTime = tracker.summary(for: "all_time")
        XCTAssertEqual(allTime.totalActions, 3)

        let months = tracker.availableMonthKeys()
        XCTAssertTrue(months.contains("2026-09"))
        XCTAssertTrue(months.contains("2026-10"))
    }

    @MainActor
    func testResetAnalyticsClearsAllHistory() {
        let tracker = AppUsageTracker.shared
        tracker.recordUsage(id: "/Applications/Notes.app", name: "Notes", kind: .application)
        tracker.recordUsage(id: "window-snap://maximize", name: "Maximize", kind: .windowAction)

        XCTAssertFalse(tracker.stats.allTimeRecords.isEmpty)

        tracker.resetAnalytics()

        XCTAssertTrue(tracker.stats.allTimeRecords.isEmpty)
        XCTAssertTrue(tracker.stats.monthlyBuckets.isEmpty)
        XCTAssertTrue(tracker.stats.appRecords.isEmpty)
    }
}
