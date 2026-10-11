import Foundation
import AppKit
import Combine
import HotKey

@MainActor
final class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()
    private var hotKey: HotKey?
    private var clipboardHotKey: HotKey?

    @Published var currentShortcutLabel: String = "⌥ + L"
    @Published var currentClipboardShortcutLabel: String = "⌥ + C"

    private let keyCodeStorageKey = "AppsChannelHotKey_KeyCode"
    private let modCodeStorageKey = "AppsChannelHotKey_ModCode"
    private let labelStorageKey = "AppsChannelHotKey_Label"

    private let clipboardKeyCodeStorageKey = "AppsChannelClipboardHotKey_KeyCode"
    private let clipboardModCodeStorageKey = "AppsChannelClipboardHotKey_ModCode"
    private let clipboardLabelStorageKey = "AppsChannelClipboardHotKey_Label"

    struct PresetShortcut: Identifiable {
        let id: String
        let label: String
        let key: Key
        let modifiers: NSEvent.ModifierFlags
    }

    let presets: [PresetShortcut] = [
        PresetShortcut(id: "opt_l", label: "⌥ + L", key: .l, modifiers: [.option]),
        PresetShortcut(id: "opt_space", label: "⌥ + Space", key: .space, modifiers: [.option]),
        PresetShortcut(id: "cmd_opt_space", label: "⌘ + ⌥ + Space", key: .space, modifiers: [.command, .option]),
        PresetShortcut(id: "ctrl_space", label: "⌃ + Space", key: .space, modifiers: [.control]),
        PresetShortcut(id: "shift_cmd_space", label: "⇧ + ⌘ + Space", key: .space, modifiers: [.shift, .command]),
        PresetShortcut(id: "opt_k", label: "⌥ + K", key: .k, modifiers: [.option])
    ]

    func registerHotKey() {
        if let label = UserDefaults.standard.string(forKey: labelStorageKey) {
            currentShortcutLabel = label
        }

        let savedKey = UserDefaults.standard.object(forKey: keyCodeStorageKey) as? UInt32
        let savedMod = UserDefaults.standard.object(forKey: modCodeStorageKey) as? UInt32

        if let keyVal = savedKey, let modVal = savedMod {
            let combo = KeyCombo(carbonKeyCode: keyVal, carbonModifiers: modVal)
            apply(keyCombo: combo)
        } else {
            let defaultCombo = KeyCombo(key: .l, modifiers: [.option])
            apply(keyCombo: defaultCombo)
        }

        registerClipboardHotKey()
    }

    func registerClipboardHotKey() {
        if let label = UserDefaults.standard.string(forKey: clipboardLabelStorageKey) {
            currentClipboardShortcutLabel = label
        }

        let savedKey = UserDefaults.standard.object(forKey: clipboardKeyCodeStorageKey) as? UInt32
        let savedMod = UserDefaults.standard.object(forKey: clipboardModCodeStorageKey) as? UInt32

        if let keyVal = savedKey, let modVal = savedMod {
            let combo = KeyCombo(carbonKeyCode: keyVal, carbonModifiers: modVal)
            applyClipboard(keyCombo: combo)
        } else {
            let defaultCombo = KeyCombo(key: .c, modifiers: [.option])
            applyClipboard(keyCombo: defaultCombo)
        }
    }

    func applyPreset(_ preset: PresetShortcut) {
        let combo = KeyCombo(key: preset.key, modifiers: preset.modifiers)
        UserDefaults.standard.set(combo.carbonKeyCode, forKey: keyCodeStorageKey)
        UserDefaults.standard.set(combo.carbonModifiers, forKey: modCodeStorageKey)
        UserDefaults.standard.set(preset.label, forKey: labelStorageKey)
        currentShortcutLabel = preset.label
        apply(keyCombo: combo)
    }

    func applyCustom(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, label: String) {
        let combo = KeyCombo(carbonKeyCode: keyCode, carbonModifiers: modifiers.carbonFlags)
        UserDefaults.standard.set(combo.carbonKeyCode, forKey: keyCodeStorageKey)
        UserDefaults.standard.set(combo.carbonModifiers, forKey: modCodeStorageKey)
        UserDefaults.standard.set(label, forKey: labelStorageKey)
        currentShortcutLabel = label
        apply(keyCombo: combo)
    }

    func applyClipboardCustom(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, label: String) {
        let combo = KeyCombo(carbonKeyCode: keyCode, carbonModifiers: modifiers.carbonFlags)
        UserDefaults.standard.set(combo.carbonKeyCode, forKey: clipboardKeyCodeStorageKey)
        UserDefaults.standard.set(combo.carbonModifiers, forKey: clipboardModCodeStorageKey)
        UserDefaults.standard.set(label, forKey: clipboardLabelStorageKey)
        currentClipboardShortcutLabel = label
        applyClipboard(keyCombo: combo)
    }

    private func apply(keyCombo: KeyCombo) {
        hotKey = nil
        hotKey = HotKey(keyCombo: keyCombo)
        hotKey?.keyDownHandler = {
            DispatchQueue.main.async {
                PanelController.shared.toggle()
            }
        }
    }

    private func applyClipboard(keyCombo: KeyCombo) {
        clipboardHotKey = nil
        clipboardHotKey = HotKey(keyCombo: keyCombo)
        clipboardHotKey?.keyDownHandler = {
            DispatchQueue.main.async {
                PanelController.shared.toggleClipboardHistory()
            }
        }
    }
}
