import SwiftUI
import AppKit

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
                HStack(spacing: 9) {
                    Image(systemName: "square.grid.3x3.topleft.filled")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Preferences")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                Button(action: {
                    stopRecordingShortcut()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 28, height: 28)
                        .background(Color(white: 0.08).opacity(0.85), in: Circle())
                        .contentShape(Circle())
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Close (⎋)")
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()
                .background(Color.white.opacity(0.08))

            // Sidebar Tabs & Content
            HStack(spacing: 0) {
                // Sidebar Navigation
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(SettingsTab.allCases) { tab in
                        let isSelected = selectedTab == tab
                        Button(action: {
                            stopRecordingShortcut()
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .frame(width: 18)
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            }
                            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.75))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Group {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.white)
                                    } else {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.clear)
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? Color.white : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .frame(width: 160)
                .padding(14)
                .background(Color.black.opacity(0.25))

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)

                // Tab Content Pane
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
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
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
        }
        .frame(width: 710, height: 510)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(
            ZStack {
                VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.92)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.07),
                        Color.clear,
                        Color.black.opacity(0.4)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.7), radius: 36, x: 0, y: 18)
        .onDisappear {
            stopRecordingShortcut()
        }
    }

    // MARK: - Reusable Obsidian Glass Card Container
    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.07).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - General Settings Tab
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card 1: App Behavior
            settingsCard(title: "Application Behavior", icon: "macwindow") {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(isOn: $launchAtLogin) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Text("Automatically start AppsChannel in the background when logging into macOS.")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.white)

                    Divider().background(Color.white.opacity(0.08))

                    Toggle(isOn: $soundEffects) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Navigation Sound Effects")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Text("Play subtle audio feedback when navigating cards and launching channels.")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.white)
                }
            }

            // Card 2: Default Launcher Mode
            settingsCard(title: "Default Launcher Mode", icon: "slider.horizontal.2.square") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose the mode activated by the global shortcut.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))

                    HStack(spacing: 10) {
                        modeButton(
                            title: "Quick Launcher",
                            desc: "Floating Spotlight-style bar with rapid search",
                            mode: .quickLauncher
                        )
                        modeButton(
                            title: "Full Channel",
                            desc: "Full-screen CoverFlow & Curved Wall Grid",
                            mode: .fullScreen
                        )
                    }
                }
            }

            // Card 3: Smart Usage & Ranking
            settingsCard(title: "Smart Ranking & Search Memory", icon: "chart.line.uptrend.xyaxis") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Apps are arranged with your most opened apps in the center (1 middle, 2 right, 3 left, 4 right...). When searching, previous launch choices are learned and prioritized.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button(action: {
                            AppUsageTracker.shared.resetAnalytics()
                            AppDiscoveryService.shared.resetToUsageOrder()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                Text("Reset Usage & Search History")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            AppDiscoveryService.shared.resetToUsageOrder()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 11))
                                Text("Reapply Usage Order")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func modeButton(title: String, desc: String, mode: LauncherMode) -> some View {
        let isSelected = defaultMode == mode.rawValue
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                defaultMode = mode.rawValue
            }
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? Color.black : Color.white)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.black)
                    }
                }
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.7) : Color.white.opacity(0.55))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.14), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shortcut Settings Tab
    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card 1: Global Shortcut
            settingsCard(title: "Global Activation Shortcut", icon: "keyboard.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Press this keyboard combination anywhere in macOS to trigger AppsChannel.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))

                    // Current Shortcut Glass Banner
                    HStack(spacing: 14) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 18))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current Shortcut")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.6))
                            Text(isRecordingShortcut ? "Press key combo now..." : hotKeyManager.currentShortcutLabel)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(isRecordingShortcut ? .yellow : .white)
                        }

                        Spacer()

                        Button(action: toggleRecordingShortcut) {
                            HStack(spacing: 6) {
                                Image(systemName: isRecordingShortcut ? "record.circle.fill" : "record.circle")
                                    .foregroundStyle(isRecordingShortcut ? .red : (isRecordingShortcut ? .black : .black))
                                Text(isRecordingShortcut ? "Cancel" : "Record Shortcut")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isRecordingShortcut ? Color.white.opacity(0.9) : Color.white, in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )

                    // Presets
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Presets:")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
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
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        isSelected ?
                                            Color.white : Color(white: 0.08).opacity(0.85),
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.18), lineWidth: 1)
                                    )
                                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Card 2: macOS System Integration
            settingsCard(title: "System Integration", icon: "applelogo") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("To bind system-wide shortcuts directly through macOS native preferences:")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))

                    // Method A
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Method A: macOS Shortcuts App (Recommended)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Button(action: {
                                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                            }) {
                                Text("Open Shortcuts")
                                    .foregroundStyle(.black)
                                    .font(.system(size: 11, weight: .semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                                    .contentShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }

                        walkthroughStep(number: "1", title: "Open Shortcuts", desc: "Launch the native macOS Shortcuts app.")
                        walkthroughStep(number: "2", title: "Add Action", desc: "Click '+' and search for 'Open App'.")
                        walkthroughStep(number: "3", title: "Choose AppsChannel", desc: "Select 'AppsChannel' as the target application.")
                        walkthroughStep(number: "4", title: "Assign Hotkey", desc: "In Details panel, check 'Use as Quick Action' > 'Add Keyboard Shortcut'.")
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )

                    // Method B
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Method B: System Settings > Keyboard Shortcuts")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Button(action: {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                Text("Open Settings")
                                    .foregroundStyle(.white.opacity(0.85))
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                                    .contentShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                        }

                        walkthroughStep(number: "1", title: "Keyboard Shortcuts", desc: "Open System Settings > Keyboard > Keyboard Shortcuts...")
                        walkthroughStep(number: "2", title: "App Shortcuts", desc: "Select 'App Shortcuts' in the left sidebar.")
                        walkthroughStep(number: "3", title: "Add Shortcut", desc: "Click '+' > choose AppsChannel > assign shortcut.")
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
    }

    private func walkthroughStep(number: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.white))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.65))
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

    // MARK: - Appearance Settings Tab
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "Visual & Desktop Glass Shaders", icon: "paintpalette.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Desktop Dimming Level")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.85))
                            Spacer()
                            Text("\(Int(dimmingIntensity * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12), in: Capsule())
                        }

                        Slider(value: $dimmingIntensity, in: 0.05...0.45)
                            .tint(.white)
                    }

                    Divider().background(Color.white.opacity(0.08))

                    HStack(spacing: 8) {
                        Circle().fill(Color.white).frame(width: 6, height: 6)
                        Text("Apple Liquid Glass shaders & behind-window desktop blur active")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
            }
        }
    }

    // MARK: - Account Settings Tab
    private var accountSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "Local Profile & License", icon: "person.crop.circle.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.9))

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(NSFullUserName())
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Text("PRO")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white, in: Capsule())
                            }

                            Text("macOS Local Profile")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AppsChannel Pro Edition")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.white)

                        Text("Licensed to local macOS workspace. Custom Wii & 3DS channel layout active.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
            }
        }
    }
}
