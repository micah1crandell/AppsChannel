import AppKit
import SwiftUI
import Combine

// MARK: - Keyboard Modifier Manager
@MainActor
final class KeyboardModifierManager: ObservableObject {
    static let shared = KeyboardModifierManager()

    @Published private(set) var isCommandPressed: Bool = false
    @Published private(set) var isOptionPressed: Bool = false
    @Published private(set) var isShiftPressed: Bool = false
    @Published private(set) var isControlPressed: Bool = false

    private init() {}

    func update(from flags: NSEvent.ModifierFlags) {
        let cmd = flags.contains(.command)
        let opt = flags.contains(.option)
        let shf = flags.contains(.shift)
        let ctrl = flags.contains(.control)

        if isCommandPressed != cmd || isOptionPressed != opt || isShiftPressed != shf || isControlPressed != ctrl {
            isCommandPressed = cmd
            isOptionPressed = opt
            isShiftPressed = shf
            isControlPressed = ctrl
        }
    }

    func reset() {
        if isCommandPressed || isOptionPressed || isShiftPressed || isControlPressed {
            isCommandPressed = false
            isOptionPressed = false
            isShiftPressed = false
            isControlPressed = false
        }
    }

    var hasActiveModifier: Bool {
        isCommandPressed || isOptionPressed || isShiftPressed
    }

    var activeModifierSymbol: String? {
        if isCommandPressed { return "⌘" }
        if isOptionPressed { return "⌥" }
        if isShiftPressed { return "⇧" }
        if isControlPressed { return "⌃" }
        return nil
    }

    var primaryActionHint: (label: String, key: String, icon: String)? {
        if isCommandPressed {
            return ("Reveal in Finder", "⌘↵", "folder.fill")
        } else if isShiftPressed {
            return ("Copy Path", "⇧↵", "doc.on.doc.fill")
        }
        return nil
    }
}
