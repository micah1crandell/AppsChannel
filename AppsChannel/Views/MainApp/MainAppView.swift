import SwiftUI
import AppKit
import Combine

@MainActor
final class MainAppState: ObservableObject {
    static let shared = MainAppState()
    @Published var isShowingSettings: Bool = false
    @Published var isShowingWalkthrough: Bool = false
    var eventMonitor: Any? = nil

    init() {
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedWalkthrough")
        if !hasCompleted {
            isShowingWalkthrough = true
        }
    }
}

struct MainAppView: View {
    @StateObject private var discoveryService = AppDiscoveryService.shared
    @ObservedObject private var appState = MainAppState.shared
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "ALL"
    @State private var scrollAccumulator: CGFloat = 0.0

    @AppStorage("mainLayoutMode") private var layoutModeRaw: String = MainLayoutViewMode.gridWall.rawValue
    @AppStorage("appDisplayStyle") private var appDisplayStyleRaw: String = AppDisplayStyle.iconOnly.rawValue
    @AppStorage("threeDSGridRows") private var threeDSGridRows: Int = 3
    @State private var layoutMode: MainLayoutViewMode = .gridWall
    @State private var isOrganizeMode: Bool = false
    @State private var showRecentDocs: Bool = false
    @State private var isShowingAddChannelSheet: Bool = false
    @State private var toastMessage: String? = nil
    @ObservedObject private var modifierManager = KeyboardModifierManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onSwitchToQuickLauncher: () -> Void
    let onDismiss: () -> Void

    private var appDisplayStyle: AppDisplayStyle {
        AppDisplayStyle(rawValue: appDisplayStyleRaw) ?? .iconOnly
    }

    private var isIconOnly: Bool {
        appDisplayStyle == .iconOnly
    }

