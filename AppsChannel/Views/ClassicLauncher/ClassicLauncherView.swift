import SwiftUI
import AppKit
import Combine

// MARK: - Classic Launcher Item Model
enum ClassicLauncherItemKind: Hashable {
    case application
    case suggestion
    case systemAction
    case windowAction
    case customChannel
    case hiddenApp

    var badgeTitle: String {
        switch self {
        case .application: return "Application"
        case .suggestion: return "Suggestion"
        case .systemAction: return "Command"
        case .windowAction: return "Window"
        case .customChannel: return "Channel"
        case .hiddenApp: return "Hidden"
        }
    }
}

struct ClassicLauncherItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let subtitle: String
    let badge: String
    let icon: NSImage
    let accentColor: Color
    let kind: ClassicLauncherItemKind
    let rawApp: DiscoveredApp
    let isRunning: Bool
    let slotNumber: Int?
}

struct ClassicLauncherSection: Identifiable {
    let id: String
    let title: String
    let items: [ClassicLauncherItem]
}

// MARK: - Classic Launcher State & Controller
@MainActor
final class ClassicLauncherState: ObservableObject {
    static let shared = ClassicLauncherState()

    @Published var searchText: String = ""
    @Published var selectedIndex: Int = 0
    @Published var selectedCategory: String = "ALL"
    @Published var isActionsMenuPresented: Bool = false
    @Published var actionsMenuSelectedIndex: Int = 0
    @Published var toastMessage: String? = nil

    @Published private(set) var sections: [ClassicLauncherSection] = []
    @Published private(set) var flatItems: [ClassicLauncherItem] = []

    var eventMonitor: Any? = nil

    init() {
        updateSections()
    }

    func reset() {
        searchText = ""
        selectedCategory = "ALL"
        isActionsMenuPresented = false
        actionsMenuSelectedIndex = 0
        updateSections()
        selectedIndex = 0
    }

