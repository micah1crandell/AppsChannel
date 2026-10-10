import SwiftUI
import AppKit

// MARK: - App Context Menu & Quick Action Operations
struct AppCardContextMenu: ViewModifier {
    let app: DiscoveredApp
    let onLaunch: () -> Void

    @ObservedObject private var discoveryService = AppDiscoveryService.shared

    func body(content: Content) -> some View {
        content.contextMenu {
            if !app.isAppsChannelApp {
                Button {
                    onLaunch()
                } label: {
                    Label(discoveryService.isRunning(app: app) ? "Switch to Application" : "Launch Application", systemImage: "arrow.up.right.square")
                }

                Divider()

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([app.url])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }

                Button {
                    openGetInfo(for: app.url)
                } label: {
                    Label("Get Info", systemImage: "info.circle")
                }

                Menu {
                    Button {
                        copyToClipboard(app.url.path)
                    } label: {
                        Label("Copy Path", systemImage: "doc.on.doc")
                    }

                    if let bundleId = app.bundleIdentifier {
                        Button {
                            copyToClipboard(bundleId)
                        } label: {
                            Label("Copy Bundle ID", systemImage: "tag")
                        }
                    }
                } label: {
                    Label("Copy Details", systemImage: "doc.on.clipboard")
                }

                if discoveryService.isRunning(app: app) {
                    Divider()

                    Button {
                        discoveryService.terminateApp(app, force: false)
                    } label: {
                        Label("Quit Application", systemImage: "xmark.circle")
                    }

                    Button(role: .destructive) {
                        discoveryService.terminateApp(app, force: true)
                    } label: {
                        Label("Force Quit", systemImage: "exclamationmark.octagon")
                    }
                }

                Divider()

                Button(role: .destructive) {
                    discoveryService.hideApp(app)
                } label: {
                    Label("Hide from AppsChannel", systemImage: "eye.slash")
                }
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func openGetInfo(for url: URL) {
        let escapedPath = url.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Finder"
            activate
            open information window of (POSIX file "\(escapedPath)" as alias)
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

extension View {
    func appContextMenu(for app: DiscoveredApp, onLaunch: @escaping () -> Void) -> some View {
        self.modifier(AppCardContextMenu(app: app, onLaunch: onLaunch))
    }
}
