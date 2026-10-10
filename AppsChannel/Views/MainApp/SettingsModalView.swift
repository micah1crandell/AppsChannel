import SwiftUI

struct SettingsModalView: View {
    @Binding var isPresented: Bool
    @State private var selectedTab: SettingsTab = .general
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("defaultMode") private var defaultMode: String = LauncherMode.quickLauncher.rawValue
    @AppStorage("soundEffects") private var soundEffects: Bool = true
    @AppStorage("dimmingIntensity") private var dimmingIntensity: Double = 0.15

    @StateObject private var hotKeyManager = HotKeyManager.shared
    @State private var isRecordingShortcut: Bool = false
    @State private var recordKeyMonitor: Any? = nil
    @AppStorage("showInDock") private var showInDock: Bool = true

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case shortcuts = "Shortcuts"
        case appearance = "Appearance"
        case account = "Account"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .general: return "gearshape.fill"
            case .shortcuts: return "keyboard.fill"
            case .appearance: return "paintpalette.fill"
            case .account: return "person.crop.circle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Modal Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3.topleft.filled")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text("AppsChannel Preferences")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Spacer()

                Button(action: {
                    stopRecordingShortcut()
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()
                .background(Color.white.opacity(0.12))

            // Sidebar Tabs & Content
            HStack(spacing: 0) {
                // Tab Selection
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(SettingsTab.allCases) { tab in
                        Button(action: {
                            stopRecordingShortcut()
                            selectedTab = tab
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 13))
                                    .frame(width: 18)
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: selectedTab == tab ? .bold : .medium))
                            }
                            .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                selectedTab == tab ?
                                    Color.cyan.opacity(0.2) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .frame(width: 150)
                .padding(16)
                .background(Color.black.opacity(0.2))

                Divider()
                    .background(Color.white.opacity(0.12))

                // Tab Content Pane (Scrollable with isolated scroll events)
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case .general:
                            generalSettings
                        case .shortcuts:
                            shortcutSettings
                        case .appearance:
                            appearanceSettings
                        case .account:
                            accountSettings
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 680, height: 490)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(white: 0.12).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
        .onDisappear {
            stopRecordingShortcut()
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Show AppsChannel in macOS Dock", isOn: $showInDock)
                .toggleStyle(.checkbox)
                .foregroundStyle(.white)
                .onChange(of: showInDock) { newValue in
                    PanelController.shared.setDockVisibility(showInDock: newValue)
                }

            Toggle("Launch AppsChannel at Login", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .foregroundStyle(.white)

            Toggle("Enable Sound Effects on Navigation", isOn: $soundEffects)
                .toggleStyle(.checkbox)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 8) {
                Text("Default Launcher Mode:")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))

                Picker("", selection: $defaultMode) {
                    Text("Spotlight-style Quick Launcher").tag(LauncherMode.quickLauncher.rawValue)
                    Text("Full-Screen Main Channel").tag(LauncherMode.fullScreen.rawValue)
                }
                .pickerStyle(.radioGroup)
                .foregroundStyle(.white)
            }

            Divider()
                .background(Color.white.opacity(0.12))

            // Smart Usage & Search Memory
            VStack(alignment: .leading, spacing: 8) {
                Text("Smart Usage & Search Ranking")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)

                Text("Apps are arranged with your most opened apps in the center (1 in middle, 2 right, 3 left, 4 right...). When searching, previous choices are learned and prioritized.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button(action: {
                        AppUsageTracker.shared.resetAnalytics()
                        AppDiscoveryService.shared.resetToUsageOrder()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                            Text("Reset Usage & Search History")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.red.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.red.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        AppDiscoveryService.shared.resetToUsageOrder()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11))
                            Text("Reapply Usage Order")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
        }
    }

    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
                // Section 1: In-App Shortcut Customization
                VStack(alignment: .leading, spacing: 10) {
                    Text("Global Activation Shortcut")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("Press this keyboard combination from any macOS app to open AppsChannel.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    // Current Shortcut Glass Banner
                    HStack(spacing: 14) {
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.cyan)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Shortcut")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                            Text(isRecordingShortcut ? "Press key combo now..." : hotKeyManager.currentShortcutLabel)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(isRecordingShortcut ? .yellow : .cyan)
                        }

                        Spacer()

                        Button(action: toggleRecordingShortcut) {
                            HStack(spacing: 6) {
                                Image(systemName: isRecordingShortcut ? "record.circle.fill" : "record.circle")
                                    .foregroundStyle(isRecordingShortcut ? .red : .white)
                                Text(isRecordingShortcut ? "Cancel" : "Record Shortcut")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isRecordingShortcut ? Color.red.opacity(0.2) : Color.white.opacity(0.12), in: Capsule())
                            .overlay(
                                Capsule().strokeBorder(isRecordingShortcut ? Color.red.opacity(0.5) : Color.white.opacity(0.25), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )

                    // Presets
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Presets:")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(hotKeyManager.presets) { preset in
                                let isSelected = hotKeyManager.currentShortcutLabel == preset.label
                                Button(action: {
                                    stopRecordingShortcut()
                                    hotKeyManager.applyPreset(preset)
                                }) {
                                    HStack {
                                        Text(preset.label)
                                            .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .monospaced))
                                            .foregroundStyle(isSelected ? .black : .white)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundStyle(.black)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(
                                        isSelected ?
                                            Color.cyan : Color.white.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Divider().background(Color.white.opacity(0.12))

                // Section 2: macOS System Settings Walkthrough
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "applelogo")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                        Text("macOS System Settings Walkthrough")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    Text("To bind system-wide shortcuts directly through macOS native settings:")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    // Method A: Shortcuts App (Apple's modern standard)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Method A: macOS Shortcuts App (Recommended)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.cyan)
                            Spacer()
                            Button("Open Shortcuts App") {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(.cyan)
                        }

                        walkthroughStep(number: "1", title: "Open Shortcuts", desc: "Launch the native macOS Shortcuts app.")
                        walkthroughStep(number: "2", title: "Add Action", desc: "Click '+' and search for the 'Open App' action.")
                        walkthroughStep(number: "3", title: "Choose AppsChannel", desc: "Select 'AppsChannel' as the application to open.")
                        walkthroughStep(number: "4", title: "Assign Hotkey", desc: "In the right Details panel, check 'Use as Quick Action' > 'Add Keyboard Shortcut'.")
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    // Method B: System Settings > Keyboard
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Method B: System Settings > Keyboard Shortcuts")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Button("Open Keyboard Settings") {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        walkthroughStep(number: "1", title: "Keyboard Shortcuts", desc: "Open System Settings > Keyboard > Keyboard Shortcuts...")
                        walkthroughStep(number: "2", title: "App Shortcuts", desc: "Select 'App Shortcuts' in the left sidebar.")
                        walkthroughStep(number: "3", title: "Add Shortcut", desc: "Click '+' > choose AppsChannel > assign shortcut.")
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
            }
            .padding(.trailing, 6)
        }

    private func walkthroughStep(number: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.cyan))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func toggleRecordingShortcut() {
        if isRecordingShortcut {
            stopRecordingShortcut()
        } else {
            startRecordingShortcut()
        }
    }

    private func startRecordingShortcut() {
        isRecordingShortcut = true
        recordKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !flags.isEmpty else { return event }

            var parts: [String] = []
            if flags.contains(.control) { parts.append("⌃") }
            if flags.contains(.option) { parts.append("⌥") }
            if flags.contains(.shift) { parts.append("⇧") }
            if flags.contains(.command) { parts.append("⌘") }

            let char = event.charactersIgnoringModifiers?.uppercased() ?? "KEY"
            parts.append(char)
            let label = parts.joined(separator: " + ")

            hotKeyManager.applyCustom(keyCode: UInt32(event.keyCode), modifiers: flags, label: label)
            stopRecordingShortcut()
            return nil
        }
    }

    private func stopRecordingShortcut() {
        isRecordingShortcut = false
        if let monitor = recordKeyMonitor {
            NSEvent.removeMonitor(monitor)
            recordKeyMonitor = nil
        }
    }

    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Desktop Dimming Level")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                Slider(value: $dimmingIntensity, in: 0.05...0.45)
                    .tint(.cyan)
            }

            HStack(spacing: 8) {
                Circle().fill(Color.cyan).frame(width: 8, height: 8)
                Text("Apple Liquid Glass shaders & behind-window blur active")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private var accountSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(NSFullUserName())
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("macOS Local Profile")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            Divider().background(Color.white.opacity(0.12))

            Text("AppsChannel Pro Edition")
                .font(.subheadline)
                .bold()
                .foregroundStyle(.white)

            Text("Licensed to local macOS workspace. Custom Wii/3DS channel layout active.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
