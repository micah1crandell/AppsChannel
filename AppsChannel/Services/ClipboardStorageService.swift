import Foundation
import AppKit

public final class ClipboardStorageService: Sendable {
    public static let shared = ClipboardStorageService()

    private let fileManager = FileManager.default

    private var baseDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = appSupport.appendingPathComponent("AppsChannel/Clipboard", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var imagesDirectory: URL {
        let dir = baseDirectory.appendingPathComponent("Images", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private var historyFileURL: URL {
        baseDirectory.appendingPathComponent("history.json")
    }

    // MARK: - Loading & Saving Items
    public func loadItems() -> [ClipboardItem] {
        guard fileManager.fileExists(atPath: historyFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: historyFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([ClipboardItem].self, from: data)
        } catch {
            print("[ClipboardStorageService] Error loading items: \(error)")
            return []
        }
    }

    public func saveItems(_ items: [ClipboardItem]) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(items)
            try data.write(to: historyFileURL, options: .atomic)
        } catch {
            print("[ClipboardStorageService] Error saving items: \(error)")
        }
    }

    // MARK: - Image Management
    public func saveImage(data: Data) -> String? {
        let filename = "\(UUID().uuidString).png"
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: .atomic)
            return filename
        } catch {
            print("[ClipboardStorageService] Error saving image: \(error)")
            return nil
        }
    }

    public func loadImage(filename: String) -> NSImage? {
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return NSImage(contentsOf: fileURL)
    }

    public func deleteImage(filename: String) {
        let fileURL = imagesDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: fileURL)
    }

    // MARK: - Pruning & Retention
    public func pruneItems(
        _ items: [ClipboardItem],
        retention: ClipboardRetentionDuration,
        maxItems: Int = 500
    ) -> [ClipboardItem] {
        let now = Date()
        var pruned = items

        // 1. Retention period filter (keep pinned always)
        if let limitSeconds = retention.timeInterval {
            let cutoffDate = now.addingTimeInterval(-limitSeconds)
            var activeItems: [ClipboardItem] = []
            for item in pruned {
                if item.isPinned || item.copiedAt >= cutoffDate {
                    activeItems.append(item)
                } else if let img = item.imageFilename {
                    deleteImage(filename: img)
                }
            }
            pruned = activeItems
        }

        // 2. Max items cap (preserve pinned items, trim oldest unpinned)
        if pruned.count > maxItems {
            let pinned = pruned.filter { $0.isPinned }
            var unpinned = pruned.filter { !$0.isPinned }

            let allowedUnpinnedCount = max(0, maxItems - pinned.count)
            if unpinned.count > allowedUnpinnedCount {
                let toRemove = unpinned.suffix(unpinned.count - allowedUnpinnedCount)
                for item in toRemove {
                    if let img = item.imageFilename {
                        deleteImage(filename: img)
                    }
                }
                unpinned = Array(unpinned.prefix(allowedUnpinnedCount))
            }

            // Merge back maintaining original relative recency
            let allowedIds = Set((pinned + unpinned).map { $0.id })
            pruned = pruned.filter { allowedIds.contains($0.id) }
        }

        return pruned
    }

    // MARK: - Clear History
    public func clearAllHistory(
        items: [ClipboardItem],
        preservePinned: Bool = true
    ) -> [ClipboardItem] {
        var remaining: [ClipboardItem] = []
        for item in items {
            if preservePinned && item.isPinned {
                remaining.append(item)
            } else {
                if let img = item.imageFilename {
                    deleteImage(filename: img)
                }
            }
        }
        saveItems(remaining)
        return remaining
    }

    // MARK: - Disk Usage
    public func calculateDiskUsage() -> Int64 {
        var totalBytes: Int64 = 0
        if let historyAttrs = try? fileManager.attributesOfItem(atPath: historyFileURL.path),
           let size = historyAttrs[.size] as? Int64 {
            totalBytes += size
        }

        if let enumerator = fileManager.enumerator(at: imagesDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let size = resourceValues.fileSize {
                    totalBytes += Int64(size)
                }
            }
        }
        return totalBytes
    }
}
