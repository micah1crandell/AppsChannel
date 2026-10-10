import SwiftUI
import AppKit
import Combine

@MainActor
final class MainAppState: ObservableObject {
    @Published var isShowingSettings: Bool = false
    var eventMonitor: Any? = nil
}

struct MainAppView: View {
    @StateObject private var discoveryService = AppDiscoveryService.shared
    @StateObject private var appState = MainAppState()
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "ALL"
    @State private var scrollAccumulator: CGFloat = 0.0

    @AppStorage("mainLayoutMode") private var layoutModeRaw: String = MainLayoutViewMode.gridWall.rawValue
    @State private var layoutMode: MainLayoutViewMode = .gridWall
    @State private var isOrganizeMode: Bool = false

    let onSwitchToQuickLauncher: () -> Void
    let onDismiss: () -> Void

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

        // Search Active: Smart search scoring with associative memory
        let candidates = baseList.filter { app in
            app.name.localizedCaseInsensitiveContains(trimmedSearch) ||
            app.category.localizedCaseInsensitiveContains(trimmedSearch) ||
            AppUsageTracker.shared.searchScore(for: app, query: trimmedSearch) > 50.0
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

            // Center Content: Either 1-Row CoverFlow or 3-Row Curved Cylindrical Wall Grid
            VStack {
                Spacer()
                if layoutMode == .coverFlow {
                    CoverFlowCarouselView(
                        apps: filteredApps,
                        activeIndex: activeIndex,
                        isCompact: false,
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
                    CoverFlowWallView(
                        apps: filteredApps,
                        activeIndex: activeIndex,
                        isOrganizeMode: isOrganizeMode,
                        onSelect: { index in
                            withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
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
            .allowsHitTesting(!appState.isShowingSettings)

            // Nintendo Wii / 3DS Style Channel Arranger Deck (Apple Liquid Glass)
            if isOrganizeMode {
                VStack {
                    Spacer()
                    channelArrangerDeck
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .allowsHitTesting(!appState.isShowingSettings)
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
                onPrevious: { navigate(by: layoutMode == .gridWall ? -3 : -1) },
                onNext: { navigate(by: layoutMode == .gridWall ? 3 : 1) },
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
                isOrganizeMode: isOrganizeMode
            )
            .allowsHitTesting(!appState.isShowingSettings)

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
        .onChange(of: searchText) { _ in
            discoveryService.selectedIndex = filteredApps.count / 2
        }
        .onChange(of: selectedCategory) { _ in
            discoveryService.selectedIndex = filteredApps.count / 2
        }
        .onAppear {
            if let mode = MainLayoutViewMode(rawValue: layoutModeRaw) {
                layoutMode = mode
            }
            discoveryService.selectedIndex = filteredApps.count / 2
            setupEventMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidShow)) { notification in
            discoveryService.selectedIndex = filteredApps.count / 2
            if let mode = notification.object as? LauncherMode {
                if mode == .fullScreen {
                    setupEventMonitor()
                } else {
                    removeEventMonitor()
                }
            }
        }
        .onChange(of: appState.isShowingSettings) { isShowing in
            if isShowing {
                scrollAccumulator = 0.0
            }
        }
        .onChange(of: layoutMode) { newMode in
            layoutModeRaw = newMode.rawValue
        }
        .onDisappear {
            removeEventMonitor()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.isShowingSettings)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isOrganizeMode)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: layoutMode)
    }

    // MARK: - Transparent Floating Backdrop with Behind-Window Desktop Blur
    private var backdropLayer: some View {
        ZStack {
            VisualEffectBackground(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Deep obsidian tinted liquid glass layer
            Color(red: 0.04, green: 0.04, blue: 0.05).opacity(0.82)
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
        appState.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .keyDown]) { [weak appState] event in
            guard let appState = appState else { return event }

            // Only process events when Main App window is visible and key
            guard PanelController.shared.isMainAppVisible,
                  let window = event.window ?? NSApp.keyWindow,
                  !(window is AppsChannelPanel) else {
                return event
            }

            // When Settings modal is active, isolate events:
            if appState.isShowingSettings {
                scrollAccumulator = 0.0
                if event.type == .scrollWheel {
                    // Let SettingsModalView's ScrollView handle scroll events natively without moving background cards
                    return event
                } else if event.type == .keyDown {
                    // Escape key dismisses settings
                    if event.keyCode == 53 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            appState.isShowingSettings = false
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

                // Command+V to toggle between 1-Row CoverFlow and 3-Row Curved Wall Grid
                if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "v" {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        layoutMode = (layoutMode == .coverFlow ? .gridWall : .coverFlow)
                    }
                    return nil
                }

                // Command + 1..8: Instant Category Group Switch
                if event.modifierFlags.contains(.command),
                   let chars = event.charactersIgnoringModifiers,
                   let num = Int(chars), num >= 1, num <= categories.count {
                    let cat = categories[num - 1]
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedCategory = cat
                    }
                    return nil
                }

                // Option + 1..9: Direct Launch Channel Slot 1..9
                if event.modifierFlags.contains(.option),
                   let chars = event.charactersIgnoringModifiers,
                   let num = Int(chars), num >= 1, num <= 9 {
                    let targetIdx = num - 1
                    if targetIdx < filteredApps.count {
                        let targetApp = filteredApps[targetIdx]
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
                    if layoutMode == .gridWall {
                        navigate(by: -1) // Move up 1 card in column
                    } else {
                        navigate(by: -1)
                    }
                    return nil

                case 125: // Down Arrow
                    if layoutMode == .gridWall {
                        navigate(by: 1) // Move down 1 card in column
                    } else {
                        navigate(by: 1)
                    }
                    return nil

                case 123: // Left Arrow
                    if layoutMode == .gridWall {
                        navigate(by: -3) // Move left 1 column
                    } else {
                        navigate(by: -1)
                    }
                    return nil

                case 124: // Right Arrow
                    if layoutMode == .gridWall {
                        navigate(by: 3) // Move right 1 column
                    } else {
                        navigate(by: 1)
                    }
                    return nil

                case 36: // Return
                    launchSelectedApp()
                    return nil

                case 53: // Escape
                    if isOrganizeMode {
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
            navigate(by: clampedStep)
        }
    }

    private func navigate(by step: Int) {
        guard !filteredApps.isEmpty else { return }
        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
            let nextIndex = min(max(0, activeIndex + step), filteredApps.count - 1)
            discoveryService.selectedIndex = nextIndex
        }
    }

    private func launchSelectedApp() {
        guard let app = currentApp else { return }
        discoveryService.launch(app: app, query: searchText)
        onDismiss()
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

    // MARK: - Nintendo Wii / 3DS Style Liquid Glass Channel Deck
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
