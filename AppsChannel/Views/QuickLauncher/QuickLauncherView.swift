import SwiftUI
import AppKit
import Combine

// MARK: - Quick Launcher State & Controller
@MainActor
final class QuickLauncherState: ObservableObject {
    static let shared = QuickLauncherState()

    @Published var selectedIndex: Int = 0
    @Published var searchText: String = ""
    @Published var isSearchTextSelected: Bool = false
    @Published var selectedCategory: String = "ALL"
    @Published var cachedFilteredApps: [DiscoveredApp] = []
    @Published var toastMessage: String? = nil

    var scrollAccumulator: CGFloat = 0.0
    var eventMonitor: Any? = nil

    init() {
        updateFilteredApps()
    }

    func reset() {
        searchText = ""
        isSearchTextSelected = false
        selectedCategory = "ALL"
        scrollAccumulator = 0.0
        updateFilteredApps()
        selectedIndex = cachedFilteredApps.count / 2
    }

    func updateFilteredApps() {
        let discoveryService = AppDiscoveryService.shared
        let baseList: [DiscoveredApp]
        if selectedCategory == "ALL" {
            baseList = discoveryService.apps
        } else {
            baseList = discoveryService.apps.filter { $0.category == selectedCategory }
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.isEmpty {
            if !discoveryService.loadSavedOrder().isEmpty {
                cachedFilteredApps = baseList
                return
            }
            if selectedCategory != "ALL" {
                let scored = baseList.map { (app: $0, score: AppUsageTracker.shared.usageScore(for: $0)) }
                let ranked = scored.sorted { s1, s2 in
                    if s1.score != s2.score { return s1.score > s2.score }
                    return s1.app.name.localizedCaseInsensitiveCompare(s2.app.name) == .orderedAscending
                }.map(\.app)
                let (arranged, _) = AppUsageTracker.shared.arrangeMiddleOut(ranked)
                cachedFilteredApps = arranged
                return
            }
            cachedFilteredApps = baseList
            return
        }

        // High-performance single-pass precomputed scoring (O(N) scoring instead of O(N log N))
        let scoredCandidates: [(app: DiscoveredApp, score: Double)] = baseList.compactMap { app in
            let score = AppUsageTracker.shared.searchScore(for: app, query: trimmedSearch)
            let matchesName = app.name.localizedCaseInsensitiveContains(trimmedSearch)
            let matchesCategory = app.category.localizedCaseInsensitiveContains(trimmedSearch)
            if matchesName || matchesCategory || score >= 40.0 {
                return (app, score)
            }
            return nil
        }

        let ranked = scoredCandidates.sorted { s1, s2 in
            if s1.score != s2.score { return s1.score > s2.score }
            return s1.app.name.localizedCaseInsensitiveCompare(s2.app.name) == .orderedAscending
        }.map(\.app)

        // Matching hidden apps section at the far right behind a separator
        var hiddenMatches = discoveryService.matchingHiddenApps(query: trimmedSearch)
        if selectedCategory != "ALL" {
            hiddenMatches = hiddenMatches.filter { $0.category == selectedCategory }
        }

        var fullList = ranked
        if !hiddenMatches.isEmpty {
            fullList.append(DiscoveredApp.hiddenAppsSeparator)
            fullList.append(contentsOf: hiddenMatches)
        }

        // When searching, include "Open AppsChannel" if the search query matches
        if QuickLauncherView.openMainAppCard.name.localizedCaseInsensitiveContains(trimmedSearch) ||
           "AppsChannel".localizedCaseInsensitiveContains(trimmedSearch) ||
           "Settings".localizedCaseInsensitiveContains(trimmedSearch) {
            fullList.append(QuickLauncherView.openMainAppCard)
        }

        cachedFilteredApps = fullList
    }

    func showToast(message: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                if self.toastMessage == message {
                    self.toastMessage = nil
                }
            }
        }
    }
}

struct QuickLauncherView: View {
    @ObservedObject private var discoveryService = AppDiscoveryService.shared
    @ObservedObject private var state = QuickLauncherState.shared
    @ObservedObject private var modifierManager = KeyboardModifierManager.shared

    let onExpandToFullScreen: () -> Void
    var onSwitchToClassic: (() -> Void)? = nil
    let onDismiss: () -> Void

