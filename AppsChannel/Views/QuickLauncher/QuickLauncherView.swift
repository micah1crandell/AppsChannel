import SwiftUI
import AppKit

struct QuickLauncherView: View {
    @ObservedObject private var discoveryService = AppDiscoveryService.shared
    @State private var selectedIndex: Int = 0
    @State private var searchText: String = ""
    @State private var scrollAccumulator: CGFloat = 0.0
    @State private var eventMonitor: Any? = nil
    @State private var toastMessage: String? = nil
    @ObservedObject private var subDeckService = AppContextSubDeckService.shared
    @ObservedObject private var modifierManager = KeyboardModifierManager.shared

    let onExpandToFullScreen: () -> Void
    let onDismiss: () -> Void

    @AppStorage("mainLayoutMode") private var layoutModeRaw: String = MainLayoutViewMode.gridWall.rawValue
    @AppStorage("appDisplayStyle") private var appDisplayStyleRaw: String = AppDisplayStyle.iconOnly.rawValue
    @AppStorage("threeDSGridRows") private var threeDSGridRows: Int = 3
    @State private var selectedCategory: String = "ALL"
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

    private var filteredApps: [DiscoveredApp] {
        let baseList: [DiscoveredApp]
        if selectedCategory == "ALL" {
            baseList = discoveryService.apps
        } else {
            baseList = discoveryService.apps.filter { $0.category == selectedCategory }
        }

        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSearch.isEmpty {
            if !discoveryService.loadSavedOrder().isEmpty {
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

        // Smart search scoring with associative memory and aliases
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

    private static let openMainAppCard: DiscoveredApp = {
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
        var list = filteredApps
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearch.isEmpty {
            // When searching, include "Open AppsChannel" if the search query matches
            if Self.openMainAppCard.name.localizedCaseInsensitiveContains(trimmedSearch) ||
               "AppsChannel".localizedCaseInsensitiveContains(trimmedSearch) ||
               "Settings".localizedCaseInsensitiveContains(trimmedSearch) {
                list.append(Self.openMainAppCard)
            }
        }
        return list
    }

    private var activeIndex: Int {
        guard !displayApps.isEmpty else { return 0 }
        return min(max(0, selectedIndex), displayApps.count - 1)
    }

    private var currentApp: DiscoveredApp? {
        guard !displayApps.isEmpty, activeIndex < displayApps.count else { return nil }
        return displayApps[activeIndex]
    }

    var body: some View {
        ZStack {
            // Soft feathered backdrop blur that smoothly expands downwards when subdeck opens
            VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)
                .frame(width: 1100, height: subDeckService.isSubDeckVisible ? 740 : 480)
                .offset(y: subDeckService.isSubDeckVisible ? 120 : 0)
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
            .frame(width: 520, height: 320)
            .allowsHitTesting(false)

            // Middle Content: Stationary CoverFlow, Wall, or Flat Grid (never shifts when typing or opening sub-deck)
            Group {
                if layoutMode == .coverFlow {
                    CoverFlowCarouselView(
                        apps: displayApps,
                        activeIndex: activeIndex,
                        isCompact: true,
                        isIconOnly: appDisplayStyle == .iconOnly,
                        onSelect: { index in
                            withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.30, dampingFraction: 0.85))) {
                                selectedIndex = index
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
                                selectedIndex = index
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
                                selectedIndex = index
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

            // Sub-Deck Content: Positioned snug directly below the carousel tiles and reflection
            if subDeckService.isSubDeckVisible, let app = currentApp, !app.isSeparator {
                AppContextSubDeckView(
                    app: app,
                    focusedLocation: subDeckService.focusedLocation,
                    onClose: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            subDeckService.closeSubDeck()
                        }
                    },
                    onActionExecuted: {
                        subDeckService.closeSubDeck()
                        onDismiss()
                    }
                )
                .offset(y: 260)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Top Floating Search & Category Status Badge (floats above carousel without moving it)
            VStack {
                if !searchText.isEmpty || selectedCategory != "ALL" {
                    searchStatusBadge
                        .transition(.scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)))
                }
                Spacer()

                // Toast Overlay
                if let toast = toastMessage {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.green)
                        Text(toast)
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
                    .transition(.scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: searchText) { _, newText in
            let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let target = (displayApps.first?.isSeparator == true && displayApps.count > 1) ? 1 : 0
                selectedIndex = target
                discoveryService.selectedIndex = target
            } else {
                let center = displayApps.count / 2
                selectedIndex = center
                discoveryService.selectedIndex = center
            }
        }
        .onChange(of: selectedCategory) {
            if !searchText.isEmpty {
                selectedIndex = 0
                discoveryService.selectedIndex = 0
            } else {
                let center = displayApps.count / 2
                selectedIndex = center
                discoveryService.selectedIndex = center
            }
        }
        .onChange(of: discoveryService.apps.count) {
            if selectedIndex >= displayApps.count {
                let center = displayApps.count / 2
                selectedIndex = center
                discoveryService.selectedIndex = center
            }
        }
        .onAppear {
            searchText = ""
            selectedCategory = "ALL"
            scrollAccumulator = 0.0
            subDeckService.isSubDeckVisible = false
            subDeckService.focusedLocation = nil
            let center = displayApps.count / 2
            selectedIndex = center
            discoveryService.selectedIndex = center
            setupEventMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidShow)) { notification in
            if let mode = notification.object as? LauncherMode {
                if mode == .quickLauncher {
                    searchText = ""
                    selectedCategory = "ALL"
                    scrollAccumulator = 0.0
                    subDeckService.isSubDeckVisible = false
                    subDeckService.focusedLocation = nil
                    let center = displayApps.count / 2
                    selectedIndex = center
                    discoveryService.selectedIndex = center
                    setupEventMonitor()
                } else {
                    removeEventMonitor()
                }
            } else {
                searchText = ""
                selectedCategory = "ALL"
                scrollAccumulator = 0.0
                subDeckService.isSubDeckVisible = false
                subDeckService.focusedLocation = nil
                let center = displayApps.count / 2
                selectedIndex = center
                discoveryService.selectedIndex = center
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickLauncherDidDismiss)) { _ in
            searchText = ""
            selectedCategory = "ALL"
            scrollAccumulator = 0.0
            subDeckService.isSubDeckVisible = false
            subDeckService.focusedLocation = nil
            let center = discoveryService.apps.count / 2
            selectedIndex = center
            discoveryService.selectedIndex = center
            removeEventMonitor()
        }
        .onDisappear {
            searchText = ""
            subDeckService.isSubDeckVisible = false
            subDeckService.focusedLocation = nil
            removeEventMonitor()
            KeyboardModifierManager.shared.reset()
        }
        .animation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.28, dampingFraction: 0.8)), value: searchText.isEmpty)
        .animation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.35, dampingFraction: 0.8)), value: layoutMode)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: subDeckService.isSubDeckVisible)
        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: subDeckService.focusedLocation)
    }

    // MARK: - Direct Key & Scroll Handling
    private func setupEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown, .flagsChanged]) { [self] event in
            // Only process events when QuickLauncher is visible
            guard PanelController.shared.isQuickLauncherVisible else {
                return event
            }

            if event.type == .flagsChanged {
                KeyboardModifierManager.shared.update(from: event.modifierFlags)
                return event
            }

            // Ignore leftover hotkey keyDown/scroll events within 0.25s of presentation
            if Date().timeIntervalSince(PanelController.shared.lastQuickShowTime) < 0.25 {
                return nil
            }

            if event.type == .scrollWheel {
                handleScrollEvent(event)
                return nil
            } else if event.type == .keyDown {
                KeyboardModifierManager.shared.update(from: event.modifierFlags)
                let isCmd = event.modifierFlags.contains(.command) || KeyboardModifierManager.shared.isCommandPressed

                // Command+O to expand to full screen
                if isCmd && event.charactersIgnoringModifiers == "o" {
                    onExpandToFullScreen()
                    return nil
                }

                // Command+Down Arrow: Toggle Context Sub-Deck
                if isCmd && event.keyCode == 125 {
                    if let app = currentApp, !app.isSeparator {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            subDeckService.toggleSubDeck(for: app)
                        }
                    }
                    return nil
                }

                // Command+Up Arrow: Dismiss Sub-Deck if open
                if isCmd && event.keyCode == 126 {
                    if subDeckService.isSubDeckVisible {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            subDeckService.closeSubDeck()
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
                    if let pasted = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !pasted.isEmpty {
                        searchText.append(pasted)
                        return nil
                    }
                    cycleLayoutMode()
                    return nil
                }

                // Command+Shift+R: Reveal selected app in Finder
                if event.modifierFlags.contains(.command) && (event.charactersIgnoringModifiers == "r" || event.charactersIgnoringModifiers == "R") {
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
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "i" {
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
                            selectedCategory = targetCategory
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
                        let query = searchText
                        searchText = ""
                        let center = discoveryService.apps.count / 2
                        selectedIndex = center
                        discoveryService.selectedIndex = center
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
                            searchText = ""
                            let center = discoveryService.apps.count / 2
                            selectedIndex = center
                            discoveryService.selectedIndex = center
                            onExpandToFullScreen()
                            return nil
                        }
                        let query = searchText
                        searchText = ""
                        let center = discoveryService.apps.count / 2
                        selectedIndex = center
                        discoveryService.selectedIndex = center
                        SoundEffectsManager.shared.playLaunch()
                        discoveryService.launch(app: app, query: query)
                        onDismiss()
                        return nil
                    }
                }

                switch event.keyCode {
                case 126: // Up Arrow
                    if subDeckService.focusedLocation != nil {
                        if let app = currentApp {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                                subDeckService.moveFocusUp(for: app)
                            }
                        }
                        return nil
                    }

                    // On carousel:
                    if layoutMode == .gridWall || layoutMode == .flatGrid {
                        navigate(by: -1) // Up 1 card in column
                    } else {
                        navigate(by: -1)
                    }
                    return nil

                case 125: // Down Arrow
                    if subDeckService.focusedLocation == nil {
                        // From carousel: move down into the sub-deck!
                        if let app = currentApp, !app.isSeparator {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                subDeckService.moveFocusDown(for: app)
                            }
                        }
                        return nil
                    } else if let app = currentApp {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            subDeckService.moveFocusDown(for: app)
                        }
                        return nil
                    }
                    return nil

                case 123: // Left Arrow
                    if subDeckService.focusedLocation != nil {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            subDeckService.moveFocusLeft()
                        }
                        return nil
                    }

                    // On carousel:
                    if layoutMode == .gridWall {
                        navigate(by: -3) // Left 1 column
                    } else if layoutMode == .flatGrid {
                        navigate(by: -threeDSGridRows) // Left 1 column
                    } else {
                        navigate(by: -1)
                    }
                    return nil

                case 124: // Right Arrow
                    if subDeckService.focusedLocation != nil {
                        if let app = currentApp {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                                subDeckService.moveFocusRight(for: app)
                            }
                        }
                        return nil
                    }

                    // On carousel:
                    if layoutMode == .gridWall {
                        navigate(by: 3) // Right 1 column
                    } else if layoutMode == .flatGrid {
                        navigate(by: threeDSGridRows) // Right 1 column
                    } else {
                        navigate(by: 1)
                    }
                    return nil

                case 36, 76: // Return key or Keypad Enter
                    if let loc = subDeckService.focusedLocation, let app = currentApp {
                        // Execute the focused subdeck item!
                        subDeckService.executeItem(at: loc, app: app, onActionExecuted: {
                            subDeckService.closeSubDeck()
                            onDismiss()
                        })
                        return nil
                    }

                    // Launch focused app on carousel
                    if let app = currentApp {
                        if event.modifierFlags.contains(.command) {
                            revealAppInFinder(app: app)
                            return nil
                        } else if event.modifierFlags.contains(.option) {
                            openRecentDocs(app: app)
                            return nil
                        } else if event.modifierFlags.contains(.shift) {
                            copyAppPathOrURL(app: app)
                            return nil
                        }
                    }
                    launchSelectedApp()
                    return nil

                case 53: // Escape key
                    if subDeckService.focusedLocation != nil {
                        SoundEffectsManager.shared.playAction()
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            subDeckService.focusedLocation = nil
                        }
                    } else if subDeckService.isSubDeckVisible {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            subDeckService.closeSubDeck()
                        }
                    } else if !searchText.isEmpty {
                        searchText = ""
                        let center = displayApps.count / 2
                        selectedIndex = center
                        discoveryService.selectedIndex = center
                    } else if selectedCategory != "ALL" {
                        selectedCategory = "ALL"
                        let center = displayApps.count / 2
                        selectedIndex = center
                        discoveryService.selectedIndex = center
                    } else {
                        onDismiss()
                    }
                    return nil

                case 51: // Delete / Backspace key
                    if !searchText.isEmpty {
                        searchText.removeLast()
                    }
                    return nil

                default:
                    // Check if it's a printable character key to search
                    if let characters = event.characters,
                       !characters.isEmpty,
                       !event.modifierFlags.contains(.command),
                       !event.modifierFlags.contains(.control),
                       !event.modifierFlags.contains(.option) {
                        let allowed = CharacterSet.alphanumerics.union(.punctuationCharacters).union(.whitespaces)
                        if characters.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
                            if subDeckService.focusedLocation != nil {
                                subDeckService.focusedLocation = nil
                            }
                            searchText.append(characters)
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
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
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

    private func cycleLayoutMode() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            let nextMode: MainLayoutViewMode
            switch layoutMode {
            case .coverFlow: nextMode = .gridWall
            case .gridWall: nextMode = .flatGrid
            case .flatGrid: nextMode = .coverFlow
            }
            layoutModeRaw = nextMode.rawValue
        }
    }

    private func navigate(by step: Int) {
        guard !displayApps.isEmpty else { return }
        SoundEffectsManager.shared.playNavigation()
        withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.30, dampingFraction: 0.85))) {
            let nextIndex = min(max(0, activeIndex + step), displayApps.count - 1)
            selectedIndex = nextIndex
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
            searchText = ""
            let center = discoveryService.apps.count / 2
            selectedIndex = center
            discoveryService.selectedIndex = center
            onExpandToFullScreen()
            return
        }

        if modifierManager.isCommandPressed {
            revealAppInFinder(app: app)
            return
        }
        if modifierManager.isOptionPressed {
            openRecentDocs(app: app)
            return
        }
        if modifierManager.isShiftPressed {
            copyAppPathOrURL(app: app)
            return
        }

        let query = searchText
        searchText = ""
        let center = discoveryService.apps.count / 2
        selectedIndex = center
        discoveryService.selectedIndex = center
        SoundEffectsManager.shared.playLaunch()
        discoveryService.launch(app: app, query: query)
        onDismiss()
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

    private func openRecentDocs(app: DiscoveredApp) {
        guard !app.isSeparator, app.url.path != Self.openMainAppCard.url.path else {
            SoundEffectsManager.shared.playAction()
            return
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            subDeckService.toggleSubDeck(for: app)
        }
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

    // MARK: - Floating Search & Category Status Badge
    private var searchStatusBadge: some View {
        HStack(spacing: 8) {
            if selectedCategory != "ALL" {
                Text(selectedCategory)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.18), in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )

                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedCategory = "ALL"
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            if !searchText.isEmpty {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))

                Text(searchText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        searchText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(white: 0.08).opacity(0.9), in: Capsule())
        .overlay(
            Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }
}
