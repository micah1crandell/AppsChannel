import AppKit
import SwiftUI

@MainActor
final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var contextMenu: NSMenu?

    func setup() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            if let image = NSImage(systemSymbolName: "square.grid.3x3.topleft.filled", accessibilityDescription: "AppsChannel")?.withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            }
            button.toolTip = "AppsChannel"
        }

        let menu = buildContextMenu()
        item.menu = menu
        self.contextMenu = menu
        self.statusItem = item
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

        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        updateItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        menu.addItem(updateItem)

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