    @AppStorage("mainLayoutMode") private var layoutModeRaw: String = MainLayoutViewMode.gridWall.rawValue
    @AppStorage("appDisplayStyle") private var appDisplayStyleRaw: String = AppDisplayStyle.iconOnly.rawValue
    @AppStorage("threeDSGridRows") private var threeDSGridRows: Int = 3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var layoutMode: MainLayoutViewMode {
        MainLayoutViewMode(rawValue: layoutModeRaw) ?? .coverFlow
    }

    private var appDisplayStyle: AppDisplayStyle {
        AppDisplayStyle(rawValue: appDisplayStyleRaw) ?? .iconOnly
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

    static let openMainAppCard: DiscoveredApp = {
        let size = NSSize(width: 128, height: 128)
        let img = NSImage(size: size, flipped: false) { rect in
            let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .bold)
            if let symbol = NSImage(systemSymbolName: "macwindow.and.cursorarrow", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let tinted = symbol.copy() as! NSImage
                let drawRect = NSRect(x: 16, y: 16, width: 96, height: 96)
                tinted.draw(in: drawRect)
                return true
            }
            return false
        }
        return DiscoveredApp(
            id: UUID(),
            name: "Open AppsChannel",
            url: URL(fileURLWithPath: "/Applications/AppsChannel.app/OpenMainWindow"),
            bundleIdentifier: "com.micahcrandell.AppsChannel.openMainWindow",
            icon: img,
            category: "WINDOW",
            tagBadge: "MAIN APP",
            sizeString: "⌘O",
            accentColor: .white
        )
    }()

    private var displayApps: [DiscoveredApp] {
        state.cachedFilteredApps
    }

    private var activeIndex: Int {
        guard !displayApps.isEmpty else { return 0 }
        return min(max(0, state.selectedIndex), displayApps.count - 1)
    }

    private var currentApp: DiscoveredApp? {
        guard !displayApps.isEmpty, activeIndex < displayApps.count else { return nil }
        return displayApps[activeIndex]
    }