    private var filteredApps: [DiscoveredApp] {
        let baseList: [DiscoveredApp]
        if selectedCategory == "ALL" {
            baseList = discoveryService.apps
        } else {
            baseList = discoveryService.apps.filter { $0.category == selectedCategory }
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.isEmpty {
            if isOrganizeMode || !discoveryService.loadSavedOrder().isEmpty {
                return baseList
            }
            if selectedCategory != "ALL" {
                let ranked = baseList.sorted { a1, a2 in
                    let s1 = AppUsageTracker.shared.usageScore(for: a1)
                    let s2 = AppUsageTracker.shared.usageScore(for: a2)
                    if s1 != s2 { return s1 > s2 }
                    return a1.name.localizedCaseInsensitiveCompare(a2.name) == .orderedAscending
                }
                let (arranged, _) = AppUsageTracker.shared.arrangeMiddleOut(ranked)
                return arranged
            }
            return baseList
        }

        // Search Active: Smart search scoring with associative memory and aliases
        let candidates = baseList.filter { app in
            app.name.localizedCaseInsensitiveContains(trimmedSearch) ||
            app.category.localizedCaseInsensitiveContains(trimmedSearch) ||
            AppUsageTracker.shared.searchScore(for: app, query: trimmedSearch) >= 40.0
        }

        let ranked = candidates.sorted { a1, a2 in
            let s1 = AppUsageTracker.shared.searchScore(for: a1, query: trimmedSearch)
            let s2 = AppUsageTracker.shared.searchScore(for: a2, query: trimmedSearch)
            if s1 != s2 { return s1 > s2 }
            return a1.name.localizedCaseInsensitiveCompare(a2.name) == .orderedAscending
        }

        // Matching hidden apps section at the far right behind a separator
        var hiddenMatches = discoveryService.matchingHiddenApps(query: trimmedSearch)
        if selectedCategory != "ALL" {
            hiddenMatches = hiddenMatches.filter { $0.category == selectedCategory }
        }

        if !hiddenMatches.isEmpty {
            var fullList = ranked
            fullList.append(DiscoveredApp.hiddenAppsSeparator)
            fullList.append(contentsOf: hiddenMatches)
            return fullList
        }

        return ranked
    }

    private var categories: [String] {
        var set = Set<String>()
        for app in discoveryService.apps {
            set.insert(app.category)
        }
        var list = Array(set).sorted()
        list.insert("ALL", at: 0)
        return list
    }

    private var activeIndex: Int {
        guard !filteredApps.isEmpty else { return 0 }
        return min(max(0, discoveryService.selectedIndex), filteredApps.count - 1)
    }

    private var currentApp: DiscoveredApp? {
        guard !filteredApps.isEmpty, activeIndex < filteredApps.count else { return nil }
        return filteredApps[activeIndex]
    }

    var body: some View {
        ZStack {
            // Transparent blurred backdrop floating over desktop
            backdropLayer

            // Center Content: CoverFlow Carousel, Curved Wall Grid, or Flat Grid
            VStack {
                Spacer()
                if layoutMode == .coverFlow {
                    CoverFlowCarouselView(
                        apps: filteredApps,
                        activeIndex: activeIndex,
                        isCompact: false,
                        isIconOnly: isIconOnly,
                        onSelect: { index in
                            withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.30, dampingFraction: 0.85))) {
                                discoveryService.selectedIndex = index
                            }
                        },
                        onLaunch: launchSelectedApp,
                        onNavigate: { step in
                            navigate(by: step)
                        }
                    )
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                } else if layoutMode == .gridWall {
                    CoverFlowWallView(
                        apps: filteredApps,
                        activeIndex: activeIndex,
                        isCompact: false,
                        isIconOnly: isIconOnly,
                        isOrganizeMode: isOrganizeMode,
                        onSelect: { index in
                            withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.30, dampingFraction: 0.85))) {
                                discoveryService.selectedIndex = index
                            }
                        },
                        onLaunch: launchSelectedApp,
                        onNavigate: { step in
                            navigate(by: step)
                        },
                        onMoveApp: { from, to in
                            withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.35, dampingFraction: 0.8))) {
                                discoveryService.moveApp(from: from, to: to)
                            }
                        }
                    )
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                } else if layoutMode == .flatGrid {
                    FlatGridView(
                        apps: filteredApps,
                        activeIndex: activeIndex,
                        rowsCount: threeDSGridRows,
                        isCompact: false,
                        isIconOnly: isIconOnly,
                        isOrganizeMode: isOrganizeMode,
                        onSelect: { index in
                            withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.30, dampingFraction: 0.85))) {
                                discoveryService.selectedIndex = index
                            }
                        },
                        onLaunch: launchSelectedApp,
                        onNavigate: { step in
                            navigate(by: step)
                        },
                        onMoveApp: { from, to in
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                discoveryService.moveApp(from: from, to: to)
                            }
                        }
                    )
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
                Spacer()
            }
            .allowsHitTesting(!appState.isShowingSettings && !appState.isShowingWalkthrough)

            // Channel Arranger Deck (Apple Liquid Glass)
            if isOrganizeMode {
                VStack {
                    Spacer()
                    channelArrangerDeck
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .allowsHitTesting(!appState.isShowingSettings && !appState.isShowingWalkthrough)
            }

            // Dynamic App Context Floating Sub-Deck Overlay (Apple Liquid Glass)
            if showRecentDocs, let app = currentApp, !app.isSeparator {
                VStack {
                    Spacer()
                    AppContextSubDeckView(
                        app: app,
                        onClose: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showRecentDocs = false
                            }
                        }
                    )
                    .padding(.bottom, 78)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .allowsHitTesting(!appState.isShowingSettings && !appState.isShowingWalkthrough)
            }

            // Full Screen Liquid Glass HUD
            RetroHUDView(
                searchText: $searchText,
                selectedCategory: $selectedCategory,
                layoutMode: $layoutMode,
                categories: categories,
                totalAppsCount: discoveryService.apps.count,
                selectedApp: currentApp,
                onLaunch: launchSelectedApp,
                onDismiss: onDismiss,
                onPrevious: {
                    switch layoutMode {
                    case .coverFlow: navigate(by: -1)
                    case .gridWall: navigate(by: -3)
                    case .flatGrid: navigate(by: -threeDSGridRows)
                    }
                },
                onNext: {
                    switch layoutMode {
                    case .coverFlow: navigate(by: 1)
                    case .gridWall: navigate(by: 3)
                    case .flatGrid: navigate(by: threeDSGridRows)
                    }
                },
                onNavigateStep: { step in navigate(by: step) },
                onSwitchToQuick: onSwitchToQuickLauncher,
                onOpenSettings: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        appState.isShowingSettings = true
                    }
                },
                onToggleOrganize: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOrganizeMode.toggle()
                    }
                },
                isOrganizeMode: isOrganizeMode,
                onToggleRecentDocuments: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showRecentDocs.toggle()
                    }
                },
                onAddCustomChannel: {
                    isShowingAddChannelSheet = true
                }
            )
            .allowsHitTesting(!appState.isShowingSettings && !appState.isShowingWalkthrough)

            // Settings & Account Modal Sheet
            if appState.isShowingSettings {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            appState.isShowingSettings = false
                        }
                    }

                SettingsModalView(isPresented: $appState.isShowingSettings)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // First-Time Open Walkthrough Modal Sheet
            if appState.isShowingWalkthrough {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Keep focused on walkthrough
                    }

                WalkthroughView(
                    isPresented: $appState.isShowingWalkthrough,
                    onComplete: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            appState.isShowingWalkthrough = false
                        }
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // Real-Time Floating Action Toast
            if let toast = toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.green)
                        Text(toast)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color(white: 0.08).opacity(0.92), in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
                    .padding(.bottom, 82)
                    .transition(.scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .bottom)))
                }
                .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
        .shadow(color: .black.opacity(0.65), radius: 30, x: 0, y: 15)
        .ignoresSafeArea()
        .onChange(of: searchText) { _, newText in
            let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                // When searching, select the best matching app
                if !filteredApps.isEmpty {
                    if filteredApps.first?.isSeparator == true && filteredApps.count > 1 {
                        discoveryService.selectedIndex = 1
                    } else {
                        discoveryService.selectedIndex = 0
                    }
                }
            } else {
                discoveryService.selectedIndex = filteredApps.count / 2
            }
        }
        .onChange(of: selectedCategory) {
            if !searchText.isEmpty {
                discoveryService.selectedIndex = 0
            } else {
                discoveryService.selectedIndex = filteredApps.count / 2
            }
        }
        .onAppear {
            if let mode = MainLayoutViewMode(rawValue: layoutModeRaw) {
                layoutMode = mode
            }
            discoveryService.selectedIndex = filteredApps.count / 2
            setupEventMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidShow)) { notification in
            if let mode = notification.object as? LauncherMode, mode == .fullScreen {
                searchText = ""
                selectedCategory = "ALL"
                discoveryService.selectedIndex = filteredApps.count / 2
                setupEventMonitor()
            } else {
                removeEventMonitor()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("AppsChannelOpenPreferences"))) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                appState.isShowingSettings = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWalkthrough)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                appState.isShowingSettings = false
                appState.isShowingWalkthrough = true
            }
        }
        .onChange(of: appState.isShowingSettings) { _, isShowing in
            if isShowing {
                scrollAccumulator = 0.0
            }
        }
        .onChange(of: appState.isShowingWalkthrough) { _, isShowing in
            if isShowing {
                scrollAccumulator = 0.0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleRecentDocuments)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showRecentDocs.toggle()
            }
        }
        .sheet(isPresented: $isShowingAddChannelSheet) {
            AddCustomChannelSheet()
        }
        .onDisappear {
            removeEventMonitor()
            KeyboardModifierManager.shared.reset()
        }
        .animation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.3, dampingFraction: 0.8)), value: appState.isShowingSettings)
        .animation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.35, dampingFraction: 0.8)), value: appState.isShowingWalkthrough)
        .animation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.3, dampingFraction: 0.8)), value: isOrganizeMode)
        .animation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.35, dampingFraction: 0.8)), value: layoutMode)
        .animation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.3, dampingFraction: 0.8)), value: showRecentDocs)
    }

    // MARK: - Transparent Floating Backdrop with Behind-Window Desktop Blur
    private var backdropLayer: some View {
        ZStack {
            VisualEffectBackground(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Deep obsidian tinted liquid glass layer
            Color(red: 0.04, green: 0.04, blue: 0.05).opacity(0.82)
                .ignoresSafeArea()

            // Theme atmospheric backdrop tint
            Group {
                switch themeManager.currentTheme {
                case .liquidGlass:
                    EmptyView()
                case .matteWhite:
                    Color(white: 0.95).opacity(0.12)
                case .indigoPurple:
                    Color(red: 0.18, green: 0.14, blue: 0.35).opacity(0.42)
                case .cyberpunkDark:
                    Color(red: 0.0, green: 0.06, blue: 0.10).opacity(0.50)
                }
            }
            .ignoresSafeArea()

            // Subtle dark specular top sheen
            LinearGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.clear,
                    Color.black.opacity(0.35)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.white.opacity(0.06),
                    Color.white.opacity(0.01),
                    Color.clear
                ],
                center: .center,
                startRadius: 40,
                endRadius: 500
            )
            .blur(radius: 60)
            .ignoresSafeArea()

            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    if appState.isShowingSettings {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            appState.isShowingSettings = false
                        }
                    }
                }
        }
    }

    // MARK: - Fast Event Interception
    private func setupEventMonitor() {
        guard appState.eventMonitor == nil else { return }
        appState.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown, .flagsChanged]) { event in
            // Only process events when Main App window is visible and key
            guard PanelController.shared.isMainAppVisible,
                  let window = event.window ?? NSApp.keyWindow,
                  !(window is AppsChannelPanel) else {
                return event
            }

            if event.type == .flagsChanged {
                KeyboardModifierManager.shared.update(from: event.modifierFlags)
                return event
            }

            // When Walkthrough modal is active, isolate events and allow keyboard walkthrough navigation:
            if MainAppState.shared.isShowingWalkthrough {
                scrollAccumulator = 0.0
                if event.type == .keyDown {
                    if event.keyCode == 53 { // Escape: Dismiss/Skip
                        SoundEffectsManager.shared.playLaunch()
                        UserDefaults.standard.set(true, forKey: "hasCompletedWalkthrough")
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            MainAppState.shared.isShowingWalkthrough = false
                        }
                        return nil
                    } else if event.keyCode == 123 { // Left Arrow
                        NotificationCenter.default.post(name: .walkthroughPrevious, object: nil)
                        return nil
                    } else if event.keyCode == 124 || event.keyCode == 36 || event.keyCode == 49 { // Right Arrow, Return, Space
                        NotificationCenter.default.post(name: .walkthroughNext, object: nil)
                        return nil
                    }
                }
                return nil
            }

            // When Settings modal is active, isolate events:
            if MainAppState.shared.isShowingSettings {
                scrollAccumulator = 0.0
                if event.type == .scrollWheel {
                    // Let SettingsModalView's ScrollView handle scroll events natively without moving background cards
                    return event
                } else if event.type == .keyDown {
                    // Escape key dismisses settings
                    if event.keyCode == 53 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            MainAppState.shared.isShowingSettings = false
                        }
                        return nil
                    }
                    return event
                }
                return event
            }

            if event.type == .scrollWheel {
                let loc = event.locationInWindow
                if let window = NSApp.keyWindow {
                    let topHUDThreshold = window.frame.height - 140
                    if loc.y > topHUDThreshold {
                        return event
                    }
                }
                handleScrollEvent(event)
                return nil
            } else if event.type == .keyDown {
                // Command+W to close window
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
                    onDismiss()
                    return nil
                }

                // Command+O to switch to Quick Launcher
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "o" {
                    onSwitchToQuickLauncher()
                    return nil
                }

                // Command+Down Arrow: Toggle Context Sub-Deck for current app
                if event.modifierFlags.contains(.command) && event.keyCode == 125 {
                    if let app = currentApp, !app.isSeparator {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showRecentDocs.toggle()
                        }
                    }
                    return nil
                }

                // Command+Up Arrow: Dismiss Recent Documents if open
                if event.modifierFlags.contains(.command) && event.keyCode == 126 {
                    if showRecentDocs {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showRecentDocs = false
                        }
                        return nil
                    }
                }

                // Command+Shift+V or Command+V: View Mode Switch vs. Paste
                if event.modifierFlags.contains(.command) && (event.charactersIgnoringModifiers == "v" || event.charactersIgnoringModifiers == "V") {
                    if event.modifierFlags.contains(.shift) {
                        cycleLayoutMode()
                        return nil
                    }
                    if let responder = event.window?.firstResponder, responder is NSText || responder is NSTextView {
                        return event
                    }
                    if let pasted = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !pasted.isEmpty {
                        searchText.append(pasted)
                        return nil
                    }
                    cycleLayoutMode()
                    return nil
                }

                // Command+Shift+R: Reveal focused application in Finder
                if event.modifierFlags.contains(.command) && (event.charactersIgnoringModifiers == "r" || event.charactersIgnoringModifiers == "R") {
                    if discoveryService.selectedIndex < filteredApps.count {
                        let selectedApp = filteredApps[discoveryService.selectedIndex]
                        if selectedApp.url.isFileURL && !selectedApp.isAppsChannelApp {
                            SoundEffectsManager.shared.playAction()
                            let path = selectedApp.url.path
                            if !NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "") {
                                let task = Process()
                                task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                                task.arguments = ["-R", path]
                                try? task.run()
                            }
                            return nil
                        }
                    }
                }

                // Command+I: Get Info on focused application
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "i" {
                    if discoveryService.selectedIndex < filteredApps.count {
                        let selectedApp = filteredApps[discoveryService.selectedIndex]
                        if selectedApp.url.isFileURL && !selectedApp.isAppsChannelApp {
                            SoundEffectsManager.shared.playAction()
                            let escapedPath = selectedApp.url.path
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
                        return nil
                    }
                }
            }

                // Command + 1..8: Instant Category Group Switch (Customizable in Settings)
                if event.modifierFlags.contains(.command),
                   let chars = event.charactersIgnoringModifiers,
                   let num = Int(chars), num >= 1, num <= 8 {
                    if let targetCategory = ShortcutMappingManager.shared.category(forSlot: num, availableCategories: categories) {
                        SoundEffectsManager.shared.playNavigation()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCategory = targetCategory
                        }
                        return nil
                    }
                }

                // Option + 1..9: Direct Launch Channel Slot 1..9 (Customizable in Settings)
                if event.modifierFlags.contains(.option),
                   let chars = event.charactersIgnoringModifiers,
                   let num = Int(chars), num >= 1, num <= 9 {
                    // Check if a specific app is assigned to this slot
                    if let assigned = ShortcutMappingManager.shared.assignedApp(forSlot: num, in: discoveryService.apps) {
                        SoundEffectsManager.shared.playLaunch()
                        discoveryService.launch(app: assigned, query: searchText)
                        onDismiss()
                        return nil
                    }

                    // Fall back to current grid index
                    let targetIdx = num - 1
                    if targetIdx < filteredApps.count {
                        let targetApp = filteredApps[targetIdx]
                        SoundEffectsManager.shared.playLaunch()
                        discoveryService.launch(app: targetApp, query: searchText)
                        onDismiss()
                        return nil
                    }
                }

                // If in Organize Mode, support Option+Arrow or Bracket keys to rearrange
                if isOrganizeMode {
                    if event.modifierFlags.contains(.option) {
                        switch event.keyCode {
                        case 123: // Left Arrow
                            moveCurrentAppLeft()
                            return nil
                        case 124: // Right Arrow
                            moveCurrentAppRight()
                            return nil
                        case 126: // Up Arrow
                            pinCurrentAppToFront()
                            return nil
                        default:
                            break
                        }
                    }
                    if event.keyCode == 33 { // '['
                        moveCurrentAppLeft()
                        return nil
                    } else if event.keyCode == 30 { // ']'
                        moveCurrentAppRight()
                        return nil
                    }
                }

                switch event.keyCode {
                case 126: // Up Arrow
                    navigate(by: -1)
                    return nil

                case 125: // Down Arrow
                    navigate(by: 1)
                    return nil

                case 123: // Left Arrow
                    if layoutMode == .gridWall {
                        navigate(by: -3)
                    } else if layoutMode == .flatGrid {
                        navigate(by: -threeDSGridRows)
                    } else {
                        navigate(by: -1)
                    }
                    return nil

                case 124: // Right Arrow
                    if layoutMode == .gridWall {
                        navigate(by: 3)
                    } else if layoutMode == .flatGrid {
                        navigate(by: threeDSGridRows)
                    } else {
                        navigate(by: 1)
                    }
                    return nil

                case 36, 76: // Return or Keypad Enter
                    if let app = currentApp {
                        if event.modifierFlags.contains(.command) {
                            revealAppInFinder(app: app)
                            return nil
                        } else if event.modifierFlags.contains(.option) {
                            toggleRecentDocs(app: app)
                            return nil
                        } else if event.modifierFlags.contains(.shift) {
                            copyAppPathOrURL(app: app)
                            return nil
                        }
                    }
                    launchSelectedApp()
                    return nil

                case 53: // Escape
                    if showRecentDocs {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showRecentDocs = false
                        }
                    } else if isOrganizeMode {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isOrganizeMode = false
                        }
                    } else {
                        onDismiss()
                    }
                    return nil

                default:
                    return event
                }
            }
            return event
        }
    }

    private func removeEventMonitor() {
        if let monitor = appState.eventMonitor {
            NSEvent.removeMonitor(monitor)
            appState.eventMonitor = nil
        }
    }

    private func handleScrollEvent(_ event: NSEvent) {
        guard !MainAppState.shared.isShowingSettings else { return }
        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        guard abs(dx) > 0.001 || abs(dy) > 0.001 else { return }

        let dominant = abs(dx) > abs(dy) ? dx : dy
        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 0.35 : 0.75
        let delta = (-dominant) * multiplier

        if (scrollAccumulator > 0 && delta < 0) || (scrollAccumulator < 0 && delta > 0) {
            scrollAccumulator = 0
        }

        scrollAccumulator += delta
        let stepThreshold: CGFloat = 36.0
        let rawSteps = Int(scrollAccumulator / stepThreshold)
        if rawSteps != 0 {
            let clampedStep = max(-1, min(1, rawSteps))
            scrollAccumulator -= CGFloat(clampedStep) * stepThreshold
            let stepMultiplier: Int = {
                switch layoutMode {
                case .coverFlow: return 1
                case .gridWall: return 3
                case .flatGrid: return threeDSGridRows
                }
            }()
            navigate(by: clampedStep * stepMultiplier)
        }
    }

    private func navigate(by step: Int) {
        guard !MainAppState.shared.isShowingSettings else { return }
        guard !filteredApps.isEmpty else { return }
        SoundEffectsManager.shared.playNavigation()
        withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.30, dampingFraction: 0.85))) {
            let nextIndex = min(max(0, activeIndex + step), filteredApps.count - 1)
            discoveryService.selectedIndex = nextIndex
        }
    }

    private func launchSelectedApp() {
        guard let app = currentApp else { return }
        if app.isSeparator {
            navigate(by: 1)
            return
        }
        if modifierManager.isCommandPressed {
            revealAppInFinder(app: app)
            return
        }
        if modifierManager.isOptionPressed {
            toggleRecentDocs(app: app)
            return
        }
        if modifierManager.isShiftPressed {
            copyAppPathOrURL(app: app)
            return
        }

        SoundEffectsManager.shared.playLaunch()
        let query = searchText
        searchText = ""
        discoveryService.launch(app: app, query: query)
        onDismiss()
    }

    private func revealAppInFinder(app: DiscoveredApp) {
        guard !app.isSeparator, app.systemAction == nil, app.url.isFileURL else {
            SoundEffectsManager.shared.playAction()
            return
        }
        SoundEffectsManager.shared.playAction()
        let path = app.url.path
        if !NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "") {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-R", path]
            try? task.run()
        }
        onDismiss()
    }

    private func toggleRecentDocs(app: DiscoveredApp) {
        guard !app.isSeparator else {
            SoundEffectsManager.shared.playAction()
            return
        }
        SoundEffectsManager.shared.playAction()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showRecentDocs.toggle()
        }
    }

    private func copyAppPathOrURL(app: DiscoveredApp) {
        guard !app.isSeparator else { return }
        let textToCopy: String
        if let systemAction = app.systemAction {
            textToCopy = systemAction.title
        } else if app.channelType != nil {
            textToCopy = app.url.absoluteString
        } else {
            textToCopy = app.url.path
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textToCopy, forType: .string)
        SoundEffectsManager.shared.playAction()
        showToast(message: "Copied: \(textToCopy)")
    }

    private func showToast(message: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeOut(duration: 0.2)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }

    private func moveCurrentAppLeft() {
        guard activeIndex > 0 else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            discoveryService.moveAppLeft(at: activeIndex)
        }
    }

    private func moveCurrentAppRight() {
        guard activeIndex < filteredApps.count - 1 else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            discoveryService.moveAppRight(at: activeIndex)
        }
    }

    private func pinCurrentAppToFront() {
        guard activeIndex > 0 else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            discoveryService.pinToFront(at: activeIndex)
        }
    }

    private func cycleLayoutMode() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            switch layoutMode {
            case .coverFlow: layoutMode = .gridWall
            case .gridWall: layoutMode = .flatGrid
            case .flatGrid: layoutMode = .coverFlow
            }
        }
    }

    // MARK: - Liquid Glass Channel Deck
    private var channelArrangerDeck: some View {
        HStack(spacing: 16) {
            // Slot Badge (Channel slot count)
            HStack(spacing: 6) {
                Image(systemName: "square.grid.3x3.square")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.cyan)
                Text("Channel Slot \(activeIndex + 1) of \(filteredApps.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.4), in: Capsule())

            Divider()
                .frame(height: 16)
                .background(Color.white.opacity(0.2))

            // Action Buttons
            HStack(spacing: 8) {
                Button(action: moveCurrentAppLeft) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Move Left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("⌥←")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(activeIndex == 0)
                .opacity(activeIndex == 0 ? 0.4 : 1.0)

                Button(action: moveCurrentAppRight) {
                    HStack(spacing: 4) {
                        Text("Move Right")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                        Text("⌥→")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(activeIndex >= filteredApps.count - 1)
                .opacity(activeIndex >= filteredApps.count - 1 ? 0.4 : 1.0)

                Button(action: pinCurrentAppToFront) {
                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                        Text("Pin to Slot 1")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(activeIndex == 0)
                .opacity(activeIndex == 0 ? 0.4 : 1.0)

                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        discoveryService.resetToUsageOrder()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.cyan)
                        Text("Usage Order")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        discoveryService.resetToAlphabetical()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 10))
                        Text("Reset A-Z")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isOrganizeMode = false
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("Done")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.cyan, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.cyan.opacity(0.6), .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .cyan.opacity(0.2), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 40)
        .padding(.bottom, 80)
    }
}
