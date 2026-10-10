import SwiftUI
import AppKit

@main
struct AppsChannelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene keeps the app active without rendering a default window
        Settings {
            EmptyView()
                .onOpenURL { url in
                    appDelegate.handleURL(url)
                }
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

        // Handle external Open App events (e.g. from macOS Shortcuts 'Open App' action)
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleAppleEvent(_:withReply:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenApplication)
        )
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleAppleEvent(_:withReply:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEReopenApplication)
        )

        // Handle initial presentation on next runloop turn so any incoming open URL takes precedence
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.didHandleInitialOpen {
                self.handleInitialLaunch()
            }
        }
    }

    @objc private func handleAppleEvent(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        didHandleInitialOpen = true
        DispatchQueue.main.async {
            if PanelController.shared.isQuickLauncherVisible {
                PanelController.shared.hide()
            } else {
                PanelController.shared.show()
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
        if PanelController.shared.isQuickLauncherVisible {
            PanelController.shared.hide()
        } else {
            PanelController.shared.show()
        }
        return true
    }

    private func handleInitialLaunch() {
        let args = CommandLine.arguments

        if args.contains("--main") || args.contains("--fullscreen") {
            PanelController.shared.showMainApp()
            return
        }
        if args.contains("--background") || args.contains("--login") {
            // Started silently at login in background: do not show any window
            return
        }
        if args.contains("--quick") {
            PanelController.shared.showQuickLauncher()
            return
        }
        if args.contains("--tour") || args.contains("--walkthrough") {
            PanelController.shared.showMainApp()
            DispatchQueue.main.async {
                MainAppState.shared.isShowingWalkthrough = true
            }
            return
        }

        // First time open walkthrough: check if user has completed it
        let hasCompletedWalkthrough = UserDefaults.standard.bool(forKey: "hasCompletedWalkthrough")
        if !hasCompletedWalkthrough {
            PanelController.shared.showMainApp()
            DispatchQueue.main.async {
                MainAppState.shared.isShowingWalkthrough = true
            }
            return
        }

        // Regular user launch: show according to user's default launcher preference (defaults to Quick Launcher)
        PanelController.shared.show()
    }

    func handleURL(_ url: URL) {
        didHandleInitialOpen = true
        guard url.scheme?.lowercased() == "appschannel" else { return }
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        let full = url.absoluteString.lowercased()

        if host == "quick" || path == "/quick" || full.contains("quick") {
            PanelController.shared.showQuickLauncher()
        } else if host == "main" || host == "fullscreen" || path == "/main" || full.contains("main") {
            PanelController.shared.showMainApp()
        } else if host == "walkthrough" || host == "tour" || path == "/walkthrough" || path == "/tour" || full.contains("walkthrough") || full.contains("tour") {
            PanelController.shared.showMainApp()
            DispatchQueue.main.async {
                MainAppState.shared.isShowingWalkthrough = true
            }
        } else if host == "toggle" || path == "/toggle" || full.contains("toggle") {
            PanelController.shared.toggle()
        } else {
            PanelController.shared.showQuickLauncher()
        }
    }
}
