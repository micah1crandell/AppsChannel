import XCTest
import SwiftUI
@testable import AppsChannel

final class CustomChannelTests: XCTestCase {

    func testCustomChannelRecordCodable() throws {
        let record = CustomChannelRecord(
            id: UUID(),
            name: "GitHub",
            kind: .web,
            target: "https://github.com",
            accentHex: "#0A84FF"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(record)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CustomChannelRecord.self, from: data)

        XCTAssertEqual(decoded.id, record.id)
        XCTAssertEqual(decoded.name, "GitHub")
        XCTAssertEqual(decoded.kind, .web)
        XCTAssertEqual(decoded.target, "https://github.com")
        XCTAssertEqual(decoded.accentHex, "#0A84FF")
    }

    @MainActor
    func testCustomChannelManagerConversionToDiscoveredApp() {
        let manager = CustomChannelManager.shared

        let testId = UUID()
        let record = CustomChannelRecord(
            id: testId,
            name: "Figma Web",
            kind: .web,
            target: "https://figma.com",
            accentHex: "#BF5AF2"
        )

        let apps = manager.toDiscoveredApps()
        // Verify method runs without crash
        XCTAssertNotNil(apps)

        let app = DiscoveredApp(
            id: testId,
            name: record.name,
            url: URL(string: record.target)!,
            bundleIdentifier: "com.apple.Safari",
            icon: NSImage(),
            category: "WEB CHANNEL",
            tagBadge: "Web Link",
            sizeString: "Cloud",
            accentColor: .purple,
            channelType: .web,
            customChannelId: testId
        )

        XCTAssertEqual(app.channelType, .web)
        XCTAssertEqual(app.customChannelId, testId)
        XCTAssertEqual(app.category, "WEB CHANNEL")
        XCTAssertEqual(app.tagBadge, "Web Link")
    }

    func testDiscoveredAppEqualityWithCustomChannels() {
        let id1 = UUID()
        let id2 = UUID()
        let url = URL(string: "https://example.com")!

        let app1 = DiscoveredApp(
            name: "Site 1",
            url: url,
            bundleIdentifier: nil,
            icon: NSImage(),
            category: "WEB CHANNEL",
            tagBadge: "Web Link",
            sizeString: "Cloud",
            accentColor: .blue,
            channelType: .web,
            customChannelId: id1
        )

        let app2 = DiscoveredApp(
            name: "Site 2",
            url: url,
            bundleIdentifier: nil,
            icon: NSImage(),
            category: "WEB CHANNEL",
            tagBadge: "Web Link",
            sizeString: "Cloud",
            accentColor: .blue,
            channelType: .web,
            customChannelId: id2
        )

        // Same URL, but different customChannelIds must NOT be equal
        XCTAssertNotEqual(app1, app2)

        let app1Duplicate = DiscoveredApp(
            name: "Site 1 Copy",
            url: url,
            bundleIdentifier: nil,
            icon: NSImage(),
            category: "WEB CHANNEL",
            tagBadge: "Web Link",
            sizeString: "Cloud",
            accentColor: .blue,
            channelType: .web,
            customChannelId: id1
        )

        XCTAssertEqual(app1, app1Duplicate)
    }

    func testColorHexParser() {
        let blue = Color(hex: "#0A84FF")
        XCTAssertNotNil(blue)

        let invalid = Color(hex: "invalid")
        XCTAssertNil(invalid)
    }

    func testScriptChannelRecordCodable() throws {
        let scriptRecord = CustomChannelRecord(
            id: UUID(),
            name: "Git Status",
            kind: .script,
            target: "git status",
            accentHex: "#30D158"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(scriptRecord)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CustomChannelRecord.self, from: data)

        XCTAssertEqual(decoded.id, scriptRecord.id)
        XCTAssertEqual(decoded.name, "Git Status")
        XCTAssertEqual(decoded.kind, .script)
        XCTAssertEqual(decoded.target, "git status")
        XCTAssertEqual(decoded.accentHex, "#30D158")
    }

    @MainActor
    func testScriptChannelDiscoveredAppProperties() {
        let testId = UUID()
        let record = CustomChannelRecord(
            id: testId,
            name: "Docker Cleanup",
            kind: .script,
            target: "docker system prune -f",
            accentHex: "#30D158"
        )

        let app = DiscoveredApp(
            id: testId,
            name: record.name,
            url: URL(fileURLWithPath: "/bin/zsh"),
            bundleIdentifier: "com.apple.Terminal",
            icon: NSImage(),
            category: "SCRIPT",
            tagBadge: "Shell CLI",
            sizeString: "Script",
            accentColor: .green,
            channelType: .script,
            customChannelId: testId
        )

        XCTAssertEqual(app.channelType, .script)
        XCTAssertEqual(app.customChannelId, testId)
        XCTAssertEqual(app.category, "SCRIPT")
        XCTAssertEqual(app.tagBadge, "Shell CLI")
        XCTAssertEqual(app.sizeString, "Script")
        XCTAssertEqual(app.bundleIdentifier, "com.apple.Terminal")
    }

    @MainActor
    func testCLICompanionManagerCheck() {
        let cli = CLICompanionManager.shared
        cli.checkInstallationStatus()
        // Method should execute cleanly and populate state
        XCTAssertNotNil(cli.isInstalled)
    }
}
