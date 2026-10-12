import AppKit
import SwiftUI

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var contextMenu: NSMenu?

    func setup() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = createMenuBarIcon()
            button.imagePosition = .imageOnly
            button.toolTip = "AppsChannel"
        }

        let menu = buildContextMenu()
        item.menu = menu
        self.contextMenu = menu
        self.statusItem = item
    }

    func setVisibility(_ isVisible: Bool) {
        if isVisible {
            if statusItem == nil {
                setup()
            }
        } else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
                contextMenu = nil
            }
        }
    }

    /// Generates a crisp, vector template icon modeled directly on the AppsChannel Cover Flow app icon.
    private func createMenuBarIcon() -> NSImage {
        let size = NSSize(width: 20, height: 16)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let midX: CGFloat = rect.midX
            let midY: CGFloat = rect.midY

            let strokeW: CGFloat = 1.15
            ctx.setLineWidth(strokeW)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setStrokeColor(NSColor.black.cgColor)

            let centerW: CGFloat = 7.5
            let centerH: CGFloat = 11.2
            let centerRect = CGRect(x: midX - centerW / 2, y: midY - centerH / 2, width: centerW, height: centerH)
            let centerPath = CGPath(roundedRect: centerRect, cornerWidth: 2.0, cornerHeight: 2.0, transform: nil)

            // 3 side cards on each side (Cover Flow receding perspective stack)
            let cardOffsets: [(dx: CGFloat, h: CGFloat, r: CGFloat)] = [
                (2.0, 9.8, 1.7),
                (3.8, 8.4, 1.4),
                (5.4, 7.0, 1.2)
            ]

            // Draw receding cards from back to front
            for offset in cardOffsets.reversed() {
                let leftR = CGRect(x: midX - centerW / 2 - offset.dx, y: midY - offset.h / 2, width: centerW, height: offset.h)
                let rightR = CGRect(x: midX - centerW / 2 + offset.dx, y: midY - offset.h / 2, width: centerW, height: offset.h)

                ctx.addPath(CGPath(roundedRect: leftR, cornerWidth: offset.r, cornerHeight: offset.r, transform: nil))
                ctx.strokePath()
                ctx.addPath(CGPath(roundedRect: rightR, cornerWidth: offset.r, cornerHeight: offset.r, transform: nil))
                ctx.strokePath()
            }

            // Clear behind center card so side cards don't show through the center
            ctx.saveGState()
            ctx.addPath(centerPath)
            ctx.setBlendMode(.clear)
            ctx.fillPath()
            ctx.restoreGState()

            // Stroke center hero card
            ctx.addPath(centerPath)
            ctx.strokePath()

            return true
        }
        image.isTemplate = true
        return image
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu()

        let openMainItem = NSMenuItem(
            title: "Open AppsChannel Window",
            action: #selector(openMainApp),
            keyEquivalent: "0"
        )
        openMainItem.keyEquivalentModifierMask = [.command]
        openMainItem.target = self
        openMainItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        menu.addItem(openMainItem)

        let openQuickItem = NSMenuItem(
            title: "Open Quick Launcher",
            action: #selector(openQuickLauncher),
            keyEquivalent: "l"
        )
        openQuickItem.keyEquivalentModifierMask = [.option]
        openQuickItem.target = self
        openQuickItem.image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: nil)
        menu.addItem(openQuickItem)

        let clipboardItem = NSMenuItem(
            title: "Clipboard History",
            action: #selector(openClipboardHistory),
            keyEquivalent: "c"
        )
        clipboardItem.keyEquivalentModifierMask = [.option]
        clipboardItem.target = self
        clipboardItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        menu.addItem(clipboardItem)

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.keyEquivalentModifierMask = [.command]
        prefsItem.target = self
        prefsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(prefsItem)

#if !APP_STORE
        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        menu.addItem(updateItem)
#endif

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit AppsChannel",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func openMainApp() {
        PanelController.shared.showMainApp()
    }

    @objc private func openQuickLauncher() {
        PanelController.shared.showQuickLauncher()
    }

    @objc private func openClipboardHistory() {
        PanelController.shared.showClipboardHistory()
    }

    @objc private func openPreferences() {
        PanelController.shared.showMainApp()
        NotificationCenter.default.post(name: Notification.Name("AppsChannelOpenPreferences"), object: nil)
    }

    @objc private func checkForUpdates() {
        UpdateManager.shared.checkForUpdates()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
