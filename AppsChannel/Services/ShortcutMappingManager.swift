import Foundation
import SwiftUI
import Combine

@MainActor
final class ShortcutMappingManager: ObservableObject {
    static let shared = ShortcutMappingManager()

    // MARK: - UserDefaults Storage Keys
    private let groupShortcutsKey = "AppsChannelGroupShortcutsCustom"
    private let channelSlotsKey = "AppsChannelChannelSlotsCustom"

    /// Custom mappings for Group Shortcuts ⌘1..⌘8 (slot: 1...8 -> category name)
    @Published var customGroupShortcuts: [Int: String] = [:]

    /// Custom mappings for Channel Slots ⌥1..⌥9 (slot: 1...9 -> app file URL path)
    @Published var customChannelSlots: [Int: String] = [:]

    private init() {
        loadMappings()
    }

    // MARK: - Group Shortcuts (⌘1 through ⌘8)

    /// Returns the assigned category for slot 1...8, falling back to the standard category order if uncustomized.
    func category(forSlot slot: Int, availableCategories: [String]) -> String? {
        if let custom = customGroupShortcuts[slot], !custom.isEmpty {
            return custom
        }
        // Default: slot 1 is index 0 ("ALL"), slot 2 is index 1, etc.
        let defaultIndex = slot - 1
        if defaultIndex >= 0, defaultIndex < availableCategories.count {
            return availableCategories[defaultIndex]
        }
        return nil
    }

    /// Sets or removes a custom category for group shortcut slot (1...8).
    func setGroupShortcut(category: String?, forSlot slot: Int) {
        guard slot >= 1 && slot <= 8 else { return }
        if let cat = category, !cat.isEmpty {
            customGroupShortcuts[slot] = cat
        } else {
            customGroupShortcuts.removeValue(forKey: slot)
        }
        saveGroupShortcuts()
    }

    /// Resets all group shortcuts back to automatic sequential order.
    func resetGroupShortcuts() {
        customGroupShortcuts.removeAll()
        UserDefaults.standard.removeObject(forKey: groupShortcutsKey)
    }

    // MARK: - Channel Slots (⌥1 through ⌥9)

    /// Returns the custom assigned app path for slot 1...9, or nil if using default grid position.
    func assignedAppPath(forSlot slot: Int) -> String? {
        guard slot >= 1 && slot <= 9 else { return nil }
        return customChannelSlots[slot]
    }

    /// Resolves the assigned DiscoveredApp for slot 1...9, or nil if uncustomized.
    func assignedApp(forSlot slot: Int, in allApps: [DiscoveredApp]) -> DiscoveredApp? {
        guard let path = assignedAppPath(forSlot: slot) else { return nil }
        return allApps.first(where: { $0.url.path == path })
    }

    /// Sets or removes a custom assigned app for slot 1...9.
    func setChannelSlot(appPath: String?, forSlot slot: Int) {
        guard slot >= 1 && slot <= 9 else { return }
        if let path = appPath, !path.isEmpty {
            customChannelSlots[slot] = path
        } else {
            customChannelSlots.removeValue(forKey: slot)
        }
        saveChannelSlots()
    }

    /// Resets all channel slots back to default grid order.
    func resetChannelSlots() {
        customChannelSlots.removeAll()
        UserDefaults.standard.removeObject(forKey: channelSlotsKey)
    }

    // MARK: - Persistence
    private func loadMappings() {
        if let dict = UserDefaults.standard.dictionary(forKey: groupShortcutsKey) as? [String: String] {
            var loaded: [Int: String] = [:]
            for (k, v) in dict {
                if let slot = Int(k), slot >= 1, slot <= 8 {
                    loaded[slot] = v
                }
            }
            self.customGroupShortcuts = loaded
        }

        if let dict = UserDefaults.standard.dictionary(forKey: channelSlotsKey) as? [String: String] {
            var loaded: [Int: String] = [:]
            for (k, v) in dict {
                if let slot = Int(k), slot >= 1, slot <= 9 {
                    loaded[slot] = v
                }
            }
            self.customChannelSlots = loaded
        }
    }

    private func saveGroupShortcuts() {
        var dict: [String: String] = [:]
        for (k, v) in customGroupShortcuts {
            dict[String(k)] = v
        }
        UserDefaults.standard.set(dict, forKey: groupShortcutsKey)
    }

    private func saveChannelSlots() {
        var dict: [String: String] = [:]
        for (k, v) in customChannelSlots {
            dict[String(k)] = v
        }
        UserDefaults.standard.set(dict, forKey: channelSlotsKey)
    }
}
