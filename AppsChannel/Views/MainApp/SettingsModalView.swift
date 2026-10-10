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
        case channels = "Channels"
        case hiddenApps = "Hidden Apps"
        case about = "About"

        var id: String { rawValue }

        var iconName: String {
            switch self {
            case .general: return "gearshape.fill"
            case .appearance: return "paintpalette.fill"
            case .shortcuts: return "keyboard.fill"
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

    // MARK: - Reusable Obsidian Glass Card Container
    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.07).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    // MARK: - 1. General Settings Tab
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Default Launcher Mode (Show Not Tell - Visual Card Selector)
            settingsCard(title: "Default Mode (Opens on Shortcut & Launch)", icon: "slider.horizontal.2.square") {
                HStack(spacing: 12) {
                    visualModeCard(
                        mode: .quickLauncher,
                        title: "Quick Launcher",
                        badge: "Floating HUD",
                        isSelected: defaultMode == LauncherMode.quickLauncher.rawValue
                    ) { isSel in
                        // Mini Floating HUD Mockup
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isSel ? Color.black.opacity(0.7) : Color.white.opacity(0.7))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isSel ? Color.black.opacity(0.3) : Color.white.opacity(0.3))
                                .frame(width: 32, height: 4)
                            Spacer()
                            Circle()
                                .fill(Color.green)
                                .frame(width: 4, height: 4)
                        }
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(isSel ? Color.black.opacity(0.08) : Color.black.opacity(0.55), in: Capsule())
                        .overlay(Capsule().strokeBorder(isSel ? Color.black.opacity(0.18) : Color.white.opacity(0.2), lineWidth: 1))
                    }

                    visualModeCard(
                        mode: .fullScreen,
                        title: "Channel Window",
                        badge: "Full Menu",
                        isSelected: defaultMode == LauncherMode.fullScreen.rawValue
                    ) { isSel in
                        // Mini Channel Cards Mockup
                        HStack(spacing: 5) {
                            ForEach(0..<3) { idx in
                                miniChannelCardPreview(index: idx, isSelected: isSel)
                            }
                        }
                        .frame(height: 24)
                    }
                }
            }

            // System Integration
            settingsCard(title: "System Integration", icon: "macwindow") {
                VStack(spacing: 10) {
                    HStack {
                        settingLabel(icon: "power", title: "Launch at Login", subtitle: "Background daemon responds to hotkey instantly")
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { launchAtLoginManager.isEnabled },
                            set: { launchAtLoginManager.setEnabled($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(.white)
                    }

                    Divider().background(Color.white.opacity(0.06))

                    HStack {
                        settingLabel(icon: "menubar.arrow.up.rectangle", title: "Show in Menu Bar", subtitle: "Cover Flow icon in status bar")
                        Spacer()
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
                        .tint(.white)
                    }

                    Divider().background(Color.white.opacity(0.06))

                    HStack {
                        settingLabel(icon: "dock.rectangle", title: "Show in Dock", subtitle: "Visible alongside macOS applications")
                        Spacer()
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
                        .tint(.white)
                    }
                }
            }

            // Sound & Haptics (Show Not Tell - Live Sound Preview Button)
            settingsCard(title: "Audio & Feedback", icon: "speaker.wave.2.fill") {
                VStack(spacing: 10) {
                    HStack {
                        settingLabel(icon: "speaker.wave.2", title: "Sound Effects", subtitle: "Audio cues for navigation and launches")

                        Spacer()

                        if soundEffects {
                            HStack(spacing: 8) {
                                Picker("", selection: $soundThemeRaw) {
                                    ForEach(SoundTheme.allCases) { theme in
                                        Text(theme.rawValue).tag(theme.rawValue)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .tint(.white)
                                .frame(width: 140)
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
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Color.white, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .help("Preview sound")
                            }
                        }

                        Toggle("", isOn: $soundEffects)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(.white)
                    }

                    Divider().background(Color.white.opacity(0.06))

                    HStack {
                        settingLabel(icon: "hand.tap.fill", title: "Trackpad Haptics", subtitle: "Force Touch alignment pulses")
                        Spacer()
                        Toggle("", isOn: $hapticFeedback)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(.white)
                    }
                }
            }

            // Smart Ranking (Show Not Tell - Visual Diagram)
            settingsCard(title: "Smart Ranking", icon: "chart.line.uptrend.xyaxis") {
                HStack(spacing: 14) {
                    // Mini Visual Diagram of Center-Out arrangement
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
                    .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Center-Out Distribution")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Most used apps occupy the center slots for fastest reach")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.55))
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
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
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
                            .foregroundStyle(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .help("Reorder cards by current launch frequency")
                    }
                }
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
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.black.opacity(0.1) : Color.white.opacity(0.08), in: Capsule())
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.12), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func settingLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - 2. Appearance Settings Tab (Show Not Tell Gallery)
    private var appearanceSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Visual Theme (Show Not Tell - 2x2 Interactive Gallery Cards)
            settingsCard(title: "Visual Theme", icon: "sparkles") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(AppVisualTheme.allCases) { theme in
                        themeVisualTile(theme: theme)
                    }
                }
            }

            // Presentation Style (Show Not Tell - Icon Only vs Channel Card)
            settingsCard(title: "App Presentation", icon: "app.badge.fill") {
                HStack(spacing: 12) {
                    let currentStyle = AppDisplayStyle(rawValue: appDisplayStyleRaw) ?? .iconOnly

                    // Style 1: Icon Only
                    visualChoiceButton(
                        isSelected: currentStyle == .iconOnly,
                        title: "App Icon Only",
                        badge: "Minimalist"
                    ) { isSel in
                        // Mini Icon Floating Graphic
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
                        // Mini Card Graphic
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
            }

            // Default Layout Mode (Show Not Tell - 3 Interactive Diagrams)
            settingsCard(title: "Default Layout (⌘V to cycle)", icon: "square.grid.2x2.fill") {
                VStack(spacing: 10) {
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

                        // 3. Curved Wall Grid
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

                    // Flat Grid Rows Stepper (if Flat Grid active)
                    if (MainLayoutViewMode(rawValue: layoutModeRaw) ?? .coverFlow) == .flatGrid {
                        HStack(spacing: 8) {
                            Text("Rows:")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.7))

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
                                        .frame(width: 28, height: 22)
                                        .background(isSelected ? Color.white : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                                        .foregroundStyle(isSelected ? Color.black : Color.white)
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                }
            }

            // Desktop Dimming
            settingsCard(title: "Desktop Dimming", icon: "circle.lefthalf.filled") {
                HStack(spacing: 12) {
                    Slider(value: $dimmingIntensity, in: 0.05...0.45)
                        .tint(.white)

                    Text("\(Int(dimmingIntensity * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .frame(width: 38)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
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
                // Mini Card Mockup with actual gradient and border
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
                                .foregroundStyle(.white)
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.white : Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.1), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    // MARK: - 3. Shortcuts Settings Tab (Show Not Tell)
    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Global Hotkey (Tactile Keycap Display)
            settingsCard(title: "Global Shortcut", icon: "keyboard.fill") {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        // Tactile Keycap Badge
                        HStack(spacing: 6) {
                            if isRecordingShortcut {
                                HStack(spacing: 5) {
                                    Circle().fill(Color.red).frame(width: 8, height: 8)
                                    Text("Press key combination...")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.red.opacity(0.2), in: Capsule())
                            } else {
                                keycapPill(label: hotKeyManager.currentShortcutLabel)
                            }
                        }

                        Spacer()

                        Button(action: toggleRecordingShortcut) {
                            HStack(spacing: 5) {
                                Image(systemName: isRecordingShortcut ? "xmark.circle.fill" : "record.circle")
                                    .foregroundStyle(isRecordingShortcut ? .red : .black)
                                Text(isRecordingShortcut ? "Cancel" : "Record Shortcut")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.black)
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Color.white, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    // Presets Grid (Uniform Size & Scale)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Presets")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(hotKeyManager.presets) { preset in
                                let isSelected = hotKeyManager.currentShortcutLabel == preset.label
                                Button(action: {
                                    stopRecordingShortcut()
                                    hotKeyManager.applyPreset(preset)
                                    SoundEffectsManager.shared.playAction()
                                }) {
                                    Text(preset.label)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .monospaced))
                                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.85))
                                        .frame(maxWidth: .infinity, minHeight: 28)
                                        .background(isSelected ? Color.white : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            // Category Group Shortcuts (Compact 2-Column Grid)
            settingsCard(title: "Category Shortcuts (⌘1 – ⌘8)", icon: "square.grid.3x1.folder.badge.plus") {
                VStack(spacing: 8) {
                    if !shortcutManager.customGroupShortcuts.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: {
                                shortcutManager.resetGroupShortcuts()
                                SoundEffectsManager.shared.playAction()
                            }) {
                                Text("Reset Defaults")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.08), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(1...8, id: \.self) { slot in
                            let currentAssigned = shortcutManager.category(forSlot: slot, availableCategories: availableCategories) ?? "ALL"
                            let isCustomized = shortcutManager.customGroupShortcuts[slot] != nil

                            HStack(spacing: 8) {
                                Text("⌘\(slot)")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.white, in: RoundedRectangle(cornerRadius: 5))

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
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(isCustomized ? Color.white.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            // Direct App Launch Slots (Compact 3-Column Grid)
            settingsCard(title: "Direct Launch Slots (⌥1 – ⌥9)", icon: "target") {
                VStack(spacing: 8) {
                    if !shortcutManager.customChannelSlots.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: {
                                shortcutManager.resetChannelSlots()
                                SoundEffectsManager.shared.playAction()
                            }) {
                                Text("Reset All")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.08), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(1...9, id: \.self) { slot in
                            let assignedPath = shortcutManager.assignedAppPath(forSlot: slot)
                            let assignedApp = shortcutManager.assignedApp(forSlot: slot, in: discoveryService.allDiscoveredApps)
                            let isCustomized = assignedPath != nil

                            HStack(spacing: 6) {
                                Text("⌥\(slot)")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.white, in: RoundedRectangle(cornerRadius: 4))

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
                            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(isCustomized ? Color.white.opacity(0.22) : Color.white.opacity(0.06), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            // System Integration Links
            settingsCard(title: "macOS System Shortcuts", icon: "applelogo") {
                HStack(spacing: 12) {
                    quickActionCard(
                        icon: "bolt.fill",
                        title: "Shortcuts App",
                        desc: "Cold start trigger via system daemon",
                        actionTitle: "Open Shortcuts"
                    ) {
                        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
                    }

                    quickActionCard(
                        icon: "gearshape.fill",
                        title: "System Settings",
                        desc: "macOS native Keyboard Shortcuts",
                        actionTitle: "Open Settings"
                    ) {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
    }

    private func keycapPill(label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "keyboard")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))

            Text(label)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func quickActionCard(
        icon: String,
        title: String,
        desc: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(action: action) {
                Text(actionTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 9))
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
            // Pinned Channels
            settingsCard(title: "Custom Channels", icon: "plus.rectangle.on.rectangle.fill") {
                VStack(spacing: 10) {
                    HStack {
                        Text("\(customChannelManager.channels.count) Pinned Channels")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))

                        Spacer()

                        Button {
                            isShowingAddChannelSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add Channel")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4.5)
                            .background(Color.white, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    if customChannelManager.channels.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 6) {
                                Image(systemName: "plus.square.dashed")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.3))
                                Text("No custom channels yet")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(.vertical, 16)
                            Spacer()
                        }
                    } else {
                        VStack(spacing: 6) {
                            ForEach(customChannelManager.channels) { record in
                                customChannelRow(channel: record)
                            }
                        }
                    }
                }
            }

            // Command-Line Companion
            settingsCard(title: "CLI Companion (appschannel)", icon: "terminal.fill") {
                VStack(spacing: 10) {
                    HStack {
                        if cliManager.isInstalled {
                            HStack(spacing: 5) {
                                Circle().fill(Color.green).frame(width: 6, height: 6)
                                Text("Installed")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.green)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12), in: Capsule())
                        } else {
                            HStack(spacing: 5) {
                                Circle().fill(Color.orange).frame(width: 6, height: 6)
                                Text("Not in PATH")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                        }

                        if let path = cliManager.installedPath {
                            Text(path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        Button {
                            cliManager.installCLI()
                        } label: {
                            Text(cliManager.isInstalled ? "Reinstall" : "Install CLI")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)

                        if cliManager.isInstalled {
                            Button(role: .destructive) {
                                cliManager.uninstallCLI()
                            } label: {
                                Text("Uninstall")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.red.opacity(0.85))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Click to Copy Command Chips
                    HStack(spacing: 6) {
                        cliCommandChip(command: "appschannel toggle")
                        cliCommandChip(command: "appschannel launch Safari")
                        cliCommandChip(command: "appschannel theme liquid-glass")
                        Spacer()
                    }
                }
            }
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
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9))
                Text(isCopied ? "Copied" : command)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(isCopied ? Color.green : Color.white.opacity(0.8))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(isCopied ? Color.green.opacity(0.15) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private func customChannelRow(channel: CustomChannelRecord) -> some View {
        HStack(spacing: 9) {
            Circle()
                .fill(Color(hex: channel.accentHex) ?? .blue)
                .frame(width: 8, height: 8)

            Image(systemName: channel.kind == .web ? "globe" : (channel.kind == .shortcut ? "bolt.fill" : "terminal.fill"))
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.8))

            Text(channel.name)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white)

            Text(channel.target)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(role: .destructive) {
                customChannelManager.removeChannel(id: channel.id)
                SoundEffectsManager.shared.playAction()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundStyle(.red.opacity(0.8))
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
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
            settingsCard(title: "Application Visibility", icon: "eye.slash.fill") {
                VStack(spacing: 10) {
                    // Search & Batch Bar
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))

                            TextField("Search applications...", text: $hiddenAppsSearchText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundStyle(.white)

                            if !hiddenAppsSearchText.isEmpty {
                                Button(action: { hiddenAppsSearchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))

                        Spacer()

                        // Counters
                        HStack(spacing: 5) {
                            Text("\(categoryVisibleCount) Visible")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.green.opacity(0.9))

                            Text("•")
                                .foregroundStyle(.white.opacity(0.3))

                            Text("\(categoryHiddenCount) Hidden")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(categoryHiddenCount > 0 ? .orange : .white.opacity(0.4))
                        }

                        // Batch Toggle
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
                            Text(categoryVisibleCount > 0 ? "Hide All" : "Unhide All")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }

                    // Category Filter Strip
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(allCategories, id: \.self) { cat in
                                let isSelected = hiddenAppsCategoryFilter == cat
                                let appsInCat = discoveryService.allDiscoveredApps.filter { cat == "ALL" || $0.category == cat }
                                let hiddenInCat = appsInCat.filter { discoveryService.isHidden(app: $0) }.count

                                Button(action: {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        hiddenAppsCategoryFilter = cat
                                    }
                                    SoundEffectsManager.shared.playAction()
                                }) {
                                    HStack(spacing: 4) {
                                        Text(cat)
                                            .font(.system(size: 9.5, weight: isSelected ? .bold : .medium))

                                        if hiddenInCat > 0 {
                                            Text("\(hiddenInCat)")
                                                .font(.system(size: 8, weight: .bold))
                                                .padding(.horizontal, 3)
                                                .background(isSelected ? Color.black.opacity(0.2) : Color.orange.opacity(0.3), in: Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(isSelected ? Color.white : Color.white.opacity(0.06), in: Capsule())
                                    .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    // App Rows
                    if filteredManagerApps.isEmpty {
                        Text("No apps match filter")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.vertical, 12)
                    } else {
                        LazyVStack(spacing: 4) {
                            ForEach(filteredManagerApps) { app in
                                appManagerCompactRow(app: app)
                            }
                        }
                    }

                    if !discoveryService.hiddenAppPaths.isEmpty {
                        Divider().background(Color.white.opacity(0.06))

                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                discoveryService.unhideAllApps()
                                SoundEffectsManager.shared.playAction()
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Unhide All Applications (\(discoveryService.hiddenAppPaths.count))")
                            }
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func appManagerCompactRow(app: DiscoveredApp) -> some View {
        let isHidden = discoveryService.isHidden(app: app)
        return HStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .opacity(isHidden ? 0.4 : 1.0)

            Text(app.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isHidden ? .white.opacity(0.4) : .white)

            Text(app.category.uppercased())
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(isHidden ? .white.opacity(0.25) : .white.opacity(0.55))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    discoveryService.toggleHidden(app: app)
                }
                SoundEffectsManager.shared.playAction()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 9))
                    Text(isHidden ? "Hidden" : "Visible")
                        .font(.system(size: 9.5, weight: .semibold))
                }
                .foregroundStyle(isHidden ? Color.orange : Color.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(isHidden ? Color.orange.opacity(0.18) : Color.white.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(isHidden ? 0.015 : 0.04), in: RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 6. About Settings Tab (Hero & Actions)
    private var aboutSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsCard(title: "AppsChannel", icon: "info.circle.fill") {
                VStack(spacing: 14) {
                    // Hero
                    HStack(spacing: 14) {
                        Image(nsImage: NSApp.applicationIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .shadow(color: .white.opacity(0.2), radius: 8)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 7) {
                                Text("AppsChannel")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)

                                Text(appVersionString)
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white, in: Capsule())
                            }

                            Text("Cover Flow meets the Channel Grid for macOS")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Action Buttons Grid
                    HStack(spacing: 8) {
                        aboutActionButton(
                            icon: "arrow.triangle.2.circlepath",
                            title: "Check Updates"
                        ) {
                            UpdateManager.shared.checkForUpdates()
                        }

                        aboutActionButton(
                            icon: "link",
                            title: "GitHub"
                        ) {
                            if let url = URL(string: "https://github.com/micah1crandell/AppsChannel") {
                                NSWorkspace.shared.open(url)
                            }
                        }

                        aboutActionButton(
                            icon: "cup.and.saucer.fill",
                            title: "Tip Jar"
                        ) {
                            if let url = URL(string: "https://www.buymeacoffee.com/micahcrandell") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Footer
                    HStack {
                        Text("MIT License • Offline First • Zero Telemetry")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer()
                        Text("macOS 14.0+")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
            }
        }
    }

    private func aboutActionButton(
        icon: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 10.5, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