    var body: some View {
        ZStack {
            // Soft feathered backdrop blur
            VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)
                .frame(width: 1100, height: backdropHeight)
                .mask(
                    EllipticalGradient(
                        stops: [
                            .init(color: .white.opacity(0.90), location: 0.0),
                            .init(color: .white.opacity(0.65), location: 0.35),
                            .init(color: .white.opacity(0.20), location: 0.70),
                            .init(color: .clear, location: 1.0)
                        ],
                        center: .center
                    )
                )
                .allowsHitTesting(false)

            // Ultra-subtle monochrome white glass ambient glow
            EllipticalGradient(
                stops: [
                    .init(color: Color.white.opacity(0.08), location: 0.0),
                    .init(color: Color.white.opacity(0.03), location: 0.40),
                    .init(color: .clear, location: 0.80)
                ],
                center: .center
            )
            .frame(width: 520, height: layoutMode == .coverFlow ? 320 : 400)
            .allowsHitTesting(false)

            // Middle Content: Stationary CoverFlow, Wall, or Flat Grid (never shifts when typing)
            Group {
                if layoutMode == .coverFlow {
                    CoverFlowCarouselView(
                        apps: displayApps,
                        activeIndex: activeIndex,
                        isCompact: true,
                        isIconOnly: appDisplayStyle == .iconOnly,
                        onSelect: { index in
                            withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.30, dampingFraction: 0.85))) {
                                state.selectedIndex = index
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
                        apps: displayApps,
                        activeIndex: activeIndex,
                        isCompact: true,
                        isIconOnly: appDisplayStyle == .iconOnly,
                        isOrganizeMode: false,
                        onSelect: { index in
                            withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.30, dampingFraction: 0.85))) {
                                state.selectedIndex = index
                                discoveryService.selectedIndex = index
                            }
                        },
                        onLaunch: launchSelectedApp,
                        onNavigate: { step in
                            navigate(by: step)
                        }
                    )
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                } else {
                    FlatGridView(
                        apps: displayApps,
                        activeIndex: activeIndex,
                        rowsCount: threeDSGridRows,
                        isCompact: true,
                        isIconOnly: appDisplayStyle == .iconOnly,
                        isOrganizeMode: false,
                        onSelect: { index in
                            withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.30, dampingFraction: 0.85))) {
                                state.selectedIndex = index
                                discoveryService.selectedIndex = index
                            }
                        },
                        onLaunch: launchSelectedApp,
                        onNavigate: { step in
                            navigate(by: step)
                        }
                    )
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }

            // Floating Search & Category Input Bar (hidden until user starts typing or filters category)
            if !state.searchText.isEmpty || state.selectedCategory != "ALL" {
                searchStatusBadge
                    .offset(y: searchBadgeOffsetY)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
                    .zIndex(100)
            }

            // Toast Overlay (positioned cleanly below carousel)
            if let toast = state.toastMessage {
                toastView(message: toast)
                    .offset(y: toastOffsetY)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(101)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: discoveryService.apps.count) { _, _ in
            state.updateFilteredApps()
            if state.selectedIndex >= displayApps.count || state.selectedIndex == 0 {
                let center = max(0, displayApps.count / 2)
                state.selectedIndex = center
            }
        }
        .onAppear {
            state.reset()
            KeyboardModifierManager.shared.reset()
            setupEventMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidShow)) { notification in
            if let mode = notification.object as? LauncherMode {
                if mode == .quickLauncher {
                    state.reset()
                    KeyboardModifierManager.shared.reset()
                    setupEventMonitor()
                } else {
                    removeEventMonitor()
                }
            } else {
                state.reset()
                KeyboardModifierManager.shared.reset()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickLauncherDidDismiss)) { _ in
            state.reset()
            removeEventMonitor()
            KeyboardModifierManager.shared.reset()
        }
        .onDisappear {
            state.reset()
            removeEventMonitor()
            KeyboardModifierManager.shared.reset()
        }
        .animation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.28, dampingFraction: 0.8)), value: state.searchText.isEmpty)
        .animation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.28, dampingFraction: 0.8)), value: state.isSearchTextSelected)
        .animation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.35, dampingFraction: 0.8)), value: layoutMode)
    }

    // MARK: - Direct Key & Scroll Handling
    private func setupEventMonitor() {
        if let existing = state.eventMonitor {
            NSEvent.removeMonitor(existing)
            state.eventMonitor = nil
        }
        state.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown, .flagsChanged]) { event in
            // Only process events when QuickLauncher is visible
            guard PanelController.shared.isQuickLauncherVisible else {
                return event
            }

            if event.type == .flagsChanged {
                KeyboardModifierManager.shared.update(from: event.modifierFlags)
                return event
            }

            let s = QuickLauncherState.shared

            if event.type == .scrollWheel {
                handleScrollEvent(event)
                return nil
            } else if event.type == .keyDown {
                KeyboardModifierManager.shared.update(from: event.modifierFlags)
                let isCmd = event.modifierFlags.contains(.command)
                let isShift = event.modifierFlags.contains(.shift)

                // Command + Shift + Q: Explicit full quit
                if isCmd && isShift && (event.keyCode == 12 || event.charactersIgnoringModifiers?.lowercased() == "q") {
                    AppDelegate.quitCompletely()
                    return nil
                }

                // Command + Q: Dismiss launcher if keepRunningInBackgroundOnQuit is enabled
                if isCmd && !isShift && (event.keyCode == 12 || event.charactersIgnoringModifiers?.lowercased() == "q") {
                    let keepAlive = UserDefaults.standard.object(forKey: "keepRunningInBackgroundOnQuit") as? Bool ?? true
                    if keepAlive {
                        SoundEffectsManager.shared.playAction()
                        onDismiss()
                        return nil
                    }
                }

                // Command+O to expand to full screen
                if isCmd && (event.keyCode == 31 || event.charactersIgnoringModifiers?.lowercased() == "o") {
                    onExpandToFullScreen()
                    return nil
                }

                // Command+L to switch to Classic Launcher
                if isCmd && (event.keyCode == 37 || event.charactersIgnoringModifiers?.lowercased() == "l") {
                    if let onSwitch = onSwitchToClassic {
                        SoundEffectsManager.shared.playAction()
                        onSwitch()
                        return nil
                    }
                }

                // Command+A: Select all search text
                if isCmd && (event.keyCode == 0 || event.charactersIgnoringModifiers?.lowercased() == "a") {
                    if !s.searchText.isEmpty {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            s.isSearchTextSelected = true
                        }
                        SoundEffectsManager.shared.playAction()
                        return nil
                    }
                }

                // Command+C: Copy search text to clipboard
                if isCmd && (event.keyCode == 8 || event.charactersIgnoringModifiers?.lowercased() == "c") {
                    if !s.searchText.isEmpty {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(s.searchText, forType: .string)
                        SoundEffectsManager.shared.playAction()
                        return nil
                    }
                }

                // Command+X: Cut search text to clipboard
                if isCmd && (event.keyCode == 7 || event.charactersIgnoringModifiers?.lowercased() == "x") {
                    if !s.searchText.isEmpty {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(s.searchText, forType: .string)
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            s.searchText = ""
                            s.isSearchTextSelected = false
                            s.updateFilteredApps()
                            let center = s.cachedFilteredApps.count / 2
                            s.selectedIndex = center
                        }
                        SoundEffectsManager.shared.playAction()
                        return nil
                    }
                }

                // Check Delete / Backspace keys (ANSI 51, Forward Delete 117, ASCII 127/8, NSDeleteFunctionKey, SpecialKeys)
                let isDeleteKey = (event.keyCode == 51 || event.keyCode == 117 || event.specialKey == .delete || event.specialKey == .deleteForward)
                let isDeleteChar = (event.characters == "\u{7f}" || event.characters == "\u{08}" || event.charactersIgnoringModifiers == "\u{7f}" || event.charactersIgnoringModifiers == "\u{08}" || event.characters == "\u{f728}" || event.charactersIgnoringModifiers == "\u{f728}")

                if isDeleteKey || isDeleteChar {
                    if isCmd {
                        if !s.searchText.isEmpty {
                            s.searchText = ""
                            s.isSearchTextSelected = false
                            s.updateFilteredApps()
                            withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.22, dampingFraction: 0.85))) {
                                let center = s.cachedFilteredApps.count / 2
                                s.selectedIndex = center
                            }
                            SoundEffectsManager.shared.playAction()
                        }
                        return nil
                    }

                    let isOption = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option)
                    if isOption {
                        if !s.searchText.isEmpty {
                            var text = s.searchText
                            while text.hasSuffix(" ") {
                                text.removeLast()
                            }
                            if let lastSpaceIndex = text.lastIndex(of: " ") {
                                s.searchText = String(text[..<lastSpaceIndex])
                            } else {
                                s.searchText = ""
                            }
                            s.isSearchTextSelected = false
                            s.updateFilteredApps()
                            withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.22, dampingFraction: 0.85))) {
                                let center = s.cachedFilteredApps.count / 2
                                s.selectedIndex = center
                            }
                            SoundEffectsManager.shared.playNavigation()
                        }
                        return nil
                    }

                    if s.isSearchTextSelected {
                        s.searchText = ""
                        s.isSearchTextSelected = false
                        s.updateFilteredApps()
                        withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.22, dampingFraction: 0.85))) {
                            let center = s.cachedFilteredApps.count / 2
                            s.selectedIndex = center
                        }
                        SoundEffectsManager.shared.playAction()
                        return nil
                    } else if !s.searchText.isEmpty {
                        s.searchText = String(s.searchText.dropLast())
                        s.updateFilteredApps()
                        withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.22, dampingFraction: 0.85))) {
                            let trimmed = s.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                let center = s.cachedFilteredApps.count / 2
                                s.selectedIndex = center
                            } else {
                                let target = (s.cachedFilteredApps.first?.isSeparator == true && s.cachedFilteredApps.count > 1) ? 1 : 0
                                s.selectedIndex = min(target, max(0, s.cachedFilteredApps.count - 1))
                            }
                        }
                        SoundEffectsManager.shared.playNavigation()
                        return nil
                    }
                    return nil
                }

                // Command+Shift+V: View Layout Mode Switch
                if event.modifierFlags.contains(.command) && event.modifierFlags.contains(.shift) && (event.keyCode == 9 || event.charactersIgnoringModifiers?.lowercased() == "v") {
                    cycleLayoutMode()
                    return nil
                }

                // Command+V: Paste clipboard text into search input (strictly paste, never cycle)
                if event.modifierFlags.contains(.command) && !event.modifierFlags.contains(.shift) && (event.keyCode == 9 || event.charactersIgnoringModifiers?.lowercased() == "v") {
                    if let pasted = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !pasted.isEmpty {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            if s.isSearchTextSelected {
                                s.searchText = pasted
                                s.isSearchTextSelected = false
                            } else {
                                s.searchText.append(pasted)
                            }
                            s.updateFilteredApps()
                            let target = (s.cachedFilteredApps.first?.isSeparator == true && s.cachedFilteredApps.count > 1) ? 1 : 0
                            s.selectedIndex = min(target, max(0, s.cachedFilteredApps.count - 1))
                        }
                        SoundEffectsManager.shared.playAction()
                        return nil
                    }
                    return nil
                }

                // Command+Shift+R: Reveal selected app in Finder
                if event.modifierFlags.contains(.command) && (event.keyCode == 15 || event.charactersIgnoringModifiers?.lowercased() == "r") {
                    if let selectedApp = currentApp, selectedApp.url.isFileURL, !selectedApp.isAppsChannelApp {
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

                // Command+I: Get Info on focused application
                if event.modifierFlags.contains(.command) && (event.keyCode == 34 || event.charactersIgnoringModifiers?.lowercased() == "i") {
                    if let selectedApp = currentApp, selectedApp.url.isFileURL, !selectedApp.isAppsChannelApp {
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

                // Command + 1..8: Category Group Filtering (Customizable in Settings)
                if event.modifierFlags.contains(.command),
                   let chars = event.charactersIgnoringModifiers,
                   let num = Int(chars), num >= 1, num <= 8 {
                    if let targetCategory = ShortcutMappingManager.shared.category(forSlot: num, availableCategories: categories) {
                        SoundEffectsManager.shared.playNavigation()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            s.selectedCategory = targetCategory
                            s.updateFilteredApps()
                            let center = s.cachedFilteredApps.count / 2
                            s.selectedIndex = center
                        }
                        return nil
                    }
                }

                // Option + 1..9: Direct Launch of Channel Slot 1..9 (Customizable in Settings)
                if event.modifierFlags.contains(.option),
                   let chars = event.charactersIgnoringModifiers,
                   let num = Int(chars), num >= 1, num <= 9 {
                    // Check if a specific app is assigned to this slot
                    if let assigned = ShortcutMappingManager.shared.assignedApp(forSlot: num, in: discoveryService.apps) {
                        let query = s.searchText
                        s.reset()
                        SoundEffectsManager.shared.playLaunch()
                        discoveryService.launch(app: assigned, query: query)
                        onDismiss()
                        return nil
                    }

                    // Fall back to current grid index
                    let targetIdx = num - 1
                    if targetIdx < displayApps.count {
                        let app = displayApps[targetIdx]
                        if app.url.path == Self.openMainAppCard.url.path {
                            s.reset()
                            onExpandToFullScreen()
                            return nil
                        }
                        let query = s.searchText
                        s.reset()
                        SoundEffectsManager.shared.playLaunch()
                        discoveryService.launch(app: app, query: query)
                        onDismiss()
                        return nil
                    }
                }

                switch event.keyCode {
                case 126: // Up Arrow
                    if s.isSearchTextSelected { s.isSearchTextSelected = false }
                    navigate(by: -1)
                    return nil

                case 125: // Down Arrow
                    if s.isSearchTextSelected { s.isSearchTextSelected = false }
                    navigate(by: 1)
                    return nil

                case 123: // Left Arrow
                    if s.isSearchTextSelected { s.isSearchTextSelected = false }
                    if layoutMode == .gridWall {
                        navigate(by: -3)
                    } else if layoutMode == .flatGrid {
                        navigate(by: -threeDSGridRows)
                    } else {
                        navigate(by: -1)
                    }
                    return nil

                case 124: // Right Arrow
                    if s.isSearchTextSelected { s.isSearchTextSelected = false }
                    if layoutMode == .gridWall {
                        navigate(by: 3)
                    } else if layoutMode == .flatGrid {
                        navigate(by: threeDSGridRows)
                    } else {
                        navigate(by: 1)
                    }
                    return nil

                case 36, 76: // Return key or Keypad Enter
                    if s.isSearchTextSelected { s.isSearchTextSelected = false }
                    if let app = currentApp {
                        if event.modifierFlags.contains(.command) {
                            revealAppInFinder(app: app)
                            return nil
                        } else if event.modifierFlags.contains(.shift) {
                            copyAppPathOrURL(app: app)
                            return nil
                        }
                    }
                    launchSelectedApp()
                    return nil

                case 53: // Escape key
                    if s.isSearchTextSelected {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            s.isSearchTextSelected = false
                        }
                    } else if !s.searchText.isEmpty {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            s.searchText = ""
                            s.updateFilteredApps()
                            let center = s.cachedFilteredApps.count / 2
                            s.selectedIndex = center
                        }
                        SoundEffectsManager.shared.playAction()
                    } else if s.selectedCategory != "ALL" {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            s.selectedCategory = "ALL"
                            s.updateFilteredApps()
                            let center = s.cachedFilteredApps.count / 2
                            s.selectedIndex = center
                        }
                        SoundEffectsManager.shared.playAction()
                    } else {
                        onDismiss()
                    }
                    return nil

                default:
                    // Check if it's Return / Enter character on keyboards with non-standard keyCodes
                    if event.characters == "\r" || event.characters == "\n" || event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "\n" {
                        if s.isSearchTextSelected { s.isSearchTextSelected = false }
                        if let app = currentApp {
                            if event.modifierFlags.contains(.command) {
                                revealAppInFinder(app: app)
                                return nil
                            } else if event.modifierFlags.contains(.shift) {
                                copyAppPathOrURL(app: app)
                                return nil
                            }
                        }
                        launchSelectedApp()
                        return nil
                    }

                    // Check if it's a printable character key to search
                    if let characters = event.characters,
                       !characters.isEmpty,
                       characters != "\r",
                       characters != "\n",
                       !event.modifierFlags.contains(.command),
                       !event.modifierFlags.contains(.control),
                       !event.modifierFlags.contains(.option) {
                        let allowed = CharacterSet.alphanumerics.union(.punctuationCharacters).union(.whitespaces)
                        if characters.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
                            if s.isSearchTextSelected {
                                s.searchText = characters
                                s.isSearchTextSelected = false
                            } else {
                                s.searchText.append(characters)
                            }
                            s.updateFilteredApps()
                            withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.22, dampingFraction: 0.85))) {
                                let target = (s.cachedFilteredApps.first?.isSeparator == true && s.cachedFilteredApps.count > 1) ? 1 : 0
                                s.selectedIndex = min(target, max(0, s.cachedFilteredApps.count - 1))
                            }
                            SoundEffectsManager.shared.playNavigation()
                            return nil
                        }
                    }
                    return event
                }
            }
            return event
        }
    }

    private func removeEventMonitor() {
        if let monitor = state.eventMonitor {
            NSEvent.removeMonitor(monitor)
            state.eventMonitor = nil
        }
        KeyboardModifierManager.shared.reset()
    }

    private func handleScrollEvent(_ event: NSEvent) {
        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        guard abs(dx) > 0.001 || abs(dy) > 0.001 else { return }

        let dominant = abs(dx) > abs(dy) ? dx : dy
        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 0.35 : 0.75
        let delta = (-dominant) * multiplier

        if (state.scrollAccumulator > 0 && delta < 0) || (state.scrollAccumulator < 0 && delta > 0) {
            state.scrollAccumulator = 0
        }

        state.scrollAccumulator += delta
        let stepThreshold: CGFloat = 36.0
        let rawSteps = Int(state.scrollAccumulator / stepThreshold)
        if rawSteps != 0 {
            let clampedStep = max(-1, min(1, rawSteps))
            state.scrollAccumulator -= CGFloat(clampedStep) * stepThreshold
            let stepMultiplier: Int = {
                switch layoutMode {
                case .coverFlow: return 1
                case .gridWall: return 3
                case .flatGrid: return threeDSGridRows
                case .wiiChannels: return 1
                }
            }()
            navigate(by: clampedStep * stepMultiplier)
        }
    }

    private func cycleLayoutMode() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            let nextMode: MainLayoutViewMode
            switch layoutMode {
            case .coverFlow: nextMode = .gridWall
            case .gridWall: nextMode = .flatGrid
            case .flatGrid: nextMode = .wiiChannels
            case .wiiChannels: nextMode = .coverFlow
            }
            layoutModeRaw = nextMode.rawValue
        }
    }

    private func navigate(by step: Int) {
        guard !displayApps.isEmpty else { return }
        SoundEffectsManager.shared.playNavigation()
        withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.30, dampingFraction: 0.85))) {
            let nextIndex = min(max(0, activeIndex + step), displayApps.count - 1)
            state.selectedIndex = nextIndex
            discoveryService.selectedIndex = nextIndex
        }
    }

    private func launchSelectedApp() {
        guard let app = currentApp else { return }
        if app.isSeparator {
            navigate(by: 1)
            return
        }
        if app.url.path == Self.openMainAppCard.url.path {
            SoundEffectsManager.shared.playAction()
            state.reset()
            onExpandToFullScreen()
            return
        }

        if modifierManager.isCommandPressed {
            revealAppInFinder(app: app)
            return
        }
        if modifierManager.isShiftPressed {
            copyAppPathOrURL(app: app)
            return
        }

        let query = state.searchText
        state.reset()
        onDismiss()
        SoundEffectsManager.shared.playLaunch()
        if app.systemAction == .clipboardHistory {
            PanelController.shared.showClipboardHistory()
            return
        }
        discoveryService.launch(app: app, query: query)
    }

    private func revealAppInFinder(app: DiscoveredApp) {
        guard !app.isSeparator, app.systemAction == nil, app.url.isFileURL, app.url.path != Self.openMainAppCard.url.path else {
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

    private func copyAppPathOrURL(app: DiscoveredApp) {
        guard !app.isSeparator, app.url.path != Self.openMainAppCard.url.path else { return }
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
        state.showToast(message: "Copied: \(textToCopy)")
    }

    // MARK: - Floating Search & Category Status Badge
    private var searchStatusBadge: some View {
        HStack(spacing: 8) {
            if state.selectedCategory != "ALL" {
                HStack(spacing: 5) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(state.selectedCategory)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.18), in: Capsule())
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )

                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        state.selectedCategory = "ALL"
                        state.updateFilteredApps()
                        let center = state.cachedFilteredApps.count / 2
                        state.selectedIndex = center
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            if !state.searchText.isEmpty {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(state.isSearchTextSelected ? .white : .white.opacity(0.85))

                    Text(verbatim: state.searchText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, state.isSearchTextSelected ? 5 : 0)
                        .padding(.vertical, state.isSearchTextSelected ? 2 : 0)
                        .background(
                            state.isSearchTextSelected
                                ? RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.accentColor.opacity(0.9))
                                : nil
                        )

                    Button(action: {
                        state.searchText = ""
                        state.isSearchTextSelected = false
                        state.updateFilteredApps()
                        withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.22, dampingFraction: 0.85))) {
                            let center = state.cachedFilteredApps.count / 2
                            state.selectedIndex = center
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(state.isSearchTextSelected ? .white.opacity(0.9) : .white.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        state.isSearchTextSelected.toggle()
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Color(white: 0.08).opacity(state.isSearchTextSelected ? 0.95 : 0.9),
            in: Capsule()
        )
        .overlay(
            Capsule().strokeBorder(
                state.isSearchTextSelected ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.24),
                lineWidth: state.isSearchTextSelected ? 1.5 : 1
            )
        )
        .shadow(
            color: state.isSearchTextSelected ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.4),
            radius: state.isSearchTextSelected ? 14 : 12,
            x: 0,
            y: 6
        )
    }

    // MARK: - Toast View
    private func toastView(message: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.green)
            Text(message)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(white: 0.08).opacity(0.92), in: Capsule())
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
    }

    // MARK: - Layout Helpers
    private var backdropHeight: CGFloat {
        switch layoutMode {
        case .coverFlow: return 480
        case .gridWall, .flatGrid, .wiiChannels: return 560
        }
    }

    private var searchBadgeOffsetY: CGFloat {
        switch layoutMode {
        case .coverFlow:
            return appDisplayStyle == .iconOnly ? -125 : -155
        case .gridWall, .flatGrid, .wiiChannels:
            return -245
        }
    }

    private var toastOffsetY: CGFloat {
        switch layoutMode {
        case .coverFlow:
            return appDisplayStyle == .iconOnly ? 155 : 200
        case .gridWall, .flatGrid, .wiiChannels:
            return 235
        }
    }
}
