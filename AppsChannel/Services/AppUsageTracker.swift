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
        let pathKey = app.url.path
        guard let record = stats.appRecords[pathKey] else {
            return 0.0
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

        return baseScore + recencyBonus
    }

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
            score += 250.0 * Double(min(count, 10))
        }

        // 2. Prefix Association Learning (e.g. user typed "cod" and previously chose app for "code")
        for (pastQuery, appMap) in stats.searchAssociations {
            if pastQuery != q && (pastQuery.hasPrefix(q) || q.hasPrefix(pastQuery)) {
                if let count = appMap[pathKey] {
                    score += 80.0 * Double(min(count, 5))
                }
            }
        }

        // 3. Textual Relevance Matches
        if name == q {
            score += 180.0 // Exact match
        } else if name.hasPrefix(q) {
            score += 90.0 // Starts with query
        }

        // Word boundary match (e.g. query "code" matches "Visual Studio Code")
        let words = name.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        if words.contains(where: { $0.hasPrefix(q) }) {
            score += 85.0
        } else if name.contains(q) {
            score += 40.0
        }

        // Acronym match (e.g. "vsc" matches "Visual Studio Code")
        let acronym = words.compactMap { $0.first }.map { String($0) }.joined()
        if acronym == q || acronym.hasPrefix(q) {
            score += 70.0
        }

        // 4. Category match
        if app.category.lowercased().contains(q) {
            score += 25.0
        }

        // 5. Overall Usage Tie-Breaker
        if let record = stats.appRecords[pathKey] {
            score += min(Double(record.launchCount) * 3.0, 35.0)
        }

        return score
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
    func arrangeMiddleOut<T>(_ ranked: [T]) -> (arranged: [T], centerIndex: Int) {
        guard !ranked.isEmpty else { return ([], 0) }
        guard ranked.count > 1 else { return (ranked, 0) }

        let count = ranked.count
        var result: [T?] = Array(repeating: nil, count: count)
        let center = count / 2

        // Center gets Rank #1
        result[center] = ranked[0]

        var rightOffset = 1
        var leftOffset = 1

        for i in 1..<count {
            let item = ranked[i]
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
            self.stats = decoded
        }
    }
}
