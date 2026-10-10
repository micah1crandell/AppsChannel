import SwiftUI
import AppKit

// MARK: - App Context Menu & Quick Action Operations
struct AppCardContextMenu: ViewModifier {
    let app: DiscoveredApp
    let onLaunch: () -> Void

    @ObservedObject private var discoveryService = AppDiscoveryService.shared

    func body(content: Content) -> some View {
        content.contextMenu {
            if let customId = app.customChannelId {
                Button {
                    onLaunch()
                } label: {
                    Label(app.channelType == .web ? "Open Website" : "Run Shortcut", systemImage: "arrow.up.right.square")
                }

                Divider()

                Button {
                    copyToClipboard(app.url.absoluteString)
                } label: {
                    Label("Copy Link / Target", systemImage: "doc.on.doc")
                }

                Menu {
                    ForEach(1...9, id: \.self) { slot in
                        Button {
                            ShortcutMappingManager.shared.setChannelSlot(appPath: "custom://\(customId.uuidString)", forSlot: slot)
                            SoundEffectsManager.shared.playAction()
                        } label: {
                            if ShortcutMappingManager.shared.assignedAppPath(forSlot: slot) == "custom://\(customId.uuidString)" {
                                Text("✓ Slot \(slot) (⌥\(slot))")
                            } else {
                                Text("Slot \(slot) (⌥\(slot))")
                            }
                        }
                    }
                } label: {
                    Label("Assign to Slot (⌥1–9)", systemImage: "target")
                }

                Divider()

                Button(role: .destructive) {
                    CustomChannelManager.shared.removeChannel(id: customId)
                    SoundEffectsManager.shared.playAction()
                } label: {
                    Label("Delete Custom Channel", systemImage: "trash")
                }
            } else if !app.isAppsChannelApp && !app.isSeparator {
                Button {
                    onLaunch()
                } label: {
                    Label(discoveryService.isRunning(app: app) ? "Switch to Application" : "Launch Application", systemImage: "arrow.up.right.square")
                }

                if RecentDocumentsService.hasDocumentTypes(forAppAt: app.url) {
                    Button {
                        NotificationCenter.default.post(name: .toggleRecentDocuments, object: app)
                    } label: {
                        Label("Show Recent Documents (⌘↓)", systemImage: "clock.arrow.circlepath")
                    }
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

                Menu {
                    ForEach(1...9, id: \.self) { slot in
                        Button {
                            ShortcutMappingManager.shared.setChannelSlot(appPath: app.url.path, forSlot: slot)
                            SoundEffectsManager.shared.playAction()
                        } label: {
                            if ShortcutMappingManager.shared.assignedAppPath(forSlot: slot) == app.url.path {
                                Text("✓ Slot \(slot) (⌥\(slot))")
                            } else {
                                Text("Slot \(slot) (⌥\(slot))")
                            }
                        }
                    }

                    let isAssignedToAny = (1...9).contains { ShortcutMappingManager.shared.assignedAppPath(forSlot: $0) == app.url.path }
                    if isAssignedToAny {
                        Divider()
                        Button {
                            for slot in 1...9 {
                                if ShortcutMappingManager.shared.assignedAppPath(forSlot: slot) == app.url.path {
                                    ShortcutMappingManager.shared.setChannelSlot(appPath: nil, forSlot: slot)
                                }
                            }
                            SoundEffectsManager.shared.playAction()
                        } label: {
                            Text("Remove from Quick Launch Slots")
                        }
                    }
                } label: {
                    Label("Assign to Slot (⌥1–9)", systemImage: "target")
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

                if discoveryService.isHidden(app: app) || app.isHiddenApp {
                    Button {
                        discoveryService.unhideApp(path: app.url.path)
                    } label: {
                        Label("Unhide in AppsChannel", systemImage: "eye")
                    }
                } else {
                    Button(role: .destructive) {
                        discoveryService.hideApp(app)
                    } label: {
                        Label("Hide from AppsChannel", systemImage: "eye.slash")
                    }
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

extension Notification.Name {
    static let toggleRecentDocuments = Notification.Name("toggleRecentDocuments")
}
