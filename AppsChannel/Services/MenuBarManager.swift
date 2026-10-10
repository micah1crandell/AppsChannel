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
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "AppsChannel (Click to open, Right-click for options)"
        }

        buildContextMenu()
        self.statusItem = item
    }

    private func buildContextMenu() {
        let menu = NSMenu()

        let openMainItem = NSMenuItem(
            title: "Open AppsChannel Window",
            action: #selector(openMainApp),
            keyEquivalent: ""
        )
        openMainItem.target = self
        openMainItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        menu.addItem(openMainItem)

        let openQuickItem = NSMenuItem(
            title: "Open Quick Launcher",
            action: #selector(openQuickLauncher),
            keyEquivalent: ""
        )
        openQuickItem.target = self
        openQuickItem.image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: nil)
        menu.addItem(openQuickItem)

        menu.addItem(NSMenuItem.separator())

        let tourItem = NSMenuItem(
            title: "Welcome Walkthrough...",
            action: #selector(openWalkthrough),
            keyEquivalent: ""
        )
        tourItem.target = self
        tourItem.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
        menu.addItem(tourItem)

        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
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
        quitItem.target = self
        menu.addItem(quitItem)

        self.contextMenu = menu
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            PanelController.shared.toggleMainApp()
            return
        }

        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            // Right-click or Control-click: Show Context Menu
            if let menu = contextMenu {
                statusItem?.menu = menu
                statusItem?.button?.performClick(nil)
                statusItem?.menu = nil
            }
        } else {
            // Left-click: Toggle / Open Main App Window
            PanelController.shared.toggleMainApp()
        }
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

    @objc private func openWalkthrough() {
        PanelController.shared.showMainApp()
        NotificationCenter.default.post(name: .openWalkthrough, object: nil)
    }

    @objc private func checkForUpdates() {
        UpdateManager.shared.checkForUpdates()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