    func updateSections() {
        let discoveryService = AppDiscoveryService.shared
        let usageTracker = AppUsageTracker.shared
        let shortcutManager = ShortcutMappingManager.shared
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        var newSections: [ClassicLauncherSection] = []

        // Helper to construct item
        func makeItem(app: DiscoveredApp, overrideKind: ClassicLauncherItemKind? = nil) -> ClassicLauncherItem {
            let isRunning = discoveryService.isRunning(app: app)
            let kind: ClassicLauncherItemKind
            if let override = overrideKind {
                kind = override
            } else if app.isHiddenApp {
                kind = .hiddenApp
            } else if app.systemAction != nil {
                kind = .systemAction
            } else if app.windowAction != nil {
                kind = .windowAction
            } else if app.channelType != nil {
                kind = .customChannel
            } else {
                kind = .application
            }

            let subtitle: String
            if let sys = app.systemAction {
                subtitle = sys.subtitle
            } else if app.windowAction != nil {
                subtitle = "Window Management"
            } else if let channelType = app.channelType {
                subtitle = channelType.rawValue.capitalized + " Channel"
            } else if !app.category.isEmpty && app.category != "OTHER" {
                subtitle = app.category.capitalized
            } else {
                subtitle = app.url.path
            }

            let slotNumber: Int? = (1...9).first { slot in
                shortcutManager.assignedApp(forSlot: slot, in: discoveryService.apps)?.id == app.id
            }

            return ClassicLauncherItem(
                id: app.id,
                name: app.name,
                subtitle: subtitle,
                badge: kind.badgeTitle,
                icon: app.icon,
                accentColor: app.accentColor,
                kind: kind,
                rawApp: app,
                isRunning: isRunning,
                slotNumber: slotNumber
            )
        }

        if trimmed.isEmpty {
            // 1. Suggestions: Top 4 frequently launched apps based on usage
            let standardApps = discoveryService.apps.filter {
                !$0.isSeparator && !$0.isHiddenApp && $0.systemAction == nil && $0.windowAction == nil
            }

            let scoredApps = standardApps.map { (app: $0, score: usageTracker.usageScore(for: $0)) }
                .sorted { $0.score > $1.score }
                .prefix(4)
                .map(\.app)

            let suggestionIds = Set(scoredApps.map(\.id))
            if !scoredApps.isEmpty {
                let items = scoredApps.map { makeItem(app: $0, overrideKind: .suggestion) }
                newSections.append(ClassicLauncherSection(id: "suggestions", title: "Suggestions", items: items))
            }

            // 2. Applications (filtered by category if selected)
            var baseApps = standardApps.filter { !suggestionIds.contains($0.id) }
            if selectedCategory != "ALL" {
                baseApps = baseApps.filter { $0.category == selectedCategory }
            }
            let sortedApps = baseApps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            if !sortedApps.isEmpty {
                let items = sortedApps.map { makeItem(app: $0, overrideKind: .application) }
                newSections.append(ClassicLauncherSection(id: "applications", title: "Applications", items: items))
            }

            // 3. System Commands
            let commands = discoveryService.apps.filter { $0.systemAction != nil }
            if !commands.isEmpty && (selectedCategory == "ALL" || selectedCategory == "SYSTEM") {
                let items = commands.map { makeItem(app: $0, overrideKind: .systemAction) }
                newSections.append(ClassicLauncherSection(id: "commands", title: "Commands", items: items))
            }

            // 4. Window Management
            let windowActions = discoveryService.apps.filter { $0.windowAction != nil }
            if !windowActions.isEmpty && (selectedCategory == "ALL" || selectedCategory == "WINDOW") {
                let items = windowActions.map { makeItem(app: $0, overrideKind: .windowAction) }
                newSections.append(ClassicLauncherSection(id: "window", title: "Window Management", items: items))
            }

            // 5. Custom Channels
            let customChannels = discoveryService.apps.filter { $0.channelType != nil }
            if !customChannels.isEmpty && (selectedCategory == "ALL" || selectedCategory == "CHANNELS") {
                let items = customChannels.map { makeItem(app: $0, overrideKind: .customChannel) }
                newSections.append(ClassicLauncherSection(id: "channels", title: "Channels", items: items))
            }

        } else {
            // Filtered Search: Match across applications, commands, window actions, and hidden apps
            var allCandidates = discoveryService.apps.filter { !$0.isSeparator }
            if selectedCategory == "ALL" || selectedCategory == "WINDOW" || selectedCategory == "Window Management" {
                let unassigned = WindowManagementService.shared.matchingUnassignedWindowActions(query: trimmed)
                if !unassigned.isEmpty {
                    let existingIds = Set(allCandidates.map(\.id))
                    for item in unassigned where !existingIds.contains(item.id) {
                        allCandidates.append(item)
                    }
                }
            }

            let scoredCandidates: [(app: DiscoveredApp, score: Double)] = allCandidates.compactMap { app in
                let score = usageTracker.searchScore(for: app, query: trimmed)
                let matchesName = app.name.localizedCaseInsensitiveContains(trimmed)
                let matchesCat = app.category.localizedCaseInsensitiveContains(trimmed)
                let matchesKeywords = app.systemAction?.keywords.contains { $0.localizedCaseInsensitiveContains(trimmed) } ?? false
                let matchesWindow = app.windowAction?.keywords.contains { $0.localizedCaseInsensitiveContains(trimmed) } ?? false

                if matchesName || matchesCat || matchesKeywords || matchesWindow || score >= 40.0 {
                    return (app, score)
                }
                return nil
            }

            let sorted = scoredCandidates.sorted { s1, s2 in
                if s1.score != s2.score { return s1.score > s2.score }
                return s1.app.name.localizedCaseInsensitiveCompare(s2.app.name) == .orderedAscending
            }.map(\.app)

            var appsMatches: [DiscoveredApp] = []
            var commandMatches: [DiscoveredApp] = []
            var windowMatches: [DiscoveredApp] = []
            var channelMatches: [DiscoveredApp] = []

            for app in sorted {
                if app.systemAction != nil {
                    commandMatches.append(app)
                } else if app.windowAction != nil {
                    windowMatches.append(app)
                } else if app.channelType != nil {
                    channelMatches.append(app)
                } else {
                    appsMatches.append(app)
                }
            }

            if !appsMatches.isEmpty {
                let items = appsMatches.map { makeItem(app: $0, overrideKind: .application) }
                newSections.append(ClassicLauncherSection(id: "applications", title: "Applications", items: items))
            }

            if !commandMatches.isEmpty {
                let items = commandMatches.map { makeItem(app: $0, overrideKind: .systemAction) }
                newSections.append(ClassicLauncherSection(id: "commands", title: "Commands", items: items))
            }

            if !windowMatches.isEmpty {
                let items = windowMatches.map { makeItem(app: $0, overrideKind: .windowAction) }
                newSections.append(ClassicLauncherSection(id: "window", title: "Window Management", items: items))
            }

            if !channelMatches.isEmpty {
                let items = channelMatches.map { makeItem(app: $0, overrideKind: .customChannel) }
                newSections.append(ClassicLauncherSection(id: "channels", title: "Channels", items: items))
            }

            // Matching Hidden Apps
            let hiddenMatches = discoveryService.matchingHiddenApps(query: trimmed)
            if !hiddenMatches.isEmpty {
                let items = hiddenMatches.map { makeItem(app: $0, overrideKind: .hiddenApp) }
                newSections.append(ClassicLauncherSection(id: "hidden", title: "Hidden Apps", items: items))
            }
        }

        self.sections = newSections
        self.flatItems = newSections.flatMap(\.items)

        if flatItems.isEmpty {
            isActionsMenuPresented = false
            selectedIndex = 0
        } else if selectedIndex >= flatItems.count {
            selectedIndex = max(0, flatItems.count - 1)
        }
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

// MARK: - Classic Launcher View
struct ClassicLauncherView: View {
    @ObservedObject private var state = ClassicLauncherState.shared
    @ObservedObject private var discoveryService = AppDiscoveryService.shared
    @ObservedObject private var modifierManager = KeyboardModifierManager.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onExpandToFullScreen: () -> Void
    let onSwitchToQuickHUD: () -> Void
    let onDismiss: () -> Void

    @FocusState private var isSearchFieldFocused: Bool

    private var currentTheme: AppVisualTheme {
        themeManager.currentTheme
    }

    private var selectedItem: ClassicLauncherItem? {
        guard !state.flatItems.isEmpty, state.selectedIndex < state.flatItems.count else { return nil }
        return state.flatItems[state.selectedIndex]
    }

    private var availableCategories: [String] {
        var set = Set<String>()
        for app in discoveryService.apps {
            set.insert(app.category)
        }
        var list = Array(set).sorted()
        list.insert("ALL", at: 0)
        return list
    }

    var body: some View {
        ZStack {
            // Liquid Glass Translucent Window Frame
            VStack(spacing: 0) {
                // Top Search Bar
                searchHeaderView

                Divider()
                    .background(Color.white.opacity(0.08))

                // Scrollable Grouped Items List
                itemsListView

                Divider()
                    .background(Color.white.opacity(0.08))

                // Bottom Action Deck & Status Bar
                bottomFooterView
            }
            .frame(width: 680, height: 460)
            .background(
                ZStack {
                    VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow)

                    // Theme-Adaptive Tint & Reflection
                    currentTheme.canvasBackgroundGradient
                        .opacity(0.92)

                    // Top Glass Highlight
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(currentTheme.canvasBorderGradient, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 36, x: 0, y: 18)
            .shadow(color: currentTheme.selectionGlowColor.opacity(0.15), radius: 16, x: 0, y: 4)

            // In-Launcher Actions Sheet (⌘K Popover)
            if state.isActionsMenuPresented, let item = selectedItem {
                actionsSheetOverlay(item: item)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                    .zIndex(200)
            }

            // Toast Overlay
            if let toast = state.toastMessage {
                toastView(message: toast)
                    .offset(y: 180)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(201)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            state.reset()
            KeyboardModifierManager.shared.reset()
            setupEventMonitor()
            isSearchFieldFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFieldFocused = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isSearchFieldFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidShow)) { _ in
            state.reset()
            KeyboardModifierManager.shared.reset()
            setupEventMonitor()
            isSearchFieldFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFieldFocused = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isSearchFieldFocused = true
            }
        }
        .onChange(of: isSearchFieldFocused) { _, newValue in
            if !newValue && !state.isActionsMenuPresented {
                DispatchQueue.main.async {
                    isSearchFieldFocused = true
                }
            }
        }
        .onReceive(discoveryService.$runningBundleIds) { _ in
            state.updateSections()
        }
        .onReceive(NotificationCenter.default.publisher(for: .quickLauncherDidDismiss)) { _ in
            removeEventMonitor()
            KeyboardModifierManager.shared.reset()
        }
        .onDisappear {
            removeEventMonitor()
            KeyboardModifierManager.shared.reset()
        }
    }

    // MARK: - Search Header View
    private var searchHeaderView: some View {
        HStack(spacing: 12) {
            // App / Search Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 28, height: 28)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }

            // Search Text Field
            TextField("Search for apps or commands...", text: $state.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(currentTheme.titleTextColor)
                .focused($isSearchFieldFocused)
                .onChange(of: state.searchText) { _, _ in
                    state.updateSections()
                    state.selectedIndex = 0
                }
                .onSubmit {
                    launchItemAtSelection()
                }

            Spacer()

            // Active Category Filter Tag
            if state.selectedCategory != "ALL" {
                HStack(spacing: 5) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 9))
                    Text(state.selectedCategory)
                        .font(.system(size: 11, weight: .bold, design: .rounded))

                    Button(action: {
                        state.selectedCategory = "ALL"
                        state.updateSections()
                        state.selectedIndex = 0
                        SoundEffectsManager.shared.playAction()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.15), in: Capsule())
                .foregroundStyle(.white)
            }

            // Expand to Full Channel Window (⌘O)
            Button(action: {
                SoundEffectsManager.shared.playAction()
                onExpandToFullScreen()
            }) {
                Image(systemName: "macwindow.and.cursorarrow")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.08), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help("Open Full Channel Window (⌘O)")

            // Dismiss Button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Close (⎋)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Items List View
    private var itemsListView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 12, pinnedViews: []) {
                    if state.flatItems.isEmpty {
                        emptyResultsView
                    } else {
                        ForEach(state.sections) { section in
                            sectionView(section: section)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .simultaneousGesture(TapGesture().onEnded {
                isSearchFieldFocused = true
            })
            .onChange(of: state.selectedIndex) { _, _ in
                if let item = selectedItem {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(item.id, anchor: .center)
                    }
                    isSearchFieldFocused = true
                }
            }
        }
    }

    // MARK: - Section & Row Views
    private func sectionView(section: ClassicLauncherSection) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            // Section Header
            HStack {
                Text(section.title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .padding(.horizontal, 8)
                    .padding(.top, 4)

                Spacer()
            }

            // Rows in Section
            ForEach(section.items) { item in
                let isSelected = (selectedItem?.id == item.id)
                rowItemView(item: item, isSelected: isSelected)
                    .id(item.id)
            }
        }
    }

    private func rowItemView(item: ClassicLauncherItem, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            // Icon with Running Indicator Dot
            ZStack(alignment: .bottomLeading) {
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)

                if item.isRunning {
                    Circle()
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.45))
                        .frame(width: 5, height: 5)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.6), lineWidth: 1))
                        .shadow(color: Color.green.opacity(0.6), radius: 2)
                        .offset(x: -2, y: 2)
                }
            }
            .frame(width: 26, height: 26)

            // Name & Subtitle
            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.92))
                        .lineLimit(1)

                    if item.rawApp.isHiddenApp {
                        Text("Hidden")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.18), in: Capsule())
                    }
                }

                Text(item.subtitle)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.white.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // Quick Slot Shortcut Badge (if assigned to ⌥1..9)
            if let slot = item.slotNumber {
                Text("⌥\(slot)")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.6))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(isSelected ? 0.2 : 0.08), in: RoundedRectangle(cornerRadius: 4))
            }

            // Right Type Badge (e.g. "Application", "Command", "Window")
            Text(item.badge)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.white.opacity(0.5))
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(isSelected ? 0.16 : 0.06))
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                        )
                } else {
                    Color.clear
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if let idx = state.flatItems.firstIndex(where: { $0.id == item.id }) {
                state.selectedIndex = idx
                launchItemAtSelection()
            }
        }
        .onTapGesture(count: 1) {
            if let idx = state.flatItems.firstIndex(where: { $0.id == item.id }) {
                state.selectedIndex = idx
                SoundEffectsManager.shared.playNavigation()
                isSearchFieldFocused = true
            }
        }
    }

    private var emptyResultsView: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 50)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(Color.white.opacity(0.3))

            Text("No results for \"\(state.searchText)\"")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.7))

            Text("Try searching for installed apps, system commands, or window actions.")
                .font(.system(size: 11))
                .foregroundStyle(Color.white.opacity(0.4))
            Spacer().frame(height: 50)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Action Deck & Status Bar
    private var bottomFooterView: some View {
        HStack(spacing: 12) {
            // Selected Item Path or Info
            if let item = selectedItem {
                HStack(spacing: 6) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 13, height: 13)

                    Text(item.rawApp.systemAction?.subtitle ?? (item.rawApp.url.isFileURL ? item.rawApp.url.path : item.name))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            } else {
                Text("AppsChannel Classic Launcher")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.4))
            }

            Spacer()

            // Primary Action Button Pill
            Button(action: {
                launchItemAtSelection()
            }) {
                HStack(spacing: 6) {
                    Text(primaryActionTitle)
                        .font(.system(size: 11, weight: .bold, design: .rounded))

                    Text("↵")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(primaryActionReturnBadgeColor, in: RoundedRectangle(cornerRadius: 3))
                }
                .foregroundStyle(primaryActionTextColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(primaryActionBackgroundColor, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Secondary Actions Menu Button (⌘K)
            Button(action: {
                guard selectedItem != nil else { return }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    state.isActionsMenuPresented.toggle()
                    state.actionsMenuSelectedIndex = 0
                }
                SoundEffectsManager.shared.playAction()
            }) {
                HStack(spacing: 5) {
                    Text("Actions")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))

                    Text("⌘K")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(selectedItem != nil ? 0.65 : 0.3))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                }
                .foregroundStyle(.white.opacity(selectedItem != nil ? 0.85 : 0.35))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white.opacity(selectedItem != nil ? 0.08 : 0.03), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(selectedItem != nil ? 0.16 : 0.06), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(selectedItem == nil)
            .help("Actions Menu (⌘K)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.25))
    }

    private var primaryActionTitle: String {
        guard let item = selectedItem else { return "Open" }
        if modifierManager.isCommandPressed && item.rawApp.url.isFileURL && item.rawApp.systemAction == nil {
            return "Reveal in Finder"
        }
        if modifierManager.isShiftPressed {
            return "Copy Path"
        }
        switch item.kind {
        case .systemAction: return "Run Command"
        case .windowAction: return "Snap Window"
        case .customChannel: return "Open Channel"
        default: return "Open Application"
        }
    }

    private var primaryActionTextColor: Color {
        if modifierManager.isCommandPressed || modifierManager.isShiftPressed {
            return .white
        }
        return .black
    }

    private var primaryActionBackgroundColor: Color {
        if modifierManager.isCommandPressed {
            return Color(red: 0.08, green: 0.52, blue: 1.0)
        }
        if modifierManager.isShiftPressed {
            return Color(red: 0.68, green: 0.32, blue: 0.88)
        }
        return .white
    }

    private var primaryActionReturnBadgeColor: Color {
        if modifierManager.isCommandPressed || modifierManager.isShiftPressed {
            return Color.white.opacity(0.25)
        }
        return Color.black.opacity(0.15)
    }

    // MARK: - Actions Sheet Overlay (⌘K Menu)
    private func actionsSheetOverlay(item: ClassicLauncherItem) -> some View {
        ZStack {
            Color.black.opacity(0.4)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                        state.isActionsMenuPresented = false
                    }
                }

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Image(nsImage: item.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)

                    Text("Actions for \(item.name)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Button(action: {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                            state.isActionsMenuPresented = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.04))

                Divider().background(Color.white.opacity(0.08))

                // Actions List
                let actions = makeActions(for: item)
                VStack(spacing: 2) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                        let isSel = (state.actionsMenuSelectedIndex == index)
                        Button(action: {
                            action.execute()
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                                state.isActionsMenuPresented = false
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: action.icon)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(action.isDestructive ? .red : (isSel ? .white : .white.opacity(0.8)))
                                    .frame(width: 20)

                                Text(action.title)
                                    .font(.system(size: 12.5, weight: isSel ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(action.isDestructive ? .red : .white)

                                Spacer()

                                if let shortcut = action.shortcutHint {
                                    Text(shortcut)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(isSel ? .white : .white.opacity(0.5))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.white.opacity(isSel ? 0.2 : 0.08), in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(isSel ? Color.white.opacity(0.16) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .frame(width: 360)
            .background(
                Color(white: 0.12).opacity(0.96)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.6), radius: 24, x: 0, y: 12)
        }
    }

    private struct LauncherActionOption {
        let title: String
        let icon: String
        let shortcutHint: String?
        let isDestructive: Bool
        let execute: () -> Void
    }

    private func makeActions(for item: ClassicLauncherItem) -> [LauncherActionOption] {
        var list: [LauncherActionOption] = []

        list.append(LauncherActionOption(
            title: "Launch / Open",
            icon: "arrow.up.forward.app.fill",
            shortcutHint: "↵",
            isDestructive: false,
            execute: { launchItem(item) }
        ))

        if item.rawApp.url.isFileURL && item.rawApp.systemAction == nil {
            list.append(LauncherActionOption(
                title: "Reveal in Finder",
                icon: "folder.fill",
                shortcutHint: "⌘↵",
                isDestructive: false,
                execute: { revealInFinder(app: item.rawApp) }
            ))

            list.append(LauncherActionOption(
                title: "Get Info",
                icon: "info.circle.fill",
                shortcutHint: "⌘I",
                isDestructive: false,
                execute: { getInfo(app: item.rawApp) }
            ))
        }

        list.append(LauncherActionOption(
            title: "Copy Path / URL",
            icon: "doc.on.doc.fill",
            shortcutHint: "⇧↵",
            isDestructive: false,
            execute: { copyPathOrURL(app: item.rawApp) }
        ))

        if let bundleId = item.rawApp.bundleIdentifier {
            list.append(LauncherActionOption(
                title: "Copy Bundle Identifier",
                icon: "curlybraces",
                shortcutHint: "⌘B",
                isDestructive: false,
                execute: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bundleId, forType: .string)
                    state.showToast(message: "Copied: \(bundleId)")
                    SoundEffectsManager.shared.playAction()
                }
            ))
        }

        list.append(LauncherActionOption(
            title: "Switch to 3D Cover Flow HUD",
            icon: "rectangle.portrait.on.rectangle.portrait.fill",
            shortcutHint: "⌘L",
            isDestructive: false,
            execute: { onSwitchToQuickHUD() }
        ))

        list.append(LauncherActionOption(
            title: "Open Full Channel Window",
            icon: "macwindow.and.cursorarrow",
            shortcutHint: "⌘O",
            isDestructive: false,
            execute: { onExpandToFullScreen() }
        ))

        if item.isRunning {
            list.append(LauncherActionOption(
                title: "Hide Application",
                icon: "eye.slash.fill",
                shortcutHint: "⌘H",
                isDestructive: false,
                execute: {
                    if let app = NSRunningApplication.runningApplications(withBundleIdentifier: item.rawApp.bundleIdentifier ?? "").first {
                        app.hide()
                        state.showToast(message: "Hidden: \(item.name)")
                    }
                }
            ))

            list.append(LauncherActionOption(
                title: "Quit Application",
                icon: "xmark.circle.fill",
                shortcutHint: "⌘Q",
                isDestructive: true,
                execute: {
                    discoveryService.terminateApp(item.rawApp, force: false)
                    state.showToast(message: "Quit: \(item.name)")
                }
            ))
        }

        list.append(LauncherActionOption(
            title: "Quit AppsChannel Completely",
            icon: "power",
            shortcutHint: "⇧⌘Q",
            isDestructive: true,
            execute: {
                AppDelegate.quitCompletely()
            }
        ))

        return list
    }

    // MARK: - Direct Key Handling Event Monitor
    private func setupEventMonitor() {
        if let existing = state.eventMonitor {
            NSEvent.removeMonitor(existing)
            state.eventMonitor = nil
        }

        state.eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            guard PanelController.shared.isQuickLauncherVisible else { return event }

            if event.type == .flagsChanged {
                KeyboardModifierManager.shared.update(from: event.modifierFlags)
                return event
            }

            let isCmd = event.modifierFlags.contains(.command)
            let isShift = event.modifierFlags.contains(.shift)
            let isOpt = event.modifierFlags.contains(.option)

            // Command + Shift + Q: Explicit full quit
            if isCmd && isShift && (event.keyCode == 12 || event.charactersIgnoringModifiers?.lowercased() == "q") {
                AppDelegate.quitCompletely()
                return nil
            }

            // Command + Q: Dismiss launcher if keepRunningInBackgroundOnQuit is enabled, else allow default termination
            if isCmd && !isShift && (event.keyCode == 12 || event.charactersIgnoringModifiers?.lowercased() == "q") {
                let keepAlive = UserDefaults.standard.object(forKey: "keepRunningInBackgroundOnQuit") as? Bool ?? true
                if keepAlive {
                    SoundEffectsManager.shared.playAction()
                    onDismiss()
                    return nil
                } else {
                    AppDelegate.quitCompletely()
                    return nil
                }
            }

            // If Actions Sheet is open, route navigation inside it
            if state.isActionsMenuPresented {
                let optionsCount = (selectedItem != nil) ? makeActions(for: selectedItem!).count : 0
                if event.keyCode == 53 { // Escape
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                        state.isActionsMenuPresented = false
                    }
                    return nil
                }
                if event.keyCode == 126 { // Up
                    state.actionsMenuSelectedIndex = max(0, state.actionsMenuSelectedIndex - 1)
                    SoundEffectsManager.shared.playNavigation()
                    return nil
                }
                if event.keyCode == 125 { // Down
                    state.actionsMenuSelectedIndex = optionsCount > 0 ? min(optionsCount - 1, state.actionsMenuSelectedIndex + 1) : 0
                    SoundEffectsManager.shared.playNavigation()
                    return nil
                }
                if event.keyCode == 36 || event.keyCode == 76 { // Return
                    if let item = selectedItem {
                        let acts = makeActions(for: item)
                        if state.actionsMenuSelectedIndex >= 0 && state.actionsMenuSelectedIndex < acts.count {
                            acts[state.actionsMenuSelectedIndex].execute()
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                                state.isActionsMenuPresented = false
                            }
                        }
                    }
                    return nil
                }
                return event
            }

            // Command + K: Toggle Actions Palette
            if isCmd && (event.keyCode == 40 || event.charactersIgnoringModifiers?.lowercased() == "k") {
                if selectedItem != nil {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        state.isActionsMenuPresented.toggle()
                        state.actionsMenuSelectedIndex = 0
                    }
                    SoundEffectsManager.shared.playAction()
                }
                return nil
            }

            // Command + H: Hide focused running application
            if isCmd && (event.keyCode == 4 || event.charactersIgnoringModifiers?.lowercased() == "h") {
                if let app = selectedItem?.rawApp, selectedItem?.isRunning == true,
                   let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier ?? "").first {
                    running.hide()
                    state.showToast(message: "Hidden: \(selectedItem?.name ?? app.name)")
                    SoundEffectsManager.shared.playAction()
                    return nil
                }
            }

            // Command + B: Copy Bundle Identifier
            if isCmd && (event.keyCode == 11 || event.charactersIgnoringModifiers?.lowercased() == "b") {
                if let bundleId = selectedItem?.rawApp.bundleIdentifier {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bundleId, forType: .string)
                    state.showToast(message: "Copied: \(bundleId)")
                    SoundEffectsManager.shared.playAction()
                    return nil
                }
            }

            // Command + L or Command + Shift + V: Switch to 3D Cover Flow HUD
            if (isCmd && (event.keyCode == 37 || event.charactersIgnoringModifiers?.lowercased() == "l")) ||
               (isCmd && isShift && (event.keyCode == 9 || event.charactersIgnoringModifiers?.lowercased() == "v")) {
                SoundEffectsManager.shared.playAction()
                onSwitchToQuickHUD()
                return nil
            }

            // Command + V: Paste clipboard text into search input (without Shift)
            if isCmd && !isShift && (event.keyCode == 9 || event.charactersIgnoringModifiers?.lowercased() == "v") {
                if !isSearchFieldFocused {
                    if let pasted = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !pasted.isEmpty {
                        state.searchText.append(pasted)
                        state.updateSections()
                        state.selectedIndex = 0
                        isSearchFieldFocused = true
                        SoundEffectsManager.shared.playAction()
                        return nil
                    }
                }
                return event
            }

            // Command + O: Expand to Full Channel Window
            if isCmd && (event.keyCode == 31 || event.charactersIgnoringModifiers?.lowercased() == "o") {
                SoundEffectsManager.shared.playAction()
                onExpandToFullScreen()
                return nil
            }

            // Command + 1..8: Category Filtering
            if isCmd, let chars = event.charactersIgnoringModifiers, let num = Int(chars), num >= 1, num <= 8 {
                if let targetCategory = ShortcutMappingManager.shared.category(forSlot: num, availableCategories: availableCategories) {
                    SoundEffectsManager.shared.playNavigation()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        state.selectedCategory = targetCategory
                        state.updateSections()
                        state.selectedIndex = 0
                    }
                    return nil
                }
            }

            // Option + 1..9: Direct Slot Launch
            if isOpt, let chars = event.charactersIgnoringModifiers, let num = Int(chars), num >= 1, num <= 9 {
                if let assigned = ShortcutMappingManager.shared.assignedApp(forSlot: num, in: discoveryService.apps) {
                    let query = state.searchText
                    state.reset()
                    SoundEffectsManager.shared.playLaunch()
                    discoveryService.launch(app: assigned, query: query)
                    onDismiss()
                    return nil
                }
            }

            // Command + I: Get Info
            if isCmd && (event.keyCode == 34 || event.charactersIgnoringModifiers?.lowercased() == "i") {
                if let app = selectedItem?.rawApp {
                    getInfo(app: app)
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

            case 36, 76: // Return
                if isCmd {
                    if let app = selectedItem?.rawApp {
                        revealInFinder(app: app)
                        return nil
                    }
                } else if isShift {
                    if let app = selectedItem?.rawApp {
                        copyPathOrURL(app: app)
                        return nil
                    }
                }
                launchItemAtSelection()
                return nil

            case 53: // Escape
                if !state.searchText.isEmpty {
                    state.searchText = ""
                    state.updateSections()
                    state.selectedIndex = 0
                    SoundEffectsManager.shared.playAction()
                } else if state.selectedCategory != "ALL" {
                    state.selectedCategory = "ALL"
                    state.updateSections()
                    state.selectedIndex = 0
                    SoundEffectsManager.shared.playAction()
                } else {
                    onDismiss()
                }
                return nil

            default:
                // Fallback character typing: ensures typing always goes to search even if focus was disrupted
                if let characters = event.characters,
                   !characters.isEmpty,
                   characters != "\r" && characters != "\n",
                   !isCmd && !event.modifierFlags.contains(.control) && !isOpt {
                    let allowed = CharacterSet.alphanumerics.union(.punctuationCharacters).union(.whitespaces)
                    if characters.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
                        if !isSearchFieldFocused {
                            isSearchFieldFocused = true
                            state.searchText.append(characters)
                            state.updateSections()
                            state.selectedIndex = 0
                            SoundEffectsManager.shared.playNavigation()
                            return nil
                        }
                    }
                }

                // Fallback backspace handling
                if (event.keyCode == 51 || event.keyCode == 117) && !isSearchFieldFocused {
                    if !state.searchText.isEmpty {
                        state.searchText = String(state.searchText.dropLast())
                        state.updateSections()
                        state.selectedIndex = 0
                        isSearchFieldFocused = true
                        SoundEffectsManager.shared.playNavigation()
                        return nil
                    }
                }

                return event
            }
        }
    }

    private func removeEventMonitor() {
        if let monitor = state.eventMonitor {
            NSEvent.removeMonitor(monitor)
            state.eventMonitor = nil
        }
    }

    private func navigate(by step: Int) {
        guard !state.flatItems.isEmpty else { return }
        SoundEffectsManager.shared.playNavigation()
        withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.25, dampingFraction: 0.85))) {
            let count = state.flatItems.count
            let next = min(max(0, state.selectedIndex + step), count - 1)
            state.selectedIndex = next
        }
        isSearchFieldFocused = true
    }

    private func launchItemAtSelection() {
        guard let item = selectedItem else { return }

        if modifierManager.isCommandPressed {
            revealInFinder(app: item.rawApp)
            return
        }
        if modifierManager.isShiftPressed {
            copyPathOrURL(app: item.rawApp)
            return
        }

        launchItem(item)
    }

    private func launchItem(_ item: ClassicLauncherItem) {
        let app = item.rawApp
        if app.url.path == QuickLauncherView.openMainAppCard.url.path {
            SoundEffectsManager.shared.playAction()
            state.reset()
            onExpandToFullScreen()
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

    private func revealInFinder(app: DiscoveredApp) {
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

    private func copyPathOrURL(app: DiscoveredApp) {
        let textToCopy: String
        if let sys = app.systemAction {
            textToCopy = sys.title
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

    private func getInfo(app: DiscoveredApp) {
        guard app.url.isFileURL, app.systemAction == nil else { return }
        SoundEffectsManager.shared.playAction()
        let escaped = app.url.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Finder"
            activate
            open information window of (POSIX file "\(escaped)" as alias)
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
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
        .background(Color(white: 0.08).opacity(0.94), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.24), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}
