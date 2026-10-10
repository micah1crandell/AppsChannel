import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - App Launch Analytics Record
struct AppLaunchRecord: Codable, Sendable {
    var launchCount: Int
    var lastLaunchedAt: Date
}

// MARK: - App Usage Stats Persistence Structure
struct AppUsageStats: Codable, Sendable {
    var appRecords: [String: AppLaunchRecord] = [:]
    var searchAssociations: [String: [String: Int]] = [:]
}

// MARK: - App Usage Tracker Service
@MainActor
final class AppUsageTracker: ObservableObject {
    static let shared = AppUsageTracker()

    @Published private(set) var stats: AppUsageStats = AppUsageStats()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.micahcrandell.AppsChannel.usageTracker", qos: .utility)

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AppsChannel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("usage_analytics.json")
        loadStats()
    }

    // MARK: - Record App Launch & Query Association
    func recordLaunch(app: DiscoveredApp, query: String? = nil) {
        guard !app.isAppsChannelApp, app.url.path != "/", !app.url.path.isEmpty, app.url.path.hasSuffix(".app") else { return }
        let pathKey = app.url.path

        // 1. Update Launch Count & Recency
        var record = stats.appRecords[pathKey] ?? AppLaunchRecord(launchCount: 0, lastLaunchedAt: Date())
        record.launchCount += 1
        record.lastLaunchedAt = Date()
        stats.appRecords[pathKey] = record

        // 2. Associate Search Query with Selected App
        if let query = query?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !query.isEmpty {
            var associations = stats.searchAssociations[query] ?? [:]
            associations[pathKey, default: 0] += 1
            stats.searchAssociations[query] = associations
        }

        saveStats()
    }

    // MARK: - Scoring: General Browsing (Default Mode)
    func usageScore(for app: DiscoveredApp) -> Double {
        let baseWeight = intrinsicBaseWeight(for: app)
        let pathKey = app.url.path
        guard let record = stats.appRecords[pathKey] else {
            return baseWeight
        }

        let baseScore = Double(record.launchCount) * 15.0
        let secondsAgo = Date().timeIntervalSince(record.lastLaunchedAt)

        // Exponential-like recency tiers
        let recencyBonus: Double
        if secondsAgo < 6 * 3600 {
            recencyBonus = 60.0
        } else if secondsAgo < 24 * 3600 {
            recencyBonus = 40.0
        } else if secondsAgo < 3 * 86400 {
            recencyBonus = 25.0
        } else if secondsAgo < 7 * 86400 {
            recencyBonus = 12.0
        } else {
            recencyBonus = max(0.0, 5.0 - (secondsAgo / (30 * 86400)))
        }

        return baseWeight + baseScore + recencyBonus
    }

    // MARK: - Expanded Popular & Trending Flagship Catalog
    private static let flagshipKeywords: [String] = [
        // AI & Modern Productivity
        "chatgpt", "claude", "claude code", "cursor", "antigravity", "gemini",
        "ollama", "perplexity", "raycast", "warp", "ghostty", "zed", "windsurf",
        "superwhisper", "copilot", "github copilot", "codex",

        // Developer & Engineering Tools
        "visual studio code", "vs code", "xcode", "sublime text", "intellij",
        "pycharm", "webstorm", "docker", "orbstack", "postman", "tableplus",
        "github desktop", "gitkraken", "iterm", "iterm2", "terminal", "insomnia",
        "tower", "sourcetree", "alacritty", "kitty",

        // Web Browsers
        "arc", "safari", "google chrome", "chrome", "brave", "brave browser",
        "firefox", "microsoft edge", "edge", "orion", "duckduckgo", "zen browser", "vivaldi",

        // Communication & Social
        "slack", "discord", "messages", "facetime", "zoom", "microsoft teams",
        "teams", "telegram", "whatsapp", "signal",

        // Creative, Design, 3D & Video Editing
        "figma", "photoshop", "illustrator", "indesign", "lightroom", "premiere",
        "premiere pro", "after effects", "davinci resolve", "final cut pro",
        "blender", "cinema 4d", "canva", "pixelmator", "pixelmator pro",
        "affinity photo", "affinity designer", "affinity publisher", "sketch", "linear",

        // Audio & Music Production
        "music", "spotify", "apple music", "ableton live", "ableton", "logic pro",
        "fl studio", "pro tools", "audacity", "garageband", "reaper", "tidal",

        // Writing, Knowledge & Office
        "notes", "notion", "obsidian", "craft", "bear", "logseq", "reminders",
        "calendar", "fantastical", "todoist", "things", "microsoft word", "word",
        "microsoft excel", "excel", "microsoft powerpoint", "powerpoint",
        "microsoft outlook", "outlook", "pages", "numbers", "keynote", "goodnotes", "scrivener",

        // macOS Core Essentials
        "finder", "photos", "mail", "weather", "maps", "calculator", "clock", "freeform", "system settings"
    ]

    static func isFlagshipApp(name: String) -> Bool {
        let lower = name.lowercased()
        let words = Set(lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })

        for pat in flagshipKeywords {
            if pat.contains(" ") {
                if lower.contains(pat) { return true }
            } else {
                if words.contains(pat) || lower == pat || lower.hasPrefix(pat + " ") {
                    return true
                }
            }
        }
        return false
    }

    /// Intrinsic importance weight based on app location, type, and daily utility.
    /// Ensures primary apps (Arc, Safari, Slack, Code, Xcode, Notes, etc.) appear first
    /// even before the user has launched them from AppsChannel.
    func intrinsicBaseWeight(for app: DiscoveredApp) -> Double {
        let p = app.url.path
        let name = app.name

        let flagshipBonus: Double = Self.isFlagshipApp(name: name) ? 25.0 : 0.0

        let locWeight: Double
        if p.hasPrefix("/Applications/") && !p.contains("/Utilities/") {
            locWeight = 75.0
        } else if p.hasPrefix("/System/Applications/") && !p.contains("/Utilities/") {
            locWeight = 70.0
        } else if p.contains(FileManager.default.homeDirectoryForCurrentUser.path + "/Applications/") {
            locWeight = 65.0
        } else if p.contains("/Utilities/") {
            locWeight = 30.0
        } else {
            locWeight = 20.0
        }

        return locWeight + flagshipBonus
    }

    // MARK: - App Aliases Mapping for Quick Match
    private static let commonAliases: [String: [String]] = [
        "term": ["terminal", "iterm", "iterm2", "warp", "ghostty", "alacritty", "kitty", "hyper"],
        "terminal": ["iterm", "iterm2", "warp", "ghostty", "alacritty", "kitty"],
        "bash": ["terminal", "iterm", "iterm2", "warp", "ghostty"],
        "cmd": ["terminal", "iterm", "iterm2", "warp", "ghostty"],
        "calc": ["calculator", "numi", "soulver", "pcam"],
        "code": ["visual studio code", "cursor", "xcode", "sublime text", "zed", "windsurf", "claude code", "nova", "intellij"],
        "editor": ["visual studio code", "cursor", "textedit", "sublime text", "zed", "windsurf", "bbedit"],
        "ai": ["chatgpt", "claude", "cursor", "antigravity", "gemini", "ollama", "perplexity", "copilot"],
        "llm": ["chatgpt", "claude", "ollama", "gemini", "antigravity", "cursor"],
        "claude": ["claude", "claude code"],
        "cursor": ["cursor"],
        "browser": ["safari", "google chrome", "arc", "firefox", "brave browser", "edge", "orion", "zen browser"],
        "web": ["safari", "google chrome", "arc", "firefox", "brave browser", "edge"],
        "chrome": ["google chrome"],
        "music": ["apple music", "spotify", "tidal"],
        "chat": ["slack", "discord", "messages", "telegram", "whatsapp", "signal", "teams"],
        "mail": ["mail", "mimestream", "spark", "outlook"],
        "notes": ["notes", "bear", "craft", "notion", "obsidian", "logseq"],
        "doc": ["pages", "microsoft word", "word", "notion"],
        "office": ["microsoft word", "microsoft excel", "microsoft powerpoint", "pages", "numbers", "keynote"],
        "sheet": ["microsoft excel", "numbers", "excel"],
        "sheets": ["microsoft excel", "numbers", "excel"],
        "presentation": ["keynote", "microsoft powerpoint", "powerpoint", "canva"],
        "slides": ["keynote", "microsoft powerpoint", "powerpoint", "canva"],
        "photo": ["photos", "lightroom", "photoshop", "pixelmator pro", "affinity photo"],
        "design": ["figma", "sketch", "canva", "photoshop", "illustrator", "pixelmator pro", "affinity designer"],
        "video": ["final cut pro", "davinci resolve", "premiere pro", "imovie", "screenflow", "capcut", "blender"],
        "audio": ["logic pro", "ableton live", "fl studio", "pro tools", "audacity", "garageband", "reaper"],
        "daw": ["logic pro", "ableton live", "fl studio", "pro tools", "garageband", "reaper"],
        "git": ["github desktop", "gitkraken", "tower", "sourcetree", "terminal"],
        "docker": ["docker", "orbstack"],
        "meet": ["zoom", "teams", "microsoft teams", "facetime", "slack", "discord"],
        "call": ["zoom", "teams", "microsoft teams", "facetime", "slack", "discord"],
        "pref": ["system settings", "system preferences"],
        "settings": ["system settings", "system preferences"]
    ]

    // MARK: - Scoring: Search Query Smart Relevance
    func searchScore(for app: DiscoveredApp, query: String) -> Double {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else {
            return usageScore(for: app)
        }

        var score: Double = 0.0
        let pathKey = app.url.path
        let name = app.name.lowercased()

        // 1. Direct Association Learning (e.g. user previously searched "code" -> chose "vscode")
        if let directMatches = stats.searchAssociations[q], let count = directMatches[pathKey] {
            if name.contains(q) || app.category.lowercased().contains(q) || count >= 2 {
                score += 200.0 * Double(min(count, 10))
            }
        }

        // 2. Prefix Association Learning (e.g. user typed "cod" and previously chose app for "code")
        for (pastQuery, appMap) in stats.searchAssociations {
            guard pastQuery != q, pastQuery.count >= 2 else { continue }
            if q.hasPrefix(pastQuery) {
                // If current query extends past query, only boost if the app actually matches q
                guard name.contains(q) || app.category.lowercased().contains(q) else { continue }
                if let count = appMap[pathKey] {
                    score += 60.0 * Double(min(count, 5))
                }
            } else if pastQuery.hasPrefix(q) {
                guard name.contains(pastQuery) || app.category.lowercased().contains(pastQuery) else { continue }
                if let count = appMap[pathKey] {
                    score += 60.0 * Double(min(count, 5))
                }
            }
        }

        // 3. Textual Relevance Matches
        if name == q {
            score += 200.0 // Exact match
        } else if name.hasPrefix(q) {
            score += 110.0 // Starts with query
        }

        // Word boundary match (e.g. query "code" matches "Visual Studio Code")
        let words = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        if words.contains(where: { $0.hasPrefix(q) }) {
            score += 95.0
        } else if name.contains(q) {
            score += 50.0
        }

        // Acronym match (e.g. "vsc" matches "Visual Studio Code", "gc" matches "Google Chrome")
        let acronym = words.compactMap { $0.first }.map { String($0) }.joined()
        if acronym == q || acronym.hasPrefix(q) {
            score += 85.0
        }

        // Fuzzy subsequence match (e.g. "spot" matches "Spotify", "gc" matches "Google Chrome")
        if Self.fuzzyMatch(needle: q, haystack: name) {
            score += 45.0
        }

        // 4. Aliases Match (e.g. "calc" -> "Calculator", "term" -> "iTerm")
        for (aliasKey, targets) in Self.commonAliases {
            if q == aliasKey || (q.count >= 3 && aliasKey.hasPrefix(q)) {
                if targets.contains(where: { name.contains($0) }) {
                    score += 120.0
                }
            }
        }

        // 5. Category match
        if app.category.lowercased().contains(q) {
            score += 30.0
        }

        // 6. Overall Usage Tie-Breaker (Only applied to break ties when an actual match exists)
        if score > 0, let record = stats.appRecords[pathKey] {
            score += min(Double(record.launchCount) * 3.0, 35.0)
        }

        return score
    }

    private static func fuzzyMatch(needle: String, haystack: String) -> Bool {
        guard !needle.isEmpty else { return true }
        var nIdx = needle.startIndex
        var hIdx = haystack.startIndex

        while nIdx < needle.endIndex && hIdx < haystack.endIndex {
            if needle[nIdx] == haystack[hIdx] {
                nIdx = needle.index(after: nIdx)
            }
            hIdx = haystack.index(after: hIdx)
        }
        return nIdx == needle.endIndex
    }

    // MARK: - Middle-Origin Fan Arrangement
    /// Arranges apps so:
    /// - Center index M is Rank #1 (highest score / most used)
    /// - M + 1 (Right) is Rank #2
    /// - M - 1 (Left) is Rank #3
    /// - M + 2 (Right) is Rank #4
    /// - M - 2 (Left) is Rank #5
    /// - M + 3 (Right) is Rank #6
    /// - M - 3 (Left) is Rank #7, etc.
    ///
    /// Special constraint: AppsChannel itself is excluded from the top 5 spots (ranks 1..5)
    /// to avoid usage bias from frequent launcher opening.
    func arrangeMiddleOut<T>(_ ranked: [T]) -> (arranged: [T], centerIndex: Int) {
        guard !ranked.isEmpty else { return ([], 0) }
        guard ranked.count > 1 else { return (ranked, 0) }

        var adjustedRanked = ranked

        // If the ranked array contains DiscoveredApp, ensure AppsChannel is not in the top 5
        if let appList = ranked as? [DiscoveredApp] {
            var nonSelfApps: [DiscoveredApp] = []
            var selfApps: [DiscoveredApp] = []

            for app in appList {
                if app.isAppsChannelApp {
                    selfApps.append(app)
                } else {
                    nonSelfApps.append(app)
                }
            }

            if !selfApps.isEmpty {
                // Keep top 5 non-AppsChannel apps first, then inject selfApps starting at rank 6 (index 5)
                let topCount = min(5, nonSelfApps.count)
                var reordered: [DiscoveredApp] = []
                reordered.append(contentsOf: nonSelfApps.prefix(topCount))
                reordered.append(contentsOf: selfApps)
                if nonSelfApps.count > topCount {
                    reordered.append(contentsOf: nonSelfApps.suffix(from: topCount))
                }
                adjustedRanked = reordered as! [T]
            }
        }

        let count = adjustedRanked.count
        var result: [T?] = Array(repeating: nil, count: count)
        let center = count / 2

        // Center gets Rank #1
        result[center] = adjustedRanked[0]

        var rightOffset = 1
        var leftOffset = 1

        for i in 1..<count {
            let item = adjustedRanked[i]
            let wantRight = (i % 2 == 1)

            if wantRight {
                let rightTarget = center + rightOffset
                if rightTarget < count {
                    result[rightTarget] = item
                    rightOffset += 1
                } else {
                    let leftTarget = center - leftOffset
                    if leftTarget >= 0 {
                        result[leftTarget] = item
                        leftOffset += 1
                    }
                }
            } else {
                let leftTarget = center - leftOffset
                if leftTarget >= 0 {
                    result[leftTarget] = item
                    leftOffset += 1
                } else {
                    let rightTarget = center + rightOffset
                    if rightTarget < count {
                        result[rightTarget] = item
                        rightOffset += 1
                    }
                }
            }
        }

        // Unwrapped result guaranteed to contain all elements uniquely
        let finalArranged = result.compactMap { $0 }
        return (finalArranged, center)
    }

    // MARK: - Settings Support
    func topLaunchedApps(limit: Int = 10) -> [(path: String, count: Int, lastLaunched: Date)] {
        stats.appRecords.map { (path: $0.key, count: $0.value.launchCount, lastLaunched: $0.value.lastLaunchedAt) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }

    func resetAnalytics() {
        stats = AppUsageStats()
        saveStats()
    }

    // MARK: - Persistence
    private func saveStats() {
        let statsCopy = self.stats
        let url = self.fileURL
        queue.async {
            if let data = try? JSONEncoder().encode(statsCopy) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private func loadStats() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode(AppUsageStats.self, from: data) {
            var cleanedStats = decoded
            cleanedStats.appRecords = cleanedStats.appRecords.filter {
                !$0.key.lowercased().contains("appschannel") && $0.key != "/" && $0.key.hasSuffix(".app")
            }
            for (query, map) in cleanedStats.searchAssociations {
                let filteredMap = map.filter { path, count in
                    if path.lowercased().contains("appschannel") || path == "/" || !path.hasSuffix(".app") { return false }
                    let appName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent.lowercased()
                    let q = query.lowercased()
                    let isAlias = Self.commonAliases[q]?.contains(where: { appName.contains($0) }) ?? false
                    return appName.contains(q) || q.contains(appName) || isAlias || count >= 3
                }
                if filteredMap.isEmpty {
                    cleanedStats.searchAssociations.removeValue(forKey: query)
                } else {
                    cleanedStats.searchAssociations[query] = filteredMap
                }
            }
            self.stats = cleanedStats
        }
    }
}
