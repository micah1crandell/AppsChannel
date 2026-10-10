import Foundation
import SwiftUI
import AppKit
import Combine

enum CustomChannelKind: String, Codable, Sendable {
    case web = "web"
    case shortcut = "shortcut"
    case script = "script"
}

struct CustomChannelRecord: Identifiable, Codable, Sendable {
    var id: UUID
    var name: String
    var kind: CustomChannelKind
    var target: String // URL string (e.g. "https://github.com") or shortcut name
    var accentHex: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        kind: CustomChannelKind,
        target: String,
        accentHex: String = "#0A84FF",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.target = target
        self.accentHex = accentHex
        self.createdAt = createdAt
    }
}

@MainActor
final class CustomChannelManager: ObservableObject {
    static let shared = CustomChannelManager()

    @Published private(set) var channels: [CustomChannelRecord] = []
    @Published private(set) var availableShortcuts: [String] = []

    private static var storageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AppsChannel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("custom_channels.json")
    }

    private static var faviconsDir: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = caches.appendingPathComponent("AppsChannel/Favicons", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {
        loadChannels()
        refreshShortcutsList()
    }

    func loadChannels() {
        guard let data = try? Data(contentsOf: Self.storageURL),
              let decoded = try? JSONDecoder().decode([CustomChannelRecord].self, from: data) else {
            self.channels = []
            return
        }
        self.channels = decoded
    }

    func saveChannels() {
        if let data = try? JSONEncoder().encode(channels) {
            try? data.write(to: Self.storageURL, options: .atomic)
        }
    }

    func addWebChannel(name: String, urlString: String, accentHex: String = "#0A84FF") {
        var cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.lowercased().hasPrefix("http://") && !cleanURL.lowercased().hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }

        let record = CustomChannelRecord(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: .web,
            target: cleanURL,
            accentHex: accentHex
        )
        channels.append(record)
        saveChannels()
        fetchFavicon(for: record)
        AppDiscoveryService.shared.reloadAfterCustomChannelChange()
    }

    func addShortcutChannel(name: String, shortcutName: String, accentHex: String = "#FF9500") {
        let record = CustomChannelRecord(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: .shortcut,
            target: shortcutName.trimmingCharacters(in: .whitespacesAndNewlines),
            accentHex: accentHex
        )
        channels.append(record)
        saveChannels()
        AppDiscoveryService.shared.reloadAfterCustomChannelChange()
    }

    func addScriptChannel(name: String, command: String, accentHex: String = "#30D158") {
        let record = CustomChannelRecord(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: .script,
            target: command.trimmingCharacters(in: .whitespacesAndNewlines),
            accentHex: accentHex
        )
        channels.append(record)
        saveChannels()
        AppDiscoveryService.shared.reloadAfterCustomChannelChange()
    }

    func removeChannel(id: UUID) {
        channels.removeAll { $0.id == id }
        saveChannels()
        AppDiscoveryService.shared.reloadAfterCustomChannelChange()
    }

    func refreshShortcutsList() {
        Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["list"]

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let items = output.components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    await MainActor.run {
                        Self.shared.availableShortcuts = items
                    }
                }
            } catch {
                print("Unable to list shortcuts: \(error.localizedDescription)")
            }
        }
    }

    private func fetchFavicon(for record: CustomChannelRecord) {
        guard let url = URL(string: record.target),
              let host = url.host else { return }

        let faviconURLString = "https://www.google.com/s2/favicons?domain=\(host)&sz=128"
        guard let requestURL = URL(string: faviconURLString) else { return }

        let localFile = Self.faviconsDir.appendingPathComponent("\(record.id.uuidString).png")

        Task.detached(priority: .background) {
            if let (data, response) = try? await URLSession.shared.data(from: requestURL),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let _ = NSImage(data: data) {
                try? data.write(to: localFile, options: .atomic)
                await MainActor.run {
                    AppDiscoveryService.shared.reloadAfterCustomChannelChange()
                }
            }
        }
    }

    func toDiscoveredApps() -> [DiscoveredApp] {
        return channels.map { record in
            let accent = Color(hex: record.accentHex) ?? (record.kind == .web ? .blue : (record.kind == .shortcut ? .orange : .green))
            let icon = iconFor(record: record, accent: accent)

            let channelURL: URL = {
                switch record.kind {
                case .web:
                    return URL(string: record.target) ?? URL(string: "https://apple.com")!
                case .shortcut:
                    let escaped = record.target.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? record.target
                    return URL(string: "shortcuts://run-shortcut?name=\(escaped)") ?? URL(string: "shortcuts://")!
                case .script:
                    return URL(fileURLWithPath: "/bin/zsh")
                }
            }()

            let (cat, tag, size): (String, String, String) = {
                switch record.kind {
                case .web: return ("WEB CHANNEL", "Web Link", "Cloud")
                case .shortcut: return ("SHORTCUT", "Shortcut", "Local")
                case .script: return ("SCRIPT", "Shell CLI", "Script")
                }
            }()

            return DiscoveredApp(
                id: record.id,
                name: record.name,
                url: channelURL,
                bundleIdentifier: record.kind == .web ? "com.apple.Safari" : (record.kind == .shortcut ? "com.apple.shortcuts" : "com.apple.Terminal"),
                icon: icon,
                category: cat,
                tagBadge: tag,
                sizeString: size,
                accentColor: accent,
                channelType: record.kind,
                customChannelId: record.id
            )
        }
    }

    private func iconFor(record: CustomChannelRecord, accent: Color) -> NSImage {
        // Check disk cache for downloaded web favicon
        if record.kind == .web {
            let localFile = Self.faviconsDir.appendingPathComponent("\(record.id.uuidString).png")
            if let data = try? Data(contentsOf: localFile), let img = NSImage(data: data) {
                return img
            }
        }

        // SF Symbol fallback image
        let size = NSSize(width: 140, height: 140)
        let img = NSImage(size: size, flipped: false) { rect in
            let symbolName: String = {
                switch record.kind {
                case .web: return "globe"
                case .shortcut: return "bolt.fill"
                case .script: return "terminal.fill"
                }
            }()
            let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .semibold)
            if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let tinted = symbol.copy() as! NSImage
                let drawRect = NSRect(x: 24, y: 24, width: 92, height: 92)
                tinted.draw(in: drawRect)
                return true
            }
            return false
        }
        return img
    }
}

// MARK: - Color Hex Initializer
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let length = hexSanitized.count
        if length == 6 {
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        } else if length == 8 {
            self.init(
                red: Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                opacity: Double(rgb & 0x000000FF) / 255.0
            )
        } else {
            return nil
        }
    }
}
