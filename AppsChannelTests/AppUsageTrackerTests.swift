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
}
