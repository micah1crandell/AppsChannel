import SwiftUI

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
    func applicationDidFinishLaunching(_ notification: Notification) {
        PanelController.shared.setup()
        MenuBarManager.shared.setup()
        HotKeyManager.shared.registerHotKey()

        // Run as a Menu Bar tool without living in the macOS Dock
        PanelController.shared.setDockVisibility(showInDock: false)

        // Show the Main App window on launch so the user sees the app
        PanelController.shared.showMainApp()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PanelController.shared.showMainApp()
        return true
    }
}
