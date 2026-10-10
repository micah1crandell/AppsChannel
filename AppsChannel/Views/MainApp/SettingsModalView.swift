import SwiftUI
import AppKit

struct SettingsModalView: View {
    @Binding var isPresented: Bool
    @State private var selectedTab: SettingsTab = .general
    @StateObject private var launchAtLoginManager = LaunchAtLoginManager.shared
    @AppStorage("defaultMode") private var defaultMode: String = LauncherMode.quickLauncher.rawValue
    @AppStorage("mainLayoutMode") private var layoutModeRaw: String = MainLayoutViewMode.gridWall.rawValue
    @AppStorage("appDisplayStyle") private var appDisplayStyleRaw: String = AppDisplayStyle.iconOnly.rawValue
    @AppStorage("threeDSGridRows") private var threeDSGridRows: Int = 3
    @AppStorage("soundEffects") private var soundEffects: Bool = true
    @AppStorage("soundTheme") private var soundThemeRaw: String = SoundTheme.subtle.rawValue
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true
    @AppStorage("dimmingIntensity") private var dimmingIntensity: Double = 0.15

    @StateObject private var hotKeyManager = HotKeyManager.shared
    @State private var isRecordingShortcut: Bool = false
    @State private var recordKeyMonitor: Any? = nil

