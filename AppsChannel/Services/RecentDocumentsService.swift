import Foundation
import AppKit
import SwiftUI
import Combine

struct RecentDocumentItem: Identifiable, Hashable, @unchecked Sendable {
    let id: UUID
    let name: String
    let url: URL
    let icon: NSImage
    let lastUsedDate: Date?

    var formattedRelativeDate: String {
        guard let date = lastUsedDate else { return "Recent" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: RecentDocumentItem, rhs: RecentDocumentItem) -> Bool {
        lhs.url == rhs.url
    }
}

@MainActor
final class RecentDocumentsService: ObservableObject {
    static let shared = RecentDocumentsService()

    @Published private(set) var activeRecentDocuments: [RecentDocumentItem] = []
    @Published private(set) var isQuerying: Bool = false
    @Published private(set) var currentAppURL: URL? = nil

    private init() {}

    func fetchRecentDocuments(for app: DiscoveredApp) async {
        guard app.channelType == nil, app.systemAction == nil, app.url.isFileURL, !app.isSeparator, !app.isAppsChannelApp else {
            self.activeRecentDocuments = []
            self.currentAppURL = app.url
            return
        }

        self.currentAppURL = app.url
        self.isQuerying = true

        let appURL = app.url
        let results = await Task.detached(priority: .userInitiated) { () -> [RecentDocumentItem] in
            return Self.querySpotlightRecentDocuments(forAppAt: appURL)
        }.value

        if self.currentAppURL == app.url {
            self.activeRecentDocuments = results
            self.isQuerying = false
        }
    }

    nonisolated static let blacklistedContentTypes: Set<String> = [
        "public.data",
        "public.content",
        "public.item",
        "public.directory",
        "public.executable",
        "public.archive",
        "public.folder",
        "com.apple.application",
        "com.apple.application-bundle",
        "com.apple.package",
        "com.apple.bundle",
        "com.apple.systempreference.prefpane",
        "com.apple.plugin",
        "com.apple.framework",
        "com.apple.alias-file",
        "com.apple.resolvable",
        "*"
    ]

    nonisolated static let blacklistedExtensions: Set<String> = [
        "*",
        "",
        "app",
        "bundle",
        "kext",
        "plugin",
        "prefpane",
        "framework",
        "dylib",
        "so",
        "o",
        "a",
        "bin",
        "exe",
        "dmg",
        "iso",
        "pkg"
    ]

    nonisolated static func hasDocumentTypes(forAppAt url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let (types, exts) = extractDocumentTypes(forAppAt: url)
        return !types.isEmpty || !exts.isEmpty
    }

    nonisolated static func extractDocumentTypes(forAppAt url: URL) -> (contentTypes: [String], extensions: [String]) {
        guard url.isFileURL,
              let bundle = Bundle(url: url),
              let docTypes = bundle.infoDictionary?["CFBundleDocumentTypes"] as? [[String: Any]] else {
            return ([], [])
        }

        var types: Set<String> = []
        var exts: Set<String> = []

        for dict in docTypes {
            // Ignore document declarations with no active role (e.g. 1Password wildcard file drop handler)
            if let role = dict["CFBundleTypeRole"] as? String, role.caseInsensitiveCompare("None") == .orderedSame {
                continue
            }

            if let contentTypes = dict["LSItemContentTypes"] as? [String] {
                for ct in contentTypes {
                    let trimmed = ct.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !blacklistedContentTypes.contains(trimmed) && !trimmed.hasPrefix("dyn.") {
                        types.insert(trimmed)
                    }
                }
            }
            if let extensions = dict["CFBundleTypeExtensions"] as? [String] {
                for ext in extensions {
                    let cleaned = ext.replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !cleaned.isEmpty && !blacklistedExtensions.contains(cleaned) {
                        exts.insert(cleaned)
                    }
                }
            }
        }

        return (Array(types), Array(exts))
    }

    nonisolated static func querySpotlightRecentDocuments(forAppAt url: URL) -> [RecentDocumentItem] {
        guard url.isFileURL else { return [] }
        let (types, exts) = extractDocumentTypes(forAppAt: url)
        guard !types.isEmpty || !exts.isEmpty else {
            return []
        }

        // Build Spotlight predicate query with positive types and negative application filter
        var subClauses: [String] = []

        for ct in types.prefix(6) {
            subClauses.append("kMDItemContentTypeTree == '\(ct)'")
        }

        for ext in exts.prefix(6) {
            subClauses.append("kMDItemFSName == '*.\(ext)'")
        }

        guard !subClauses.isEmpty else { return [] }

        let typesQuery = subClauses.joined(separator: " || ")
        let fullQuery = "(\(typesQuery)) && (kMDItemContentTypeTree != 'com.apple.application-bundle') && (kMDItemLastUsedDate >= $time.today(-60) || kMDItemContentModificationDate >= $time.today(-60))"

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", homeDir, fullQuery]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            let lines = output.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let fileManager = FileManager.default
            var items: [RecentDocumentItem] = []

            for path in lines {
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: path, isDirectory: &isDir),
                      !path.hasSuffix(".app"),
                      !path.contains("/.Trash/"),
                      !path.contains("/Library/"),
                      !path.contains("/DerivedData/"),
                      !path.contains("/build/"),
                      !path.contains("/node_modules/"),
                      !path.contains("/.git/") else {
                    continue
                }

                // Allow document packages (.xcodeproj, .pages, .keynote, .numbers, .rtfd, .fcpbundle, .logicx)
                let isDocPackage = path.hasSuffix(".xcodeproj") ||
                                   path.hasSuffix(".xcworkspace") ||
                                   path.hasSuffix(".pages") ||
                                   path.hasSuffix(".keynote") ||
                                   path.hasSuffix(".numbers") ||
                                   path.hasSuffix(".rtfd") ||
                                   path.hasSuffix(".fcpbundle") ||
                                   path.hasSuffix(".logicx")

                if isDir.boolValue && !isDocPackage {
                    continue
                }

                let fileURL = URL(fileURLWithPath: path)
                let name = fileURL.lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 32, height: 32)

                let mdItem = MDItemCreateWithURL(kCFAllocatorDefault, fileURL as CFURL)
                let lastUsedDate: Date? = {
                    if let md = mdItem,
                       let cfDate = MDItemCopyAttribute(md, kMDItemLastUsedDate) as? Date {
                        return cfDate
                    }
                    let attrs = try? fileManager.attributesOfItem(atPath: path)
                    return attrs?[.modificationDate] as? Date
                }()

                items.append(RecentDocumentItem(
                    id: UUID(),
                    name: name,
                    url: fileURL,
                    icon: icon,
                    lastUsedDate: lastUsedDate
                ))

                if items.count >= 12 {
                    break
                }
            }

            let sorted = items.sorted { ($0.lastUsedDate ?? .distantPast) > ($1.lastUsedDate ?? .distantPast) }
            return Array(sorted.prefix(6))
        } catch {
            return []
        }
    }
}
