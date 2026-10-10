import SwiftUI
import AppKit

struct QuickLauncherView: View {
    @StateObject private var discoveryService = AppDiscoveryService.shared
    @State private var searchText: String = ""
    @State private var scrollAccumulator: CGFloat = 0.0
    @State private var eventMonitor: Any? = nil

    let onExpandToFullScreen: () -> Void
    let onDismiss: () -> Void

    @AppStorage("mainLayoutMode") private var layoutModeRaw: String = MainLayoutViewMode.gridWall.rawValue
    @AppStorage("appDisplayStyle") private var appDisplayStyleRaw: String = AppDisplayStyle.iconOnly.rawValue
    @AppStorage("threeDSGridRows") private var threeDSGridRows: Int = 3
    @State private var selectedCategory: String = "ALL"

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
            AppUsageTracker.shared.searchScore(for: app, query: trimmedSearch) > 30.0
        }

        let ranked = candidates.sorted { a1, a2 in
            let s1 = AppUsageTracker.shared.searchScore(for: a1, query: trimmedSearch)
            let s2 = AppUsageTracker.shared.searchScore(for: a2, query: trimmedSearch)
            if s1 != s2 { return s1 > s2 }
            return a1.name.localizedCaseInsensitiveCompare(a2.name) == .orderedAscending
        }

        let (arranged, _) = AppUsageTracker.shared.arrangeMiddleOut(ranked)
        return arranged
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
        // Always append the final button to open the main app at the far right
        list.append(Self.openMainAppCard)
        return list
    }

    private var activeIndex: Int {
        guard !displayApps.isEmpty else { return 0 }
        return min(max(0, discoveryService.selectedIndex), displayApps.count - 1)
    }

    private var currentApp: DiscoveredApp? {
        guard !displayApps.isEmpty, activeIndex < displayApps.count else { return nil }
        return displayApps[activeIndex]
    }

    var body: some View {
        ZStack {
            // Soft feathered backdrop blur that smoothly fades out at the edges into the desktop
            VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)
                .frame(width: 1100, height: 500)
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

            // Middle Content: Fixed, stationary CoverFlow, Wall, or 3DS Grid (never shifts when typing)
            Group {
                if layoutMode == .coverFlow {
                    CoverFlowCarouselView(
                        apps: displayApps,
                        activeIndex: activeIndex,
                        isCompact: true,
                        isIconOnly: appDisplayStyle == .iconOnly,
                        onSelect: { index in
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
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
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
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
                    ThreeDSGridView(
                        apps: displayApps,
                        activeIndex: activeIndex,
                        rowsCount: threeDSGridRows,
                        isCompact: true,
                        isIconOnly: appDisplayStyle == .iconOnly,
                        isOrganizeMode: false,
                        onSelect: { index in
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
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

            // Top Floating Search & Category Status Badge (floats above carousel without moving it)
            VStack {
                if !searchText.isEmpty || selectedCategory != "ALL" {
                    searchStatusBadge
                        .transition(.scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)))
                }
                Spacer()
            }
            .padding(.top, 16)
        }
        .frame(width: 1100, height: 500)
        .onChange(of: searchText) { newText in
            if !newText.isEmpty {
                discoveryService.selectedIndex = filteredApps.count / 2
            }
        }
        .onChange(of: selectedCategory) { _ in
            discoveryService.selectedIndex = filteredApps.count / 2
        }
        .onAppear {
            searchText = ""
            discoveryService.selectedIndex = filteredApps.count / 2
            setupEventMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidShow)) { notification in
            searchText = ""
            discoveryService.selectedIndex = filteredApps.count / 2
            if let mode = notification.object as? LauncherMode {
                if mode == .quickLauncher {
                    setupEventMonitor()
                } else {
                    removeEventMonitor()
                }
            }
        }
        .onDisappear {
            searchText = ""
            removeEventMonitor()
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: searchText.isEmpty)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: layoutMode)
    }

    // MARK: - Direct Key & Scroll Handling
    private func setupEventMonitor() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { [self] event in
            // Only process events when QuickLauncher is visible and event belongs to its panel
            guard PanelController.shared.isQuickLauncherVisible,
                  let window = event.window ?? NSApp.keyWindow,
                  window is AppsChannelPanel else {
                return event
            }

            if event.type == .scrollWheel {
                handleScrollEvent(event)
                return nil
            } else if event.type == .keyDown {
                // Command+O to expand to full screen
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "o" {
                    onExpandToFullScreen()
                    return nil
                }

                // Command+V to cycle between Cover Flow, Wall Grid, and 3DS Grid
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        let nextMode: MainLayoutViewMode
                        switch layoutMode {
                        case .coverFlow: nextMode = .gridWall
                        case .gridWall: nextMode = .threeDSGrid
                        case .threeDSGrid: nextMode = .coverFlow
                        }
                        layoutModeRaw = nextMode.rawValue
                    }
                    return nil
                }

                // Command + 1..8: Category Group Filtering
                if event.modifierFlags.contains(.command),
                   let chars = event.charactersIgnoringModifiers,
                   let num = Int(chars), num >= 1, num <= categories.count {
                    let cat = categories[num - 1]
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedCategory = cat
                    }
                    return nil
                }

                // Option + 1..9: Direct Launch of Channel Slot 1..9
                if event.modifierFlags.contains(.option),
                   let chars = event.charactersIgnoringModifiers,
                   let num = Int(chars), num >= 1, num <= 9 {
                    let targetIdx = num - 1
                    if targetIdx < displayApps.count {
                        let app = displayApps[targetIdx]
                        if app.url.path == Self.openMainAppCard.url.path {
                            searchText = ""
                            onExpandToFullScreen()
                            return nil
                        }
                        let query = searchText
                        searchText = ""
                        discoveryService.launch(app: app, query: query)
                        onDismiss()
                        return nil
                    }
                }

                switch event.keyCode {
                case 126: // Up Arrow
                    if layoutMode == .gridWall || layoutMode == .threeDSGrid {
                        navigate(by: -1) // Up 1 card in column
                    } else {
                        navigate(by: -1)
                    }
                    return nil

                case 125: // Down Arrow
                    if layoutMode == .gridWall || layoutMode == .threeDSGrid {
                        navigate(by: 1) // Down 1 card in column
                    } else {
                        navigate(by: 1)
                    }
                    return nil

                case 123: // Left Arrow
                    if layoutMode == .gridWall {
                        navigate(by: -3) // Left 1 column
                    } else if layoutMode == .threeDSGrid {
                        navigate(by: -threeDSGridRows) // Left 1 column
                    } else {
                        navigate(by: -1)
                    }
                    return nil

                case 124: // Right Arrow
                    if layoutMode == .gridWall {
                        navigate(by: 3) // Right 1 column
                    } else if layoutMode == .threeDSGrid {
                        navigate(by: threeDSGridRows) // Right 1 column
                    } else {
                        navigate(by: 1)
                    }
                    return nil

                case 36, 76: // Return key or Keypad Enter -> Launch app
                    launchSelectedApp()
                    return nil

                case 53: // Escape key
                    if !searchText.isEmpty {
                        searchText = ""
                    } else if selectedCategory != "ALL" {
                        selectedCategory = "ALL"
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
                case .threeDSGrid: return threeDSGridRows
                }
            }()
            navigate(by: clampedStep * stepMultiplier)
        }
    }

    private func navigate(by step: Int) {
        guard !displayApps.isEmpty else { return }
        SoundEffectsManager.shared.playNavigation()
        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
            let nextIndex = min(max(0, activeIndex + step), displayApps.count - 1)
            discoveryService.selectedIndex = nextIndex
        }
    }

    private func launchSelectedApp() {
        guard let app = currentApp else { return }
        if app.url.path == Self.openMainAppCard.url.path {
            SoundEffectsManager.shared.playAction()
            searchText = ""
            onExpandToFullScreen()
            return
        }
        let query = searchText
        searchText = ""
        SoundEffectsManager.shared.playLaunch()
        discoveryService.launch(app: app, query: query)
        onDismiss()
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
