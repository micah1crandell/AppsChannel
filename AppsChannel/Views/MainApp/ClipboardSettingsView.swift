import SwiftUI
import AppKit

public struct ClipboardSettingsView: View {
    @ObservedObject private var monitor = ClipboardMonitorService.shared
    @ObservedObject private var hotKeyManager = HotKeyManager.shared
    private let storage = ClipboardStorageService.shared

    @State private var isRecordingClipboardShortcut: Bool = false
    @State private var recordKeyMonitor: Any? = nil
    @State private var showClearConfirmation: Bool = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            settingsSectionHeader(
                icon: "doc.on.clipboard.fill",
                title: "Clipboard History",
                accentColor: Color(red: 0.1, green: 0.75, blue: 0.5)
            ) {
                HStack(spacing: 6) {
                    pillBadge(
                        text: monitor.isPaused ? "Paused" : "Recording",
                        color: monitor.isPaused ? .orange : Color(red: 0.1, green: 0.75, blue: 0.5),
                        bgOpacity: 0.15
                    )
                    pillBadge(text: "\(monitor.items.count) Clippings")
                }
            }

            // Group 1: General & Shortcut
            settingsGroupBox {
                settingsRow(
                    icon: "record.circle",
                    iconColor: monitor.isPaused ? .orange : Color(red: 0.1, green: 0.75, blue: 0.5),
                    title: "Clipboard Monitoring",
                    subtitle: monitor.isPaused ? "Monitoring is paused. New copies are ignored." : "Automatically records copied text, URLs, code, colors, and images."
                ) {
                    Toggle("", isOn: Binding(
                        get: { !monitor.isPaused },
                        set: { monitor.isPaused = !$0 }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                settingsDivider

                settingsRow(
                    icon: "keyboard.fill",
                    iconColor: Color(red: 0.58, green: 0.35, blue: 0.95),
                    title: "Global Shortcut",
                    subtitle: "Trigger the clipboard history manager from any application"
                ) {
                    HStack(spacing: 8) {
                        Button(action: {
                            if isRecordingClipboardShortcut {
                                stopRecording()
                            } else {
                                startRecording()
                            }
                        }) {
                            HStack(spacing: 5) {
                                if isRecordingClipboardShortcut {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 6, height: 6)
                                    Text("Press shortcut...")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                } else {
                                    Text(hotKeyManager.currentClipboardShortcutLabel)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4.5)
                            .background(
                                isRecordingClipboardShortcut ? Color.red.opacity(0.2) : Color.white.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(
                                        isRecordingClipboardShortcut ? Color.red : Color.white.opacity(0.18),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            PanelController.shared.showClipboardHistory()
                        }) {
                            Text("Open Now")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4.5)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Group 2: Privacy & Concealed Data
            settingsGroupBox {
                settingsRow(
                    icon: "lock.shield.fill",
                    iconColor: Color(red: 1.0, green: 0.65, blue: 0.1),
                    title: "Exclude Sensitive Data & Passwords",
                    subtitle: "Skip copies flagged by 1Password, Bitwarden, Keychain, and password managers"
                ) {
                    Toggle("", isOn: $monitor.excludeSensitive)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                settingsDivider

                settingsRow(
                    icon: "eye.slash.fill",
                    iconColor: Color(red: 1.0, green: 0.85, blue: 0.2),
                    title: "Mask Secret Previews",
                    subtitle: "Concealed clippings render as •••••••• until explicitly revealed in the inspector"
                ) {
                    pillBadge(text: "Protected by Default", color: .yellow, bgOpacity: 0.15)
                }
            }

            // Group 3: Retention & Storage Limits
            settingsGroupBox {
                settingsRow(
                    icon: "clock.arrow.circlepath",
                    iconColor: Color(red: 0.15, green: 0.55, blue: 1.0),
                    title: "History Retention",
                    subtitle: "Older unpinned clippings are automatically expired and pruned"
                ) {
                    Picker("", selection: $monitor.retentionDuration) {
                        ForEach(ClipboardRetentionDuration.allCases) { duration in
                            Text(duration.rawValue).tag(duration)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                settingsDivider

                settingsRow(
                    icon: "tray.full.fill",
                    iconColor: Color(red: 0.2, green: 0.8, blue: 0.7),
                    title: "Maximum History Items",
                    subtitle: "Limits total unpinned history count to preserve memory and disk space"
                ) {
                    Picker("", selection: $monitor.maxItemsCount) {
                        Text("100 items").tag(100)
                        Text("250 items").tag(250)
                        Text("500 items").tag(500)
                        Text("1000 items").tag(1000)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                settingsDivider

                settingsRow(
                    icon: "internaldrive.fill",
                    iconColor: Color(white: 0.5),
                    title: "Storage Space Used",
                    subtitle: "\(formatBytes(storage.calculateDiskUsage())) on disk (including image clippings)"
                ) {
                    Button(action: {
                        showClearConfirmation = true
                    }) {
                        Text("Clear History")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog(
                        "Are you sure you want to clear clipboard history?",
                        isPresented: $showClearConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Clear Unpinned Clippings", role: .destructive) {
                            monitor.clearAllHistory(preservePinned: true)
                        }
                        Button("Clear Everything (Including Pinned)", role: .destructive) {
                            monitor.clearAllHistory(preservePinned: false)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Pinned items will be preserved unless you choose to clear everything.")
                    }
                }
            }

            // Footer
            settingsFooter(
                text: "100% on-device • Zero telemetry • Private local storage",
                actionTitle: "Clear Unpinned History",
                accentColor: .orange
            ) {
                monitor.clearAllHistory(preservePinned: true)
            }
        }
    }

    // MARK: - HotKey Recording
    private func startRecording() {
        isRecordingClipboardShortcut = true
        recordKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !flags.isEmpty else { return nil }

            let keyCode = UInt32(event.keyCode)
            let label = formatKeyLabel(keyCode: keyCode, modifiers: flags)

            hotKeyManager.applyClipboardCustom(keyCode: keyCode, modifiers: flags, label: label)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecordingClipboardShortcut = false
        if let mon = recordKeyMonitor {
            NSEvent.removeMonitor(mon)
            recordKeyMonitor = nil
        }
    }

    private func formatKeyLabel(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }

        let char: String
        switch keyCode {
        case 8: char = "C"
        case 9: char = "V"
        case 35: char = "P"
        case 37: char = "L"
        case 40: char = "K"
        case 49: char = "Space"
        default:
            char = "Key"
        }
        parts.append(char)
        return parts.joined(separator: " + ")
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Shared UI Helpers
    private func settingsSectionHeader<RightView: View>(
        icon: String,
        title: String,
        accentColor: Color,
        @ViewBuilder rightView: () -> RightView
    ) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 22, height: 22)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accentColor)
            }

            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Spacer()

            rightView()
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    private func settingsGroupBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func settingsRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(iconColor)
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var settingsDivider: some View {
        Divider()
            .background(Color.white.opacity(0.05))
    }

    private func settingsFooter(
        text: String,
        actionTitle: String? = nil,
        accentColor: Color = Color(red: 0.05, green: 0.52, blue: 1.0),
        action: (() -> Void)? = nil
    ) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(accentColor)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private func pillBadge(text: String, color: Color = .white, bgOpacity: Double = 0.08) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(bgOpacity))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}