    @ObservedObject private var discoveryService = AppDiscoveryService.shared
    @State private var hiddenAppsSearchText: String = ""
    @State private var hiddenAppsCategoryFilter: String = "ALL"

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case shortcuts = "Shortcuts"
        case appearance = "Appearance"
        case hiddenApps = "Hidden Apps"
        case about = "About"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .general: return "gearshape.fill"
            case .shortcuts: return "keyboard.fill"
            case .appearance: return "paintpalette.fill"
            case .hiddenApps: return "eye.slash.fill"
            case .about: return "info.circle.fill"
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
                .contentShape(Circle())
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
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? Color.white : Color.white.opacity(0.001))
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
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    Spacer()

                    // Support / Buy Me a Coffee Button (Bottom Left)
                    Button(action: {
                        if let url = URL(string: "https://www.buymeacoffee.com/micahcrandell") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 7) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.2))

                            Text("Buy Me a Coffee")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.92))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 1.0, green: 0.82, blue: 0.2).opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    Color(red: 1.0, green: 0.82, blue: 0.2).opacity(0.35),
                                    lineWidth: 1
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .help("Support development on Buy Me a Coffee")
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
                        case .hiddenApps:
                            hiddenAppsSettings
                        case .about:
                            aboutSettings
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    Toggle(isOn: Binding(
                        get: { launchAtLoginManager.isEnabled },
                        set: { launchAtLoginManager.setEnabled($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Launch at Login (Background Daemon)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Text("Runs silently in the menu bar at macOS login so your shortcut always responds, even before opening any window.")
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

                    if soundEffects {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sound Theme")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white)
                                Text("Choose between classic retro and modern tactile chime themes.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Spacer()
                            Picker("", selection: $soundThemeRaw) {
                                ForEach(SoundTheme.allCases) { theme in
                                    Text(theme.rawValue).tag(theme.rawValue)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(.white)
                            .frame(width: 150)
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    Toggle(isOn: $hapticFeedback) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trackpad Force Touch Haptics")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Text("Trigger subtle mechanical alignment pulses on Force Touch trackpads during navigation.")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(.white)

                    Divider().background(Color.white.opacity(0.08))

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Welcome Walkthrough")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)
                            Text("Replay the interactive first-time walkthrough animation and shortcuts tour.")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isPresented = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    MainAppState.shared.isShowingWalkthrough = true
                                }
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Replay Walkthrough")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Capsule())
                    }
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
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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
                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                                    .foregroundStyle(isRecordingShortcut ? .red : .black)
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
                        .contentShape(Capsule())
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
                                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Method A: macOS Shortcuts App (Works Even When Quit)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Uses macOS system daemon to trigger Quick Launcher from a complete cold start.")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
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
                            .contentShape(RoundedRectangle(cornerRadius: 6))
                        }

                        walkthroughStep(number: "1", title: "Open Shortcuts", desc: "Launch the native macOS Shortcuts app.")
                        walkthroughStep(number: "2", title: "Add Action", desc: "Click '+' and search for 'Open URL' (or 'Open App').")
                        walkthroughStep(number: "3", title: "Set Target", desc: "Enter 'appschannel://quick' (or select 'AppsChannel').")
                        walkthroughStep(number: "4", title: "Assign Hotkey", desc: "In Shortcut Details (ℹ︎), check 'Use as Quick Action' > 'Add Keyboard Shortcut'.")
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
                            .contentShape(RoundedRectangle(cornerRadius: 6))
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
            // Card 1: App Tile Presentation Style
            settingsCard(title: "App Presentation Style", icon: "app.badge.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Choose how apps are presented across all launcher layouts.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))

                    VStack(spacing: 8) {
                        appStyleOptionButton(
                            title: "App Icon Only (Minimalist)",
                            desc: "Pure macOS app icons floating with clean titles, ambient accent glows, and specular reflections",
                            icon: "app.fill",
                            style: .iconOnly
                        )

                        appStyleOptionButton(
                            title: "Channel Cards",
                            desc: "Classic Nintendo Wii / macOS channel cards with category tags, badges, and textured framing",
                            icon: "rectangle.portrait.on.rectangle.portrait.fill",
                            style: .channelCard
                        )
                    }
                }
            }

            // Card 2: Layout Presentation Mode
            settingsCard(title: "Default Layout Mode", icon: "square.grid.2x2.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Select your primary launcher interface. You can also cycle between them anytime using ⌘V.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))

                    VStack(spacing: 8) {
                        layoutOptionButton(
                            title: "3DS Flat Grid",
                            desc: "Nintendo 3DS Home Menu flat horizontal pagination grid with turquoise reticle cursor and speech bubble",
                            icon: "square.grid.3x2.fill",
                            mode: .threeDSGrid
                        )

                        layoutOptionButton(
                            title: "Cover Flow Carousel",
                            desc: "Smooth 3D reflective Cover Flow carousel with perspective depth and fluid navigation",
                            icon: "rectangle.portrait.on.rectangle.portrait.fill",
                            mode: .coverFlow
                        )

                        layoutOptionButton(
                            title: "Curved Cylindrical Wall Grid",
                            desc: "Interactive 3-row channel wall grid with cylindrical perspective distortion",
                            icon: "circle.grid.3x3.fill",
                            mode: .gridWall
                        )
                    }
                }
            }

            // Card 3: 3DS Grid Rows
            settingsCard(title: "3DS Grid Rows", icon: "square.split.bottomrightquarter") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Configure how many horizontal rows are displayed when in 3DS Flat Grid mode (1 to 5 rows).")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))

                    HStack(spacing: 8) {
                        ForEach(1...5, id: \.self) { count in
                            let isSelected = threeDSGridRows == count
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    threeDSGridRows = count
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text("\(count) \(count == 1 ? "Row" : "Rows")")
                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                }
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.white : Color(white: 0.08).opacity(0.85), in: Capsule())
                                .foregroundStyle(isSelected ? Color.black : Color.white)
                                .overlay(
                                    Capsule().strokeBorder(isSelected ? Color.white : Color.white.opacity(0.18), lineWidth: 1)
                                )
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .contentShape(Capsule())
                        }
                    }
                }
            }

            // Card 4: Visual & Desktop Glass Shaders
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

    private func appStyleOptionButton(title: String, desc: String, icon: String, style: AppDisplayStyle) -> some View {
        let current = AppDisplayStyle(rawValue: appDisplayStyleRaw) ?? .iconOnly
        let isSelected = current == style
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                appDisplayStyleRaw = style.rawValue
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.85))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? Color.black : Color.white)
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? Color.black.opacity(0.7) : Color.white.opacity(0.55))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.black)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.14), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func layoutOptionButton(title: String, desc: String, icon: String, mode: MainLayoutViewMode) -> some View {
        let isSelected = (MainLayoutViewMode(rawValue: layoutModeRaw) ?? .coverFlow) == mode
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                layoutModeRaw = mode.rawValue
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.85))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? Color.black : Color.white)
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundStyle(isSelected ? Color.black.opacity(0.7) : Color.white.opacity(0.55))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.black)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.14), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Hidden Apps Tab (App Visibility Manager)
    private var allCategories: [String] {
        var set = Set<String>()
        for app in discoveryService.allDiscoveredApps {
            set.insert(app.category)
        }
        var list = Array(set).sorted()
        list.insert("ALL", at: 0)
        return list
    }

    private var filteredManagerApps: [DiscoveredApp] {
        let base = discoveryService.allDiscoveredApps.filter { app in
            hiddenAppsCategoryFilter == "ALL" || app.category == hiddenAppsCategoryFilter
        }
        let query = hiddenAppsSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            return base
        }
        return base.filter { app in
            app.name.localizedCaseInsensitiveContains(query) ||
            app.category.localizedCaseInsensitiveContains(query) ||
            app.url.path.localizedCaseInsensitiveContains(query)
        }
    }

    private var categoryHiddenCount: Int {
        filteredManagerApps.filter { discoveryService.isHidden(app: $0) }.count
    }

    private var categoryVisibleCount: Int {
        filteredManagerApps.filter { !discoveryService.isHidden(app: $0) }.count
    }

    private var hiddenAppsSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard(title: "Application Visibility & Groups", icon: "eye.slash.fill") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Manage which applications appear in your launchers. Toggle visibility individually or quickly hide and unhide entire groups.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))

                    hiddenAppsSearchBar

                    categoryFilterBar

                    batchActionBar

                    hiddenAppsListSection

                    if !discoveryService.hiddenAppPaths.isEmpty {
                        Divider().background(Color.white.opacity(0.08))

                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                discoveryService.unhideAllApps()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Unhide All Applications (\(discoveryService.hiddenAppPaths.count) hidden)")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
    }

    private var hiddenAppsSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))

            TextField("Filter apps by name or category...", text: $hiddenAppsSearchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)

            if !hiddenAppsSearchText.isEmpty {
                Button(action: { hiddenAppsSearchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(allCategories, id: \.self) { cat in
                    let isSelected = hiddenAppsCategoryFilter == cat
                    let appsInCat = discoveryService.allDiscoveredApps.filter { cat == "ALL" || $0.category == cat }
                    let hiddenInCat = appsInCat.filter { discoveryService.isHidden(app: $0) }.count

                    Button(action: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                            hiddenAppsCategoryFilter = cat
                        }
                    }) {
                        HStack(spacing: 5) {
                            Text(cat)
                                .font(.system(size: 10, weight: isSelected ? .bold : .medium))

                            if hiddenInCat > 0 {
                                Text("\(hiddenInCat) hidden")
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(isSelected ? Color.black.opacity(0.2) : Color.red.opacity(0.25), in: Capsule())
                                    .foregroundStyle(isSelected ? Color.black : Color.red.opacity(0.9))
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            isSelected ?
                                Color.white : Color.white.opacity(0.06),
                            in: Capsule()
                        )
                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.85))
                        .overlay(
                            Capsule().strokeBorder(isSelected ? Color.white : Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var batchActionBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(categoryVisibleCount) Visible")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green.opacity(0.9))

                    Text("•")
                        .foregroundStyle(.white.opacity(0.4))

                    Text("\(categoryHiddenCount) Hidden")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(categoryHiddenCount > 0 ? .orange : .white.opacity(0.5))
                }
                Text("Filtering by: \(hiddenAppsCategoryFilter)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            // Batch Hide All in Group
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    discoveryService.hideGroup(category: hiddenAppsCategoryFilter)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 9.5, weight: .bold))
                    Text(hiddenAppsCategoryFilter == "ALL" ? "Hide All" : "Hide Group")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .foregroundStyle(categoryVisibleCount > 0 ? Color.white : Color.white.opacity(0.35))
                .contentShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .disabled(categoryVisibleCount == 0)

            // Batch Unhide All in Group
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    discoveryService.unhideGroup(category: hiddenAppsCategoryFilter)
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                        .font(.system(size: 9.5, weight: .bold))
                    Text(hiddenAppsCategoryFilter == "ALL" ? "Unhide All" : "Unhide Group")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                .foregroundStyle(categoryHiddenCount > 0 ? Color.white : Color.white.opacity(0.35))
                .contentShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .disabled(categoryHiddenCount == 0)
        }
        .padding(10)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var hiddenAppsListSection: some View {
        Group {
            if filteredManagerApps.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("No applications match your filter.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVStack(spacing: 6) {
                    ForEach(filteredManagerApps) { app in
                        appManagerRow(app: app)
                    }
                }
            }
        }
    }

    private func appManagerRow(app: DiscoveredApp) -> some View {
        let isHidden = discoveryService.isHidden(app: app)
        return HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .opacity(isHidden ? 0.45 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isHidden ? .white.opacity(0.5) : .white)

                    Text(app.category.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(isHidden ? .white.opacity(0.3) : .white.opacity(0.65))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 3))
                }

                Text(app.url.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                    discoveryService.toggleHidden(app: app)
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 10, weight: .bold))

                    Text(isHidden ? "Hidden" : "Visible")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundStyle(isHidden ? Color.orange : Color.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(
                    isHidden ?
                        Color.orange.opacity(0.18) : Color.white.opacity(0.12),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(
                        isHidden ? Color.orange.opacity(0.4) : Color.white.opacity(0.22),
                        lineWidth: 1
                    )
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHidden ? Color.white.opacity(0.02) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.white.opacity(isHidden ? 0.04 : 0.08), lineWidth: 1)
        )
    }

    // MARK: - About Settings Tab
    private var aboutSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            settingsCard(title: "About AppsChannel", icon: "info.circle.fill") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 54, height: 54)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text("AppsChannel")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                Text("v1.0.0")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white, in: Capsule())
                            }

                            Text("Cover Flow meets the Nintendo Channel Grid for macOS")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))

                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    isPresented = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        MainAppState.shared.isShowingWalkthrough = true
                                    }
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("Replay Walkthrough")
                                        .font(.system(size: 10.5, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.12), in: Capsule())
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .contentShape(Capsule())
                            .padding(.top, 2)
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Open Source & Community")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.white)

                        Text("Crafted natively in Swift & SwiftUI. Hardware-accelerated 3D transforms with zero telemetry, zero analytics tracking, and offline disk caching.")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            Button(action: {
                                if let url = URL(string: "https://github.com/micah1crandell/AppsChannel") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "link")
                                        .font(.system(size: 11))
                                    Text("GitHub Repository")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.12), in: Capsule())
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .contentShape(Capsule())

                            Button(action: {
                                if let url = URL(string: "https://github.com/micah1crandell/AppsChannel/releases") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11))
                                    Text("Release Notes")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.12), in: Capsule())
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .contentShape(Capsule())

                            Button(action: {
                                if let url = URL(string: "https://www.buymeacoffee.com/micahcrandell") {
                                    NSWorkspace.shared.open(url)
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.2))
                                    Text("Buy Me a Coffee")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(red: 1.0, green: 0.82, blue: 0.2).opacity(0.15), in: Capsule())
                                .overlay(
                                    Capsule().strokeBorder(Color(red: 1.0, green: 0.82, blue: 0.2).opacity(0.35), lineWidth: 1)
                                )
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .contentShape(Capsule())
                        }
                        .padding(.top, 4)
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Software Updates Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Software Updates")
                            .font(.subheadline)
                            .bold()
                            .foregroundStyle(.white)

                        Text("AppsChannel automatically checks for updates via GitHub Releases.")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))

                        Button(action: {
                            UpdateManager.shared.checkForUpdates()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Check for Updates...")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.white, in: Capsule())
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .contentShape(Capsule())
                        .padding(.top, 2)
                    }

                    Divider().background(Color.white.opacity(0.08))

                    HStack {
                        Text("Licensed under the MIT License")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer()
                        Text("macOS 14.0+")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }
    }
}
