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
        HotKeyManager.shared.registerHotKey()

        // Sync user presence preferences (Dock / Menu Bar)
        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        let showInMenuBar = UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? true

        PanelController.shared.setDockVisibility(showInDock: showInDock)
        if showInMenuBar {
            MenuBarManager.shared.setup()
        } else {
            MenuBarManager.shared.setVisibility(false)
        }

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
            let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedWalkthrough")
            if !hasCompleted {
                PanelController.shared.showMainApp()
                DispatchQueue.main.async {
                    MainAppState.shared.isShowingWalkthrough = true
                }
                return
            }
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
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedWalkthrough")
        if !hasCompleted {
            PanelController.shared.showMainApp()
            DispatchQueue.main.async {
                MainAppState.shared.isShowingWalkthrough = true
            }
            return true
        }
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

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryParams: [String: String] = [:]
        if let queryItems = components?.queryItems {
            for item in queryItems {
                queryParams[item.name.lowercased()] = item.value
            }
        }

        if host == "quick" || path == "/quick" {
            PanelController.shared.showQuickLauncher()
        } else if host == "main" || host == "fullscreen" || path == "/main" {
            PanelController.shared.showMainApp()
        } else if host == "close" || host == "hide" || path == "/close" || path == "/hide" {
            PanelController.shared.hide()
        } else if host == "toggle" || path == "/toggle" {
            PanelController.shared.toggle()
        } else if host == "preferences" || host == "settings" || path == "/preferences" || path == "/settings" {
            PanelController.shared.showMainApp()
            DispatchQueue.main.async {
                MainAppState.shared.isShowingSettings = true
            }
        } else if host == "walkthrough" || host == "tour" || path == "/walkthrough" || path == "/tour" {
            PanelController.shared.showMainApp()
            DispatchQueue.main.async {
                MainAppState.shared.isShowingWalkthrough = true
            }
        } else if host == "theme" || path.hasPrefix("/theme") {
            var rawTheme = queryParams["name"] ?? queryParams["theme"]
            if rawTheme == nil && path.hasPrefix("/theme/") {
                rawTheme = String(path.dropFirst("/theme/".count)).removingPercentEncoding
            }
            if let targetTheme = rawTheme, let theme = AppVisualTheme.from(string: targetTheme) {
                ThemeManager.shared.setTheme(theme)
            }
        } else if host == "launch" || path.hasPrefix("/launch") {
            var targetQuery = queryParams["query"] ?? queryParams["name"] ?? queryParams["q"]
            if (targetQuery == nil || targetQuery?.isEmpty == true) && path.hasPrefix("/launch/") {
                targetQuery = String(path.dropFirst("/launch/".count)).removingPercentEncoding
            }
            if let target = targetQuery, !target.isEmpty {
                DispatchQueue.main.async {
                    if let app = AppDiscoveryService.shared.findApp(matching: target) {
                        AppDiscoveryService.shared.launch(app: app, query: target)
                    }
                }
            }
        } else {
            PanelController.shared.showQuickLauncher()
        }
    }
}
