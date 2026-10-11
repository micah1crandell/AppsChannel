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
    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = true
    @AppStorage("showInDock") private var showInDock: Bool = false
    @AppStorage("enableSystemActions") private var enableSystemActions: Bool = true
    @AppStorage("confirmDestructiveActions") private var confirmDestructiveActions: Bool = true

    @StateObject private var hotKeyManager = HotKeyManager.shared
    @State private var isRecordingShortcut: Bool = false
    @State private var recordKeyMonitor: Any? = nil

    @ObservedObject private var discoveryService = AppDiscoveryService.shared
    @ObservedObject private var shortcutManager = ShortcutMappingManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var customChannelManager = CustomChannelManager.shared
    @ObservedObject private var cliManager = CLICompanionManager.shared
    @State private var isShowingAddChannelSheet: Bool = false

    @State private var hiddenAppsSearchText: String = ""
    @State private var hiddenAppsCategoryFilter: String = "ALL"
    @State private var copiedCommandText: String? = nil

    private var availableCategories: [String] {
        var set = Set<String>()
        for app in discoveryService.allDiscoveredApps {
            set.insert(app.category)
        }
        var list = Array(set).sorted()
        list.insert("ALL", at: 0)
        return list
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case appearance = "Appearance"
        case shortcuts = "Shortcuts"
        case windowManagement = "Window Management"
        case clipboard = "Clipboard"
        case channels = "Channels"
        case hiddenApps = "Hidden Apps"
        case about = "About"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .general: return "gearshape.fill"
            case .appearance: return "paintpalette.fill"
            case .shortcuts: return "keyboard.fill"
            case .windowManagement: return "macwindow.on.rectangle"
            case .clipboard: return "doc.on.clipboard.fill"
            case .channels: return "plus.rectangle.on.rectangle.fill"
            case .hiddenApps: return "eye.slash.fill"
            case .about: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Modal Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.3x3.topleft.filled")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Preferences")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("•")
                        .foregroundStyle(.white.opacity(0.3))

                    Text(selectedTab.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
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
                        .frame(width: 26, height: 26)
                        .background(Color(white: 0.1).opacity(0.8), in: Circle())
                        .contentShape(Circle())
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .help("Close (⎋)")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.08))

            // Sidebar & Content Pane
            HStack(spacing: 0) {
                // Sidebar
                VStack(alignment: .leading, spacing: 4) {
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

                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.75))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? Color.white : Color.white.opacity(0.001))
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Buy Me a Coffee Quick Link
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
                                .foregroundStyle(Color.white.opacity(0.9))

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color(red: 1.0, green: 0.82, blue: 0.2).opacity(0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color(red: 1.0, green: 0.82, blue: 0.2).opacity(0.3), lineWidth: 1)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help("Support development")
                }
                .frame(width: 165)
                .padding(12)
                .background(Color.black.opacity(0.28))

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)

                // Tab Content Pane
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        switch selectedTab {
                        case .general:
                            generalSettings
                        case .appearance:
                            appearanceSettings
                        case .shortcuts:
                            shortcutSettings
                        case .windowManagement:
                            WindowManagementSettingsView()
                        case .clipboard:
                            ClipboardSettingsView()
                        case .channels:
                            customChannelsSettings
                        case .hiddenApps:
                            hiddenAppsSettings
                        case .about:
                            aboutSettings
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .id(selectedTab)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 760, height: 535)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(
            ZStack {
                VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.93)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.06),
                        Color.clear,
                        Color.black.opacity(0.4)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.65), radius: 32, x: 0, y: 16)
        .onDisappear {
            stopRecordingShortcut()
        }
        .sheet(isPresented: $isShowingAddChannelSheet) {
            AddCustomChannelSheet()
        }
    }

    // MARK: - Reusable Modern Preferences Components (Matching WindowManagementSettingsView)
    private func settingsSectionHeader<Trailing: View>(
        icon: String,
        title: String,
        accentColor: Color,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accentColor)

                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, 4)
    }

    private func settingsGroupBox<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 1) {
            content()
        }
        .padding(.vertical, 4)
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


    // MARK: - 1. General Settings Tab
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            settingsSectionHeader(
                icon: "gearshape.fill",
                title: "General",
                accentColor: Color(red: 0.05, green: 0.52, blue: 1.0)
            ) {
                pillBadge(
                    text: defaultMode == LauncherMode.quickLauncher.rawValue ? "Quick Launcher" : "Channel Window",
                    color: Color(red: 0.05, green: 0.52, blue: 1.0)
                )
            }

            // Default Mode Card
            settingsGroupBox {
                settingsRow(
                    icon: "slider.horizontal.2.square",
                    iconColor: Color(red: 0.05, green: 0.52, blue: 1.0),
                    title: "Default Mode",
                    subtitle: "Choose interface summoned on hotkey or app launch"
                ) {
                    EmptyView()
                }

                settingsDivider

                HStack(spacing: 10) {
                    visualModeCard(
                        mode: .quickLauncher,
                        title: "Quick Launcher",
                        badge: "Floating HUD",
                        isSelected: defaultMode == LauncherMode.quickLauncher.rawValue
                    ) { isSel in
                        HStack(spacing: 5) {
                            ForEach(0..<3) { idx in
                                miniChannelCardPreview(index: idx, isSelected: isSel)
                            }
                        }
                        .frame(height: 26)
                    }

                    visualModeCard(
                        mode: .fullScreen,
                        title: "Channel Window",
                        badge: "Full Menu",
                        isSelected: defaultMode == LauncherMode.fullScreen.rawValue
                    ) { isSel in
                        miniFullWindowPreview(isSelected: isSel)
                            .frame(height: 26)
                    }
                }
                .padding(10)
            }

            // System Integration
            settingsGroupBox {
                settingsRow(
                    icon: "power",
                    iconColor: Color(red: 0.2, green: 0.8, blue: 0.4),
                    title: "Launch at Login",
                    subtitle: "Background daemon responds to hotkey instantly"
                ) {
                    Toggle("", isOn: Binding(
                        get: { launchAtLoginManager.isEnabled },
                        set: { launchAtLoginManager.setEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color(red: 0.05, green: 0.52, blue: 1.0))
                }

                settingsDivider

                settingsRow(
                    icon: "menubar.arrow.up.rectangle",
                    iconColor: Color(red: 0.65, green: 0.35, blue: 1.0),
                    title: "Show in Menu Bar",
                    subtitle: "Cover Flow icon in macOS status bar"
                ) {
                    Toggle("", isOn: Binding(
                        get: { showInMenuBar },
                        set: { newValue in
                            if !newValue && !showInDock {
                                showInDock = true
                                PanelController.shared.setDockVisibility(showInDock: true)
                            }
                            showInMenuBar = newValue
                            MenuBarManager.shared.setVisibility(newValue)
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color(red: 0.05, green: 0.52, blue: 1.0))
                }

                settingsDivider

                settingsRow(
                    icon: "dock.rectangle",
                    iconColor: Color(red: 1.0, green: 0.55, blue: 0.0),
                    title: "Show in Dock",
                    subtitle: "Visible alongside macOS applications in Dock"
                ) {
                    Toggle("", isOn: Binding(
                        get: { showInDock },
                        set: { newValue in
                            if !newValue && !showInMenuBar {
                                showInMenuBar = true
                                MenuBarManager.shared.setVisibility(true)
                            }
                            showInDock = newValue
                            PanelController.shared.setDockVisibility(showInDock: newValue)
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color(red: 0.05, green: 0.52, blue: 1.0))
                }
            }

            // Audio & Feedback
            settingsGroupBox {
                settingsRow(
                    icon: "speaker.wave.2.fill",
                    iconColor: Color(red: 1.0, green: 0.3, blue: 0.5),
                    title: "Sound Effects",
                    subtitle: "Audio cues for navigation, selection, and launches"
                ) {
                    HStack(spacing: 8) {
                        if soundEffects {
                            Picker("", selection: $soundThemeRaw) {
                                ForEach(SoundTheme.allCases) { theme in
                                    Text(theme.rawValue).tag(theme.rawValue)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(.white)
                            .frame(width: 130)
                            .onChange(of: soundThemeRaw) { _, newTheme in
                                if let theme = SoundTheme(rawValue: newTheme) {
                                    SoundEffectsManager.shared.playPreview(for: theme)
                                }
                            }

                            Button(action: {
                                if let theme = SoundTheme(rawValue: soundThemeRaw) {
                                    SoundEffectsManager.shared.playPreview(for: theme)
                                } else {
                                    SoundEffectsManager.shared.playNavigation()
                                }
                            }) {
                                Image(systemName: "speaker.wave.2.bubble.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .help("Preview sound theme")
                        }

                        Toggle("", isOn: $soundEffects)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(Color(red: 0.05, green: 0.52, blue: 1.0))
                    }
                }

                settingsDivider

                settingsRow(
                    icon: "hand.tap.fill",
                    iconColor: Color(red: 0.1, green: 0.75, blue: 0.75),
                    title: "Trackpad Haptics",
                    subtitle: "Force Touch alignment pulses"
                ) {
                    Toggle("", isOn: $hapticFeedback)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Color(red: 0.05, green: 0.52, blue: 1.0))
                }
            }

            // Smart Ranking
            settingsGroupBox {
                settingsRow(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: Color(red: 0.35, green: 0.45, blue: 1.0),
                    title: "Smart Ranking",
                    subtitle: "Center-Out distribution places frequent apps in primary focus"
                ) {
                    EmptyView()
                }

                settingsDivider

                HStack(spacing: 14) {
                    // Mini Visual Diagram
                    HStack(spacing: 6) {
                        Text("3")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))

                        Image(systemName: "arrow.left")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.3))

                        VStack(spacing: 1) {
                            Text("1")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.black)
                            Text("TOP")
                                .font(.system(size: 7, weight: .heavy))
                                .foregroundStyle(.black.opacity(0.7))
                        }
                        .frame(width: 26, height: 26)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 6))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.3))

                        Text("2")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Center-Out Distribution")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Top apps occupy center slots for quickest thumb/eye reach")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: {
                            AppUsageTracker.shared.resetAnalytics()
                            AppDiscoveryService.shared.resetToUsageOrder()
                            SoundEffectsManager.shared.playAction()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text("Reset")
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .help("Clear launch history")

                        Button(action: {
                            AppDiscoveryService.shared.resetToUsageOrder()
                            SoundEffectsManager.shared.playAction()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reapply")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(red: 0.05, green: 0.52, blue: 1.0))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .help("Reorder cards by current launch frequency")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // Footer
            settingsFooter(
                text: "Core launcher, daemon, and feedback preferences",
                actionTitle: "Reset to Defaults"
            ) {
                defaultMode = LauncherMode.quickLauncher.rawValue
                soundEffects = true
                soundThemeRaw = SoundTheme.subtle.rawValue
                hapticFeedback = true
                SoundEffectsManager.shared.playAction()
            }
        }
    }

    private func visualModeCard<Preview: View>(
        mode: LauncherMode,
        title: String,
        badge: String,
        isSelected: Bool,
        @ViewBuilder preview: (Bool) -> Preview
    ) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                defaultMode = mode.rawValue
            }
            SoundEffectsManager.shared.playAction()
        }) {
            VStack(spacing: 8) {
                preview(isSelected)

                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? Color.black : Color.white)

                    Spacer(minLength: 0)

                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(isSelected ? Color.black.opacity(0.7) : Color.white.opacity(0.5))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.black.opacity(0.1) : Color.white.opacity(0.08), in: Capsule())
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.12), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 2. Appearance Settings Tab
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            settingsSectionHeader(
                icon: "paintpalette.fill",
                title: "Appearance",
                accentColor: Color(red: 0.65, green: 0.35, blue: 1.0)
            ) {
                pillBadge(
                    text: themeManager.currentTheme.rawValue,
                    color: Color(red: 0.65, green: 0.35, blue: 1.0)
                )
            }

            // Visual Theme Gallery
            settingsGroupBox {
                settingsRow(
                    icon: "sparkles",
                    iconColor: Color(red: 0.65, green: 0.35, blue: 1.0),
                    title: "Visual Theme",
                    subtitle: "PBR glass materials, metallic finishes, and contrast profiles"
                ) {
                    EmptyView()
                }

                settingsDivider

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(AppVisualTheme.allCases) { theme in
                        themeVisualTile(theme: theme)
                    }
                }
                .padding(10)
            }

            // App Presentation
            settingsGroupBox {
                settingsRow(
                    icon: "app.badge.fill",
                    iconColor: Color(red: 0.05, green: 0.52, blue: 1.0),
                    title: "App Presentation",
                    subtitle: "Minimalist app icon or framed 3DS channel card"
                ) {
                    EmptyView()
                }

                settingsDivider

                HStack(spacing: 10) {
                    let currentStyle = AppDisplayStyle(rawValue: appDisplayStyleRaw) ?? .iconOnly

                    // Style 1: Icon Only
                    visualChoiceButton(
                        isSelected: currentStyle == .iconOnly,
                        title: "App Icon Only",
                        badge: "Minimalist"
                    ) { isSel in
                        VStack(spacing: 4) {
                            Image(systemName: "app.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(isSel ? Color.black : Color.white)
                                .shadow(color: isSel ? Color.black.opacity(0.15) : Color.white.opacity(0.3), radius: 6)

                            RoundedRectangle(cornerRadius: 1)
                                .fill(isSel ? Color.black.opacity(0.25) : Color.white.opacity(0.2))
                                .frame(width: 18, height: 2)
                        }
                        .frame(height: 38)
                    } onSelect: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            appDisplayStyleRaw = AppDisplayStyle.iconOnly.rawValue
                        }
                        SoundEffectsManager.shared.playAction()
                    }

                    // Style 2: Channel Cards
                    visualChoiceButton(
                        isSelected: currentStyle == .channelCard,
                        title: "Channel Cards",
                        badge: "Framed Card"
                    ) { isSel in
                        VStack(spacing: 3) {
                            HStack {
                                Circle().fill(Color.cyan).frame(width: 4, height: 4)
                                Spacer()
                            }
                            .padding(.horizontal, 4)

                            Image(systemName: "app.dashed")
                                .font(.system(size: 14))
                                .foregroundStyle(isSel ? Color.black.opacity(0.85) : Color.white.opacity(0.8))

                            RoundedRectangle(cornerRadius: 1)
                                .fill(isSel ? Color.black.opacity(0.4) : Color.white.opacity(0.35))
                                .frame(width: 16, height: 2)
                        }
                        .padding(4)
                        .frame(width: 46, height: 38)
                        .background(isSel ? Color.black.opacity(0.08) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isSel ? Color.black.opacity(0.2) : Color.white.opacity(0.25), lineWidth: 1))
                    } onSelect: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            appDisplayStyleRaw = AppDisplayStyle.channelCard.rawValue
                        }
                        SoundEffectsManager.shared.playAction()
                    }
                }
                .padding(10)
            }

            // Default Layout Mode & Flat Grid Rows
            settingsGroupBox {
                settingsRow(
                    icon: "square.grid.2x2.fill",
                    iconColor: Color(red: 0.2, green: 0.8, blue: 0.4),
                    title: "Default Layout Mode",
                    subtitle: "Primary 3D presentation style (cycle anytime with ⌘V)"
                ) {
                    EmptyView()
                }

                settingsDivider

                HStack(spacing: 10) {
                    let currentMode = MainLayoutViewMode(rawValue: layoutModeRaw) ?? .coverFlow

                    // 1. Flat Grid
                    visualChoiceButton(
                        isSelected: currentMode == .flatGrid,
                        title: "Flat Grid",
                        badge: "Paged"
                    ) { isSel in
                        LazyVGrid(columns: [GridItem(.fixed(10)), GridItem(.fixed(10)), GridItem(.fixed(10))], spacing: 3) {
                            ForEach(0..<6) { _ in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(isSel ? Color.black.opacity(0.6) : Color.white.opacity(0.4))
                                    .frame(width: 10, height: 10)
                            }
                        }
                        .frame(height: 32)
                    } onSelect: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            layoutModeRaw = MainLayoutViewMode.flatGrid.rawValue
                        }
                        SoundEffectsManager.shared.playAction()
                    }

                    // 2. Cover Flow
                    visualChoiceButton(
                        isSelected: currentMode == .coverFlow,
                        title: "Cover Flow",
                        badge: "3D Stack"
                    ) { isSel in
                        HStack(spacing: -3) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isSel ? Color.black.opacity(0.3) : Color.white.opacity(0.25))
                                .frame(width: 10, height: 18)
                                .rotationEffect(.degrees(10))

                            RoundedRectangle(cornerRadius: 3)
                                .fill(isSel ? Color.black : Color.white)
                                .frame(width: 16, height: 24)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(isSel ? Color.black.opacity(0.3) : Color.white.opacity(0.25))
                                .frame(width: 10, height: 18)
                                .rotationEffect(.degrees(-10))
                        }
                        .frame(height: 32)
                    } onSelect: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            layoutModeRaw = MainLayoutViewMode.coverFlow.rawValue
                        }
                        SoundEffectsManager.shared.playAction()
                    }

                    // 3. Curved Wall
                    visualChoiceButton(
                        isSelected: currentMode == .gridWall,
                        title: "Curved Wall",
                        badge: "Cylindrical"
                    ) { isSel in
                        HStack(spacing: 3) {
                            ForEach(0..<4) { idx in
                                miniWallBarPreview(index: idx, isSelected: isSel)
                            }
                        }
                        .frame(height: 32)
                    } onSelect: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            layoutModeRaw = MainLayoutViewMode.gridWall.rawValue
                        }
                        SoundEffectsManager.shared.playAction()
                    }
                }
                .padding(10)

                if (MainLayoutViewMode(rawValue: layoutModeRaw) ?? .coverFlow) == .flatGrid {
                    settingsDivider

                    settingsRow(
                        icon: "square.grid.3x3.fill",
                        iconColor: Color(red: 0.2, green: 0.8, blue: 0.4),
                        title: "Flat Grid Rows",
                        subtitle: "Number of rows displayed per screen"
                    ) {
                        HStack(spacing: 6) {
                            ForEach(1...5, id: \.self) { count in
                                let isSelected = threeDSGridRows == count
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        threeDSGridRows = count
                                    }
                                    SoundEffectsManager.shared.playAction()
                                }) {
                                    Text("\(count)")
                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                        .frame(width: 26, height: 22)
                                        .background(isSelected ? Color.white : Color.white.opacity(0.08))
                                        .foregroundStyle(isSelected ? Color.black : Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Desktop Dimming
            settingsGroupBox {
                settingsRow(
                    icon: "circle.lefthalf.filled",
                    iconColor: Color(red: 1.0, green: 0.75, blue: 0.0),
                    title: "Desktop Dimming",
                    subtitle: "Background dimming intensity when launcher is active"
                ) {
                    HStack(spacing: 10) {
                        Slider(value: $dimmingIntensity, in: 0.05...0.45)
                            .tint(Color(red: 1.0, green: 0.75, blue: 0.0))
                            .frame(width: 120)

                        pillBadge(text: "\(Int(dimmingIntensity * 100))%")
                    }
                }
            }

            // Footer
            settingsFooter(
                text: "Themes, materials, and 3D presentation options",
                actionTitle: "Reset to Defaults",
                accentColor: Color(red: 0.65, green: 0.35, blue: 1.0)
            ) {
                themeManager.setTheme(.liquidGlass)
                appDisplayStyleRaw = AppDisplayStyle.iconOnly.rawValue
                layoutModeRaw = MainLayoutViewMode.coverFlow.rawValue
                threeDSGridRows = 3
                dimmingIntensity = 0.15
                SoundEffectsManager.shared.playAction()
            }
        }
    }

    private func themeVisualTile(theme: AppVisualTheme) -> some View {
        let isSelected = themeManager.currentTheme == theme
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                themeManager.setTheme(theme)
            }
            SoundEffectsManager.shared.playAction()
        }) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.cardBackgroundGradient)

                    Image(systemName: "app.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(theme == .matteWhite ? Color.black.opacity(0.8) : Color.white.opacity(0.9))
                }
                .frame(width: 36, height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(theme.cardBorderGradient(isSelected: isSelected), lineWidth: 1.5)
                )
                .shadow(color: theme.selectionGlowColor.opacity(isSelected ? 0.7 : 0.15), radius: 5)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(theme.rawValue)
                            .font(.system(size: 12, weight: isSelected ? .bold : .semibold))
                            .foregroundStyle(.white)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(red: 0.65, green: 0.35, blue: 1.0))
                        }
                    }

                    Text(theme.id)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color(red: 0.65, green: 0.35, blue: 1.0).opacity(0.8) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func visualChoiceButton<Preview: View>(
        isSelected: Bool,
        title: String,
        badge: String,
        @ViewBuilder preview: (Bool) -> Preview,
        onSelect: @escaping () -> Void
    ) -> some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                preview(isSelected)

                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? Color.black : Color.white)

                    Spacer(minLength: 0)

                    Text(badge)
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(isSelected ? Color.black.opacity(0.7) : Color.white.opacity(0.45))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.1), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func miniChannelCardPreview(index: Int, isSelected: Bool) -> some View {
        let isCenter = (index == 1)
        let fill: Color = isSelected
            ? (isCenter ? Color.black.opacity(0.22) : Color.black.opacity(0.08))
            : (isCenter ? Color.white.opacity(0.25) : Color.white.opacity(0.08))
        let stroke: Color = isSelected
            ? (isCenter ? Color.black.opacity(0.6) : Color.black.opacity(0.15))
            : (isCenter ? Color.white.opacity(0.6) : Color.white.opacity(0.12))
        let size: CGFloat = isCenter ? 26 : 20

        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
    }

    private func miniFullWindowPreview(isSelected: Bool) -> some View {
        let dotColor: Color = isSelected ? Color.black.opacity(0.65) : Color.white.opacity(0.75)
        let dividerColor: Color = isSelected ? Color.black.opacity(0.12) : Color.white.opacity(0.12)
        let outerCardFill: Color = isSelected ? Color.black.opacity(0.1) : Color.white.opacity(0.1)
        let centerCardFill: Color = isSelected ? Color.black.opacity(0.25) : Color.white.opacity(0.25)
        let centerCardStroke: Color = isSelected ? Color.black.opacity(0.45) : Color.white.opacity(0.45)
        let bgFill: Color = isSelected ? Color.black.opacity(0.04) : Color.white.opacity(0.06)
        let borderStroke: Color = isSelected ? Color.black.opacity(0.3) : Color.white.opacity(0.25)

        return VStack(spacing: 0) {
            // macOS Window Title Bar with monochrome stoplight dots (white/black, no red/green/yellow)
            HStack(spacing: 3) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(dotColor)
                        .frame(width: 3.5, height: 3.5)
                }
                Spacer()
            }
            .padding(.horizontal, 5)
            .frame(height: 9)

            // Titlebar hairline divider
            Rectangle()
                .fill(dividerColor)
                .frame(height: 0.75)

            // Window content body: miniature channel preview inside window
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(outerCardFill)
                    .frame(width: 9, height: 9)
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(centerCardFill)
                    .frame(width: 12, height: 11)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .strokeBorder(centerCardStroke, lineWidth: 0.75)
                    )
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(outerCardFill)
                    .frame(width: 9, height: 9)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 48, height: 26)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(bgFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(borderStroke, lineWidth: 1)
        )
    }

    private func miniWallBarPreview(index: Int, isSelected: Bool) -> some View {
        let isProminent = (index == 1 || index == 2)
        let fill: Color = isSelected
            ? (isProminent ? Color.black.opacity(0.8) : Color.black.opacity(0.35))
            : (isProminent ? Color.white.opacity(0.6) : Color.white.opacity(0.25))
        let barHeight: CGFloat = isProminent ? 22 : 16

        return RoundedRectangle(cornerRadius: 2)
            .fill(fill)
            .frame(width: 8, height: barHeight)
    }

    // MARK: - 3. Shortcuts Settings Tab
    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            settingsSectionHeader(
                icon: "keyboard.fill",
                title: "Shortcuts",
                accentColor: Color(red: 1.0, green: 0.55, blue: 0.0)
            ) {
                pillBadge(
                    text: hotKeyManager.currentShortcutLabel,
                    color: Color(red: 1.0, green: 0.55, blue: 0.0)
                )
            }

            // Global Hotkey Box
            settingsGroupBox {
                settingsRow(
                    icon: "keyboard.fill",
                    iconColor: Color(red: 1.0, green: 0.55, blue: 0.0),
                    title: "Global Shortcut",
                    subtitle: "Summons AppsChannel floating launcher or channel window from anywhere"
                ) {
                    if isRecordingShortcut {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red).frame(width: 7, height: 7)
                            Text("Press key combination...")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)

                            Button(action: stopRecordingShortcut) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.4), lineWidth: 1)
                        )
                    } else {
                        HStack(spacing: 8) {
                            keycapPill(label: hotKeyManager.currentShortcutLabel)

                            Button(action: toggleRecordingShortcut) {
                                Text("Record")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Color(red: 1.0, green: 0.55, blue: 0.0))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                settingsDivider

                HStack(spacing: 8) {
                    Text("Quick Presets:")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(hotKeyManager.presets) { preset in
                                let isSelected = hotKeyManager.currentShortcutLabel == preset.label
                                CategoryPill(title: preset.label, isSelected: isSelected) {
                                    stopRecordingShortcut()
                                    hotKeyManager.applyPreset(preset)
                                    SoundEffectsManager.shared.playAction()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // Category Group Shortcuts (⌘1 – ⌘8)
            settingsGroupBox {
                settingsRow(
                    icon: "square.grid.3x1.folder.badge.plus",
                    iconColor: Color(red: 0.0, green: 0.75, blue: 0.85),
                    title: "Category Shortcuts (⌘1 – ⌘8)",
                    subtitle: "Jump instantly to application categories"
                ) {
                    if !shortcutManager.customGroupShortcuts.isEmpty {
                        Button("Reset Defaults") {
                            shortcutManager.resetGroupShortcuts()
                            SoundEffectsManager.shared.playAction()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.0, green: 0.75, blue: 0.85))
                    }
                }

                settingsDivider

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(1...8, id: \.self) { slot in
                        let currentAssigned = shortcutManager.category(forSlot: slot, availableCategories: availableCategories) ?? "ALL"
                        let isCustomized = shortcutManager.customGroupShortcuts[slot] != nil

                        HStack(spacing: 8) {
                            Text("⌘\(slot)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                )

                            Picker("", selection: Binding<String>(
                                get: { currentAssigned },
                                set: { newCat in
                                    shortcutManager.setGroupShortcut(category: newCat, forSlot: slot)
                                    SoundEffectsManager.shared.playAction()
                                }
                            )) {
                                ForEach(availableCategories, id: \.self) { cat in
                                    Text(cat).tag(cat)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(.white)

                            Spacer(minLength: 0)

                            if isCustomized {
                                Button(action: {
                                    shortcutManager.setGroupShortcut(category: nil, forSlot: slot)
                                    SoundEffectsManager.shared.playAction()
                                }) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(isCustomized ? Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                }
                .padding(10)
            }

            // Direct App Launch Slots (⌥1 – ⌥9)
            settingsGroupBox {
                settingsRow(
                    icon: "target",
                    iconColor: Color(red: 1.0, green: 0.3, blue: 0.3),
                    title: "Direct Launch Slots (⌥1 – ⌥9)",
                    subtitle: "Directly trigger assigned applications bypassing navigation"
                ) {
                    if !shortcutManager.customChannelSlots.isEmpty {
                        Button("Reset All") {
                            shortcutManager.resetChannelSlots()
                            SoundEffectsManager.shared.playAction()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 1.0, green: 0.3, blue: 0.3))
                    }
                }

                settingsDivider

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(1...9, id: \.self) { slot in
                        let assignedPath = shortcutManager.assignedAppPath(forSlot: slot)
                        let assignedApp = shortcutManager.assignedApp(forSlot: slot, in: discoveryService.allDiscoveredApps)
                        let isCustomized = assignedPath != nil

                        HStack(spacing: 6) {
                            Text("⌥\(slot)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                )

                            if let app = assignedApp {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14, height: 14)

                                Text(app.name)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            } else {
                                Text("Auto")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.white.opacity(0.45))
                            }

                            Spacer(minLength: 0)

                            Menu {
                                Button("Automatic (Grid \(slot))") {
                                    shortcutManager.setChannelSlot(appPath: nil, forSlot: slot)
                                    SoundEffectsManager.shared.playAction()
                                }
                                Divider()
                                ForEach(discoveryService.allDiscoveredApps) { app in
                                    Button(app.name) {
                                        shortcutManager.setChannelSlot(appPath: app.url.path, forSlot: slot)
                                        SoundEffectsManager.shared.playAction()
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(isCustomized ? Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                        )
                    }
                }
                .padding(10)
            }

            // Keyboard Modifiers & Contextual Power Actions
            settingsGroupBox {
                settingsRow(
                    icon: "command",
                    iconColor: Color(red: 1.0, green: 0.82, blue: 0.2),
                    title: "Keyboard Modifiers & Power Actions",
                    subtitle: "Hold modifier keys while pressing Return (↵) on any focused app"
                ) {
                    EmptyView()
                }

                settingsDivider

                modifierHintRow(keys: "↵", label: "Launch Focused Application", icon: "arrow.up.forward.app.fill")
                settingsDivider
                modifierHintRow(keys: "⌘↵", label: "Reveal in macOS Finder", icon: "folder.fill")
                settingsDivider
                modifierHintRow(keys: "⌥↵", label: "Open Recent Documents Sub-Deck", icon: "clock.arrow.circlepath")
                settingsDivider
                modifierHintRow(keys: "⇧↵", label: "Copy Bundle Path or Web URL", icon: "doc.on.doc.fill")
            }

            // Quick System Actions Settings
            settingsGroupBox {
                settingsRow(
                    icon: "bolt.badge.automatic.fill",
                    iconColor: Color(red: 0.2, green: 0.8, blue: 0.4),
                    title: "Quick System Actions",
                    subtitle: "Include Lock Screen, Sleep, Restart, Trash, Dark Mode, and Mute in search and grid"
                ) {
                    Toggle("", isOn: $enableSystemActions)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(Color(red: 0.2, green: 0.8, blue: 0.4))
                        .onChange(of: enableSystemActions) { _, _ in
                            AppDiscoveryService.shared.reloadAfterCustomChannelChange()
                        }
                }

                if enableSystemActions {
                    settingsDivider

                    settingsRow(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: Color(red: 1.0, green: 0.75, blue: 0.0),
                        title: "Confirm Destructive Actions",
                        subtitle: "Require confirmation modal before executing Restart and Shut Down"
                    ) {
                        Toggle("", isOn: $confirmDestructiveActions)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(Color(red: 1.0, green: 0.75, blue: 0.0))
                    }
                }
            }

            // System Integration Links
            settingsGroupBox {
                settingsRow(
                    icon: "bolt.fill",
                    iconColor: Color(red: 0.05, green: 0.52, blue: 1.0),
                    title: "macOS Shortcuts App",
                    subtitle: "Cold start trigger via macOS system daemon"
                ) {
                    Button(action: {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                    }) {
                        Text("Open Shortcuts")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                settingsDivider

                settingsRow(
                    icon: "gearshape.fill",
                    iconColor: Color.gray,
                    title: "System Settings",
                    subtitle: "macOS native Keyboard Shortcuts"
                ) {
                    Button(action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Text("Open Settings")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Footer
            settingsFooter(
                text: "Global triggers, direct launch slots, and power modifiers",
                actionTitle: "Reset All Shortcuts",
                accentColor: Color(red: 1.0, green: 0.55, blue: 0.0)
            ) {
                hotKeyManager.applyPreset(hotKeyManager.presets[0])
                shortcutManager.resetGroupShortcuts()
                shortcutManager.resetChannelSlots()
                SoundEffectsManager.shared.playAction()
            }
        }
    }

    private func modifierHintRow(keys: String, label: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )

            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }

    private func keycapPill(label: String) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            )
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

            let char: String
            if event.keyCode == 49 {
                char = "Space"
            } else if let raw = event.charactersIgnoringModifiers?.uppercased(), !raw.isEmpty && raw != " " {
                char = raw
            } else {
                char = "Key"
            }
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

    // MARK: - 4. Channels Settings Tab
    private var customChannelsSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            settingsSectionHeader(
                icon: "plus.rectangle.on.rectangle.fill",
                title: "Channels",
                accentColor: Color(red: 0.1, green: 0.75, blue: 0.5)
            ) {
                Button(action: {
                    isShowingAddChannelSheet = true
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                        Text("Add Channel")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 0.1, green: 0.75, blue: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // Pinned Custom Channels Box
            settingsGroupBox {
                settingsRow(
                    icon: "star.fill",
                    iconColor: Color(red: 0.1, green: 0.75, blue: 0.5),
                    title: "Pinned Custom Channels",
                    subtitle: "\(customChannelManager.channels.count) custom web apps, shortcuts, or scripts pinned to grid"
                ) {
                    pillBadge(text: "\(customChannelManager.channels.count) Pinned")
                }

                settingsDivider

                if customChannelManager.channels.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.square.dashed")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No custom channels created yet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Button("Add Custom Channel") {
                            isShowingAddChannelSheet = true
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.1, green: 0.75, blue: 0.5))
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(customChannelManager.channels) { record in
                        customChannelRow(channel: record)
                        if record != customChannelManager.channels.last {
                            settingsDivider
                        }
                    }
                }
            }

            // CLI Companion (appschannel) Box
            settingsGroupBox {
                settingsRow(
                    icon: "terminal.fill",
                    iconColor: Color(red: 0.65, green: 0.35, blue: 1.0),
                    title: "CLI Companion (appschannel)",
                    subtitle: cliManager.isInstalled ? (cliManager.installedPath ?? "Installed in system PATH") : "Script AppsChannel from Terminal or Raycast"
                ) {
                    HStack(spacing: 6) {
                        if cliManager.isInstalled {
                            pillBadge(text: "Installed", color: .green, bgOpacity: 0.15)

                            Button("Reinstall") {
                                cliManager.installCLI()
                            }
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .buttonStyle(.plain)

                            Button("Uninstall") {
                                cliManager.uninstallCLI()
                            }
                            .font(.system(size: 10.5))
                            .foregroundStyle(.red.opacity(0.9))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .buttonStyle(.plain)
                        } else {
                            pillBadge(text: "Not in PATH", color: .orange, bgOpacity: 0.15)

                            Button("Install CLI") {
                                cliManager.installCLI()
                            }
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.65, green: 0.35, blue: 1.0))
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .buttonStyle(.plain)
                        }
                    }
                }

                settingsDivider

                VStack(alignment: .leading, spacing: 6) {
                    Text("Quick Commands (Click to copy)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))

                    HStack(spacing: 6) {
                        cliCommandChip(command: "appschannel toggle")
                        cliCommandChip(command: "appschannel launch Safari")
                        cliCommandChip(command: "appschannel theme liquid-glass")
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            // Footer
            settingsFooter(
                text: "\(customChannelManager.channels.count) custom channels configured",
                accentColor: Color(red: 0.1, green: 0.75, blue: 0.5)
            )
        }
    }

    private func cliCommandChip(command: String) -> some View {
        let isCopied = copiedCommandText == command
        return Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            SoundEffectsManager.shared.playAction()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                copiedCommandText = command
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    if copiedCommandText == command { copiedCommandText = nil }
                }
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9, weight: .bold))
                Text(isCopied ? "Copied" : command)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(isCopied ? Color.green : Color.white.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isCopied ? Color.green.opacity(0.15) : Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isCopied ? Color.green.opacity(0.3) : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func customChannelRow(channel: CustomChannelRecord) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(hex: channel.accentHex) ?? Color(red: 0.1, green: 0.75, blue: 0.5))
                    .frame(width: 24, height: 24)

                Image(systemName: channel.kind == .web ? "globe" : (channel.kind == .shortcut ? "bolt.fill" : "terminal.fill"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(channel.target)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            pillBadge(text: channel.kind.rawValue.capitalized, color: .white.opacity(0.7), bgOpacity: 0.05)

            Button(role: .destructive) {
                customChannelManager.removeChannel(id: channel.id)
                SoundEffectsManager.shared.playAction()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(5)
            }
            .buttonStyle(.plain)
            .help("Delete custom channel")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    // MARK: - 5. Hidden Apps Tab
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
            // Header
            settingsSectionHeader(
                icon: "eye.slash.fill",
                title: "Application Visibility",
                accentColor: Color(red: 1.0, green: 0.65, blue: 0.1)
            ) {
                HStack(spacing: 6) {
                    pillBadge(text: "\(categoryVisibleCount) Visible")
                    if categoryHiddenCount > 0 {
                        pillBadge(
                            text: "\(categoryHiddenCount) Hidden",
                            color: Color(red: 1.0, green: 0.65, blue: 0.1),
                            bgOpacity: 0.15
                        )
                    }
                }
            }

            // Search Bar & Category Filter Pills
            HStack(spacing: 8) {
                // Search Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))

                    TextField("Search applications...", text: $hiddenAppsSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.white)

                    if !hiddenAppsSearchText.isEmpty {
                        Button(action: { hiddenAppsSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )

                // Category Filter Pills ScrollView
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(allCategories, id: \.self) { cat in
                            let isSelected = hiddenAppsCategoryFilter == cat
                            let appsInCat = discoveryService.allDiscoveredApps.filter { cat == "ALL" || $0.category == cat }
                            let hiddenInCat = appsInCat.filter { discoveryService.isHidden(app: $0) }.count
                            CategoryPill(
                                title: cat,
                                count: hiddenInCat > 0 ? hiddenInCat : nil,
                                isSelected: isSelected
                            ) {
                                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                    hiddenAppsCategoryFilter = cat
                                }
                                SoundEffectsManager.shared.playAction()
                            }
                        }
                    }
                }
            }

            // Sub-bar: Count & Batch Toggle
            HStack {
                Text("\(filteredManagerApps.count) applications" + (hiddenAppsCategoryFilter == "ALL" ? "" : " in \(hiddenAppsCategoryFilter)"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))

                Spacer()

                Button(action: {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        if categoryVisibleCount > 0 {
                            discoveryService.hideGroup(category: hiddenAppsCategoryFilter)
                        } else {
                            discoveryService.unhideGroup(category: hiddenAppsCategoryFilter)
                        }
                        SoundEffectsManager.shared.playAction()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: categoryVisibleCount > 0 ? "eye.slash" : "eye")
                            .font(.system(size: 10, weight: .semibold))
                        Text(categoryVisibleCount > 0 ? "Hide All in \(hiddenAppsCategoryFilter)" : "Unhide All in \(hiddenAppsCategoryFilter)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            // Application Rows Table
            if filteredManagerApps.isEmpty {
                settingsGroupBox {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.25))
                            Text("No applications match your filter")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.vertical, 28)
                        Spacer()
                    }
                }
            } else {
                settingsGroupBox {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredManagerApps.enumerated()), id: \.element.id) { index, app in
                            if index > 0 {
                                settingsDivider
                            }
                            appManagerCompactRow(app: app)
                        }
                    }
                }
            }

            // Footer
            settingsFooter(
                text: "\(discoveryService.hiddenAppPaths.count) of \(discoveryService.allDiscoveredApps.count) apps hidden from launcher",
                actionTitle: discoveryService.hiddenAppPaths.isEmpty ? nil : "Unhide All (\(discoveryService.hiddenAppPaths.count))",
                accentColor: Color(red: 1.0, green: 0.65, blue: 0.1),
                action: discoveryService.hiddenAppPaths.isEmpty ? nil : {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        discoveryService.unhideAllApps()
                        SoundEffectsManager.shared.playAction()
                    }
                }
            )
        }
    }

    private func appManagerCompactRow(app: DiscoveredApp) -> some View {
        let isHidden = discoveryService.isHidden(app: app)
        return HStack(spacing: 12) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .opacity(isHidden ? 0.35 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isHidden ? .white.opacity(0.45) : .white)
                    .lineLimit(1)

                Text(app.category.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(isHidden ? .white.opacity(0.25) : .white.opacity(0.45))
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    discoveryService.toggleHidden(app: app)
                }
                SoundEffectsManager.shared.playAction()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(isHidden ? "Hidden" : "Visible")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(isHidden ? Color(red: 1.0, green: 0.65, blue: 0.1) : Color.white.opacity(0.85))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    isHidden ? Color(red: 1.0, green: 0.65, blue: 0.1).opacity(0.18) : Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isHidden ? Color(red: 1.0, green: 0.65, blue: 0.1).opacity(0.3) : Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }

    // MARK: - 6. About Settings Tab (Hero & Actions)
    private var aboutSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            settingsSectionHeader(
                icon: "info.circle.fill",
                title: "About AppsChannel",
                accentColor: Color(red: 0.05, green: 0.52, blue: 1.0)
            ) {
                pillBadge(text: appVersionString)
            }

            // Hero Branding Box
            settingsGroupBox {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: .white.opacity(0.15), radius: 8, y: 2)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text("AppsChannel")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            pillBadge(text: appVersionString, color: .white, bgOpacity: 0.15)
                        }

                        Text("Cover Flow meets the Channel Grid for macOS")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.65))

                        HStack(spacing: 6) {
                            pillBadge(text: "Offline First", color: .white.opacity(0.7), bgOpacity: 0.06)
                            pillBadge(text: "Zero Telemetry", color: .white.opacity(0.7), bgOpacity: 0.06)
                            pillBadge(text: "MIT License", color: .white.opacity(0.7), bgOpacity: 0.06)
                        }
                        .padding(.top, 2)
                    }

                    Spacer()
                }
                .padding(14)
            }

            // Actions & Links Box
            settingsGroupBox {
                #if !APP_STORE
                settingsRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconColor: Color(red: 0.05, green: 0.52, blue: 1.0),
                    title: "Check for Updates",
                    subtitle: "Sparkle automatic updater"
                ) {
                    Button(action: {
                        UpdateManager.shared.checkForUpdates()
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Check Now")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                settingsDivider
                #endif

                settingsRow(
                    icon: "link",
                    iconColor: Color(red: 0.58, green: 0.35, blue: 0.95),
                    title: "Source Code & Issues",
                    subtitle: "github.com/micah1crandell/AppsChannel"
                ) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/micah1crandell/AppsChannel") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 5) {
                            Text("Open GitHub")
                                .font(.system(size: 11, weight: .medium))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                settingsDivider

                settingsRow(
                    icon: "cup.and.saucer.fill",
                    iconColor: Color(red: 1.0, green: 0.65, blue: 0.1),
                    title: "Support the Project",
                    subtitle: "buymeacoffee.com/micahcrandell"
                ) {
                    Button(action: {
                        if let url = URL(string: "https://www.buymeacoffee.com/micahcrandell") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.pink)
                            Text("Tip Jar")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                settingsDivider

                settingsRow(
                    icon: "laptopcomputer",
                    iconColor: Color(white: 0.4),
                    title: "macOS Compatibility",
                    subtitle: "Designed for macOS Sonoma (14.0) and Sequoia (15.0+)"
                ) {
                    pillBadge(text: "macOS 14.0+")
                }
            }

            // Footer
            settingsFooter(text: "AppsChannel • Crafted with Swift & SwiftUI")
        }
    }
}
