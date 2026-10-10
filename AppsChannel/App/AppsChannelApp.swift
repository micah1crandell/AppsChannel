import SwiftUI
import AppKit

@main
struct AppsChannelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene keeps the app active without rendering a default window
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didHandleInitialOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        PanelController.shared.setup()
        MenuBarManager.shared.setup()
        HotKeyManager.shared.registerHotKey()

        // Run as a Menu Bar tool without living in the macOS Dock
        PanelController.shared.setDockVisibility(showInDock: false)

        // Sync Launch at Login status
        LaunchAtLoginManager.shared.refreshStatus()

        // Handle initial presentation on next runloop turn so any incoming open URL takes precedence
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.didHandleInitialOpen {
                self.handleInitialLaunch()
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        didHandleInitialOpen = true
        for url in urls {
            handleURL(url)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PanelController.shared.show()
        return true
    }

    private func handleInitialLaunch() {
        let args = CommandLine.arguments

        if args.contains("--quick") {
            PanelController.shared.showQuickLauncher()
            return
        }
        if args.contains("--main") || args.contains("--fullscreen") {
            PanelController.shared.showMainApp()
            return
        }
        if args.contains("--background") || args.contains("--login") {
            // Started silently at login in background: do not show any window
            return
        }

        // Regular user launch: show according to user's default launcher preference
        PanelController.shared.show()
    }

    func handleURL(_ url: URL) {
        guard url.scheme?.lowercased() == "appschannel" else { return }
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()

        if host == "quick" || path == "/quick" {
            PanelController.shared.showQuickLauncher()
        } else if host == "main" || host == "fullscreen" || path == "/main" {
            PanelController.shared.showMainApp()
        } else if host == "toggle" || path == "/toggle" {
            PanelController.shared.toggleQuickLauncher()
        } else {
            PanelController.shared.show()
        }
    }
}
