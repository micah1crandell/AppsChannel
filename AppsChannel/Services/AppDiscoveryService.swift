import AppKit
import SwiftUI
import Combine

nonisolated struct DiscoveredApp: Identifiable, Hashable, @unchecked Sendable {
    let id: UUID
    let name: String
    let url: URL
    let bundleIdentifier: String?
    let icon: NSImage
    let category: String
    let tagBadge: String
    let sizeString: String
    let accentColor: Color

    var isHiddenApp: Bool = false
    var isSeparator: Bool = false
    var channelType: CustomChannelKind? = nil
    var customChannelId: UUID? = nil
    var systemAction: SystemActionType? = nil
    var windowAction: WindowSnappingAction? = nil

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        bundleIdentifier: String?,
        icon: NSImage,
        category: String,
        tagBadge: String,
        sizeString: String,
        accentColor: Color,
        isHiddenApp: Bool = false,
        isSeparator: Bool = false,
        channelType: CustomChannelKind? = nil,
        customChannelId: UUID? = nil,
        systemAction: SystemActionType? = nil,
        windowAction: WindowSnappingAction? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
        self.category = category
        self.tagBadge = tagBadge
        self.sizeString = sizeString
        self.accentColor = accentColor
        self.isHiddenApp = isHiddenApp
        self.isSeparator = isSeparator
        self.channelType = channelType
        self.customChannelId = customChannelId
        self.systemAction = systemAction
        self.windowAction = windowAction
    }

    static let hiddenAppsSeparator: DiscoveredApp = {
        let size = NSSize(width: 128, height: 128)
        let img = NSImage(size: size, flipped: false) { rect in
            let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .bold)
            if let symbol = NSImage(systemSymbolName: "eye.slash.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let tinted = symbol.copy() as! NSImage
                let drawRect = NSRect(x: 16, y: 16, width: 96, height: 96)
                tinted.draw(in: drawRect)
                return true
            }
            return false
        }
        return DiscoveredApp(
            id: UUID(),
            name: "Hidden Apps",
            url: URL(fileURLWithPath: "/AppsChannel/Section/HiddenApps"),
            bundleIdentifier: "com.micahcrandell.AppsChannel.hiddenAppsSeparator",
            icon: img,
            category: "SECTION",
            tagBadge: "HIDDEN",
            sizeString: "|",
            accentColor: .orange,
            isHiddenApp: false,
            isSeparator: true
        )
    }()

    var isAppsChannelApp: Bool {
        if systemAction != nil {
            return false
        }
        if isSeparator {
            return true
        }
        if name.localizedCaseInsensitiveCompare("AppsChannel") == .orderedSame {
            return true
        }
        if let bundleId = bundleIdentifier, bundleId.localizedCaseInsensitiveContains("AppsChannel") {
            return true
        }
        let pathLower = url.path.lowercased()
        if pathLower.hasSuffix("/appschannel.app") || pathLower.contains("/appschannel.app/") {
            return true
        }
        return false
    }

    func hash(into hasher: inout Hasher) {
        if let action = systemAction {
            hasher.combine(action.rawValue)
        } else if let customId = customChannelId {
            hasher.combine(customId)
        } else {
            hasher.combine(url)
        }
    }

    static func == (lhs: DiscoveredApp, rhs: DiscoveredApp) -> Bool {
        if let lAction = lhs.systemAction, let rAction = rhs.systemAction {
            return lAction == rAction
        }
        if let lId = lhs.customChannelId, let rId = rhs.customChannelId {
            return lId == rId
        }
        return lhs.url == rhs.url
    }
}

private struct CachedAppRecord: Codable {
    let name: String
    let path: String
    let bundleId: String?
    let category: String
    let tagBadge: String
    let sizeString: String
    let modDate: Double
}

@MainActor
final class AppDiscoveryService: ObservableObject {
    static let shared = AppDiscoveryService()

    @Published var apps: [DiscoveredApp] = []
    @Published var allDiscoveredApps: [DiscoveredApp] = []
    @Published var isLoading: Bool = false
    @Published var selectedIndex: Int = 0

    private var isCheckingUpdates = false

    nonisolated private static var cacheFileURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let appCacheDir = caches.appendingPathComponent("AppsChannel", isDirectory: true)
        try? FileManager.default.createDirectory(at: appCacheDir, withIntermediateDirectories: true)
        return appCacheDir.appendingPathComponent("apps_cache.json")
    }

    @Published var runningBundleIds: Set<String> = []
    @Published var runningUrls: Set<URL> = []

    private var metadataQuery: NSMetadataQuery?

    init() {
        loadInitialApps()
        setupRunningAppObservers()
        setupSpotlightQuery()
    }

    // MARK: - Running Applications State
    func isRunning(app: DiscoveredApp) -> Bool {
        if let bundleId = app.bundleIdentifier, runningBundleIds.contains(bundleId) {
            return true
        }
        return runningUrls.contains(app.url)
    }

    func updateRunningApplications() {
        let running = NSWorkspace.shared.runningApplications
        let ids = Set(running.compactMap { $0.bundleIdentifier })
        let urls = Set(running.compactMap { $0.bundleURL })
        if self.runningBundleIds != ids {
            self.runningBundleIds = ids
        }
        if self.runningUrls != urls {
            self.runningUrls = urls
        }
    }

    private func setupRunningAppObservers() {
        updateRunningApplications()
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateRunningApplications()
            }
        }
        center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateRunningApplications()
            }
        }
    }

    func terminateApp(_ app: DiscoveredApp, force: Bool = false) {
        let matching = NSWorkspace.shared.runningApplications.filter {
            ($0.bundleIdentifier != nil && $0.bundleIdentifier == app.bundleIdentifier) ||
            ($0.bundleURL != nil && $0.bundleURL?.standardizedFileURL == app.url.standardizedFileURL)
        }
        for running in matching {
            if force {
                running.forceTerminate()
            } else {
                running.terminate()
            }
        }
        SoundEffectsManager.shared.playAction()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateRunningApplications()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.updateRunningApplications()
        }
    }

    private let customOrderKey = "AppsChannelUserCustomOrder"
    private let hiddenAppsKey = "AppsChannelHiddenApps"

    @Published var hiddenAppPaths: Set<String> = []

    func loadHiddenApps() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: hiddenAppsKey) ?? [])
    }

    func isHidden(app: DiscoveredApp) -> Bool {
        hiddenAppPaths.contains(app.url.path)
    }

    func toggleHidden(app: DiscoveredApp) {
        if isHidden(app: app) {
            unhideApp(path: app.url.path)
        } else {
            hideApp(app)
        }
    }

    func hideApp(_ app: DiscoveredApp) {
        var hidden = loadHiddenApps()
        hidden.insert(app.url.path)
        UserDefaults.standard.set(Array(hidden), forKey: hiddenAppsKey)
        self.hiddenAppPaths = hidden

        self.apps = applySavedOrder(to: allDiscoveredApps)
        if !apps.isEmpty && selectedIndex >= apps.count {
            selectedIndex = max(0, apps.count / 2)
        }
        SoundEffectsManager.shared.playAction()
    }

    func unhideApp(path: String) {
        var hidden = loadHiddenApps()
        hidden.remove(path)
        UserDefaults.standard.set(Array(hidden), forKey: hiddenAppsKey)
        self.hiddenAppPaths = hidden

        self.apps = applySavedOrder(to: allDiscoveredApps)
        if !apps.isEmpty && selectedIndex >= apps.count {
            selectedIndex = max(0, apps.count / 2)
        }
        SoundEffectsManager.shared.playAction()
    }

    func hideGroup(category: String) {
        var hidden = loadHiddenApps()
        let targets = allDiscoveredApps.filter { category == "ALL" || $0.category == category }
        for app in targets {
            hidden.insert(app.url.path)
        }
        UserDefaults.standard.set(Array(hidden), forKey: hiddenAppsKey)
        self.hiddenAppPaths = hidden

        self.apps = applySavedOrder(to: allDiscoveredApps)
        if !apps.isEmpty && selectedIndex >= apps.count {
            selectedIndex = max(0, apps.count / 2)
        }
        SoundEffectsManager.shared.playAction()
    }

    func unhideGroup(category: String) {
        var hidden = loadHiddenApps()
        let targets = allDiscoveredApps.filter { category == "ALL" || $0.category == category }
        for app in targets {
            hidden.remove(app.url.path)
        }
        UserDefaults.standard.set(Array(hidden), forKey: hiddenAppsKey)
        self.hiddenAppPaths = hidden

        self.apps = applySavedOrder(to: allDiscoveredApps)
        if !apps.isEmpty && selectedIndex >= apps.count {
            selectedIndex = max(0, apps.count / 2)
        }
        SoundEffectsManager.shared.playAction()
    }

    func unhideAllApps() {
        UserDefaults.standard.removeObject(forKey: hiddenAppsKey)
        self.hiddenAppPaths = []
        self.apps = applySavedOrder(to: allDiscoveredApps)
        if !apps.isEmpty && selectedIndex >= apps.count {
            selectedIndex = max(0, apps.count / 2)
        }
        SoundEffectsManager.shared.playAction()
    }

    /// Returns hidden apps matching a search query, sorted by relevance score, marked with isHiddenApp = true
    func matchingHiddenApps(query: String) -> [DiscoveredApp] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let hiddenPaths = loadHiddenApps()
        guard !hiddenPaths.isEmpty else { return [] }

        let hiddenApps = allDiscoveredApps.filter {
            hiddenPaths.contains($0.url.path) && !$0.isAppsChannelApp
        }

        let candidates = hiddenApps.filter { app in
            app.name.localizedCaseInsensitiveContains(trimmed) ||
            app.category.localizedCaseInsensitiveContains(trimmed) ||
            AppUsageTracker.shared.searchScore(for: app, query: trimmed) > 30.0
        }

        let ranked = candidates.sorted { a1, a2 in
            let s1 = AppUsageTracker.shared.searchScore(for: a1, query: trimmed)
            let s2 = AppUsageTracker.shared.searchScore(for: a2, query: trimmed)
            if s1 != s2 { return s1 > s2 }
            return a1.name.localizedCaseInsensitiveCompare(a2.name) == .orderedAscending
        }

        return ranked.map { app in
            var marked = app
            marked.isHiddenApp = true
            return marked
        }
    }

    func loadSavedOrder() -> [String] {
        UserDefaults.standard.stringArray(forKey: customOrderKey) ?? []
    }

    func saveOrder() {
        let order = apps.map { app -> String in
            if app.systemAction != nil {
                return app.url.absoluteString
            }
            if let customId = app.customChannelId {
                return "custom://\(customId.uuidString)"
            }
            return app.url.path
        }
        UserDefaults.standard.set(order, forKey: customOrderKey)
    }

    func reloadAfterCustomChannelChange() {
        self.apps = applySavedOrder(to: allDiscoveredApps)
        if selectedIndex >= apps.count {
            selectedIndex = max(0, apps.count / 2)
        }
    }

    func applySavedOrder(to discovered: [DiscoveredApp]) -> [DiscoveredApp] {
        let hidden = loadHiddenApps()
        self.hiddenAppPaths = hidden
        var combined = discovered.filter { !hidden.contains($0.url.path) && !$0.isAppsChannelApp }

        let customChannels = CustomChannelManager.shared.toDiscoveredApps()
        for custom in customChannels {
            let key = "custom://\(custom.id.uuidString)"
            if !hidden.contains(key) && !combined.contains(where: { $0.id == custom.id }) {
                combined.append(custom)
            }
        }

        let includeSystemActions = UserDefaults.standard.object(forKey: "enableSystemActions") as? Bool ?? true
        if includeSystemActions {
            let systemActionApps = SystemActionService.shared.allActionApps
            for actionApp in systemActionApps {
                let key = actionApp.url.absoluteString
                if !hidden.contains(key) && !combined.contains(where: { $0.id == actionApp.id }) {
                    combined.append(actionApp)
                }
            }
        }

        if WindowManagementService.shared.isMasterEnabled {
            let windowActionApps = WindowManagementService.shared.allWindowActionApps()
            for actionApp in windowActionApps {
                let key = actionApp.url.absoluteString
                if !hidden.contains(key) && !combined.contains(where: { $0.id == actionApp.id }) {
                    combined.append(actionApp)
                }
            }
        }

        let saved = loadSavedOrder()
        if !saved.isEmpty {
            var appMap = [String: DiscoveredApp]()
            for app in combined {
                let key: String
                if app.systemAction != nil || app.windowAction != nil {
                    key = app.url.absoluteString
                } else if let customId = app.customChannelId {
                    key = "custom://\(customId.uuidString)"
                } else {
                    key = app.url.path
                }
                appMap[key] = app
            }

            var ordered: [DiscoveredApp] = []
            var placedKeys = Set<String>()

            for key in saved {
                if let app = appMap[key] {
                    ordered.append(app)
                    placedKeys.insert(key)
                }
            }

            for app in combined {
                let key: String
                if app.systemAction != nil {
                    key = app.url.absoluteString
                } else if let customId = app.customChannelId {
                    key = "custom://\(customId.uuidString)"
                } else {
                    key = app.url.path
                }
                if !placedKeys.contains(key) {
                    ordered.append(app)
                }
            }

            return ordered
        } else {
            // Default: Sort by usage frequency + recency, then arrange middle-out
            let ranked = combined.sorted { app1, app2 in
                let score1 = AppUsageTracker.shared.usageScore(for: app1)
                let score2 = AppUsageTracker.shared.usageScore(for: app2)
                if score1 != score2 {
                    return score1 > score2
                }
                return app1.name.localizedCaseInsensitiveCompare(app2.name) == .orderedAscending
            }
            let (arranged, _) = AppUsageTracker.shared.arrangeMiddleOut(ranked)
            return arranged
        }
    }

    func moveApp(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex >= 0, sourceIndex < apps.count,
              destinationIndex >= 0, destinationIndex < apps.count,
              sourceIndex != destinationIndex else { return }

        let app = apps.remove(at: sourceIndex)
        apps.insert(app, at: destinationIndex)
        selectedIndex = destinationIndex
        saveOrder()
    }

    func moveAppLeft(at index: Int) {
        guard index > 0 else { return }
        moveApp(from: index, to: index - 1)
    }

    func moveAppRight(at index: Int) {
        guard index < apps.count - 1 else { return }
        moveApp(from: index, to: index + 1)
    }

    func pinToFront(at index: Int) {
        guard index > 0, index < apps.count else { return }
        moveApp(from: index, to: 0)
    }

    func resetToUsageOrder() {
        UserDefaults.standard.removeObject(forKey: customOrderKey)
        let ranked = apps.sorted { app1, app2 in
            let score1 = AppUsageTracker.shared.usageScore(for: app1)
            let score2 = AppUsageTracker.shared.usageScore(for: app2)
            if score1 != score2 {
                return score1 > score2
            }
            return app1.name.localizedCaseInsensitiveCompare(app2.name) == .orderedAscending
        }
        let (arranged, center) = AppUsageTracker.shared.arrangeMiddleOut(ranked)
        self.apps = arranged
        self.selectedIndex = center
    }

    func resetToAlphabetical() {
        UserDefaults.standard.removeObject(forKey: customOrderKey)
        let ranked = apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let (arranged, center) = AppUsageTracker.shared.arrangeMiddleOut(ranked)
        self.apps = arranged
        self.selectedIndex = center
    }

    func loadInitialApps() {
        // Step 1: Instant load from persistent disk cache
        if let cached = Self.loadCacheFromDisk(), !cached.isEmpty {
            let valid = cached.filter { !$0.isAppsChannelApp }
            self.allDiscoveredApps = valid.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            self.apps = applySavedOrder(to: valid)
            self.selectedIndex = min(self.apps.count / 2, max(0, self.apps.count - 1))
            self.isLoading = false

            // Step 2: Non-blocking background delta check
            performBackgroundDeltaCheck()
        } else {
            // Cold start first-time scan
            self.isLoading = true
            Task.detached(priority: .userInitiated) {
                let discovered = Self.scanInstalledApps()
                Self.saveCacheToDisk(apps: discovered)
                await MainActor.run {
                    let valid = discovered.filter { !$0.isAppsChannelApp }
                    self.allDiscoveredApps = valid.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                    self.apps = self.applySavedOrder(to: valid)
                    self.isLoading = false
                    if !self.apps.isEmpty {
                        self.selectedIndex = min(self.apps.count / 2, self.apps.count - 1)
                    }
                }
            }
        }
    }

    func performBackgroundDeltaCheck() {
        guard !isCheckingUpdates else { return }
        isCheckingUpdates = true

        Task.detached(priority: .background) {
            let currentAppPaths = Self.quickAppPathsScan()
            let knownPaths = await MainActor.run {
                Set(self.allDiscoveredApps.map { $0.url.path })
            }

            // Check if there are any new apps in Applications folder not in allDiscoveredApps,
            // or if any apps in allDiscoveredApps no longer exist on disk
            let newPaths = currentAppPaths.subtracting(knownPaths)
            let hasDeletedApps = knownPaths.contains(where: { !FileManager.default.fileExists(atPath: $0) })

            if newPaths.isEmpty && !hasDeletedApps {
                await MainActor.run {
                    self.isCheckingUpdates = false
                }
                return
            }

            let newApps = Self.buildDiscoveredApps(from: newPaths.compactMap { URL(fileURLWithPath: $0) })

            await MainActor.run {
                var merged = self.allDiscoveredApps.filter { FileManager.default.fileExists(atPath: $0.url.path) }
                let mergedPaths = Set(merged.map { $0.url.path })

                for app in newApps where !mergedPaths.contains(app.url.path) && !app.isAppsChannelApp {
                    merged.append(app)
                }

                merged.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                Self.saveCacheToDisk(apps: merged)

                self.allDiscoveredApps = merged
                self.apps = self.applySavedOrder(to: merged)
                if self.selectedIndex >= self.apps.count {
                    self.selectedIndex = max(0, self.apps.count / 2)
                }
                self.isCheckingUpdates = false
            }
        }
    }

    func launch(app: DiscoveredApp, query: String? = nil) {
        guard !app.isSeparator else { return }

        // Execute System Action if applicable
        if let action = app.systemAction {
            SystemActionService.shared.execute(action)
            return
        }

        // Execute Window Management Action if applicable
        if let action = app.windowAction {
            WindowManagementService.shared.performAction(action)
            return
        }

        // Record launch count, recency timestamp, and search query association
        AppUsageTracker.shared.recordLaunch(app: app, query: query)

        if let kind = app.channelType {
            switch kind {
            case .web:
                NSWorkspace.shared.open(app.url)
                return
            case .shortcut:
                let shortcutName = app.name
                DispatchQueue.global(qos: .userInitiated).async {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
                    task.arguments = ["run", shortcutName]
                    do {
                        try task.run()
                    } catch {
                        DispatchQueue.main.async {
                            NSWorkspace.shared.open(app.url)
                        }
                    }
                }
                return
            case .script:
                if let channelId = app.customChannelId,
                   let record = CustomChannelManager.shared.channels.first(where: { $0.id == channelId }) {
                    let command = record.target
                    DispatchQueue.global(qos: .userInitiated).async {
                        let task = Process()
                        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
                        task.arguments = ["-c", command]
                        var env = ProcessInfo.processInfo.environment
                        let standardPath = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
                        env["PATH"] = standardPath + ":" + (env["PATH"] ?? "")
                        task.environment = env
                        do {
                            try task.run()
                        } catch {
                            print("Failed to run script channel: \(error.localizedDescription)")
                        }
                    }
                }
                return
            }
        }

        if app.bundleIdentifier == "com.apple.finder" {
            let scriptSource = """
            tell application "Finder"
                activate
                if (count of Finder windows) is 0 then
                    make new Finder window to (path to home folder)
                end if
            end tell
            """
            DispatchQueue.global(qos: .userInitiated).async {
                if let appleScript = NSAppleScript(source: scriptSource) {
                    var error: NSDictionary?
                    appleScript.executeAndReturnError(&error)
                }
            }
            return
        }

        // If the application is already running, activate it immediately and bring its windows forward
        let runningApp = (app.bundleIdentifier != nil ? NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier!).first : nil)
            ?? NSWorkspace.shared.runningApplications.first(where: { $0.bundleURL == app.url })

        if let runningApp = runningApp {
            if runningApp.isHidden {
                runningApp.unhide()
            }
            runningApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

            if let bundleId = app.bundleIdentifier {
                DispatchQueue.global(qos: .userInitiated).async {
                    let reopenScript = "tell application id \"\(bundleId)\" to reopen"
                    var error: NSDictionary?
                    NSAppleScript(source: reopenScript)?.executeAndReturnError(&error)
                }
            }
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        config.addsToRecentItems = true

        NSWorkspace.shared.openApplication(at: app.url, configuration: config) { targetApp, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("NSWorkspace openApplication failed for \(app.name): \(error.localizedDescription). Attempting fallback...")
                    if !NSWorkspace.shared.open(app.url) {
                        let task = Process()
                        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                        task.arguments = [app.url.path]
                        try? task.run()
                    }
                } else if let targetApp = targetApp {
                    if targetApp.isHidden {
                        targetApp.unhide()
                    }
                    targetApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                }
            }
        }
    }

    func findApp(matching query: String) -> DiscoveredApp? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. Exact name match
        if let exact = allDiscoveredApps.first(where: {
            $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return exact
        }

        // 2. Exact bundle ID match
        if let exactBundle = allDiscoveredApps.first(where: {
            $0.bundleIdentifier?.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return exactBundle
        }

        // 3. Name prefix match
        if let prefix = allDiscoveredApps.first(where: {
            $0.name.lowercased().hasPrefix(trimmed.lowercased())
        }) {
            return prefix
        }

        // 4. Smart score-ranked candidate match
        let candidates = allDiscoveredApps.filter { app in
            app.name.localizedCaseInsensitiveContains(trimmed) ||
            app.category.localizedCaseInsensitiveContains(trimmed) ||
            (app.bundleIdentifier?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            AppUsageTracker.shared.searchScore(for: app, query: trimmed) >= 30.0
        }

        let ranked = candidates.sorted { a1, a2 in
            let s1 = AppUsageTracker.shared.searchScore(for: a1, query: trimmed)
            let s2 = AppUsageTracker.shared.searchScore(for: a2, query: trimmed)
            if s1 != s2 { return s1 > s2 }
            return a1.name.localizedCaseInsensitiveCompare(a2.name) == .orderedAscending
        }

        return ranked.first
    }

    // MARK: - Fast Disk Caching
    nonisolated private static func loadCacheRecords() -> [CachedAppRecord]? {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let records = try? JSONDecoder().decode([CachedAppRecord].self, from: data) else {
            return nil
        }
        return records
    }

    nonisolated private static func loadCacheFromDisk() -> [DiscoveredApp]? {
        guard let records = loadCacheRecords() else { return nil }

        var results: [DiscoveredApp] = []
        let fileManager = FileManager.default

        for record in records {
            guard fileManager.fileExists(atPath: record.path) else { continue }
            guard record.name.localizedCaseInsensitiveCompare("AppsChannel") != .orderedSame else { continue }
            guard !record.path.lowercased().contains("/appschannel.app") else { continue }
            let url = URL(fileURLWithPath: record.path)
            let icon = getCachedIcon(forPath: record.path)
            let accent = deriveAccentColor(category: record.category, name: record.name)

            let app = DiscoveredApp(
                id: UUID(),
                name: record.name,
                url: url,
                bundleIdentifier: record.bundleId,
                icon: icon,
                category: record.category,
                tagBadge: record.tagBadge,
                sizeString: record.sizeString,
                accentColor: accent
            )
            results.append(app)
        }

        // Include macOS Finder
        let finderPath = "/System/Library/CoreServices/Finder.app"
        if !results.contains(where: { $0.url.path == finderPath }) && fileManager.fileExists(atPath: finderPath) {
            let finderURL = URL(fileURLWithPath: finderPath)
            let bundle = Bundle(url: finderURL)
            let finderApp = DiscoveredApp(
                id: UUID(),
                name: "Finder",
                url: finderURL,
                bundleIdentifier: bundle?.bundleIdentifier ?? "com.apple.finder",
                icon: getCachedIcon(forPath: finderPath),
                category: "SYSTEM & UTILITY",
                tagBadge: "File System",
                sizeString: "Universal",
                accentColor: deriveAccentColor(category: "SYSTEM & UTILITY", name: "Finder")
            )
            results.append(finderApp)
        }

        return results
    }

    nonisolated private static func saveCacheToDisk(apps: [DiscoveredApp]) {
        let fileManager = FileManager.default
        let records: [CachedAppRecord] = apps.map { app in
            let modDate = (try? fileManager.attributesOfItem(atPath: app.url.path)[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            return CachedAppRecord(
                name: app.name,
                path: app.url.path,
                bundleId: app.bundleIdentifier,
                category: app.category,
                tagBadge: app.tagBadge,
                sizeString: app.sizeString,
                modDate: modDate
            )
        }

        if let data = try? JSONEncoder().encode(records) {
            try? data.write(to: cacheFileURL, options: .atomic)
        }
    }

    // MARK: - Fast App Path Scan (with Subdirectory & Utility Detection)
    nonisolated static func quickAppPathsScan() -> Set<String> {
        var paths = Set<String>()
        let fileManager = FileManager.default
        let dirs: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        for dir in dirs {
            if let items = try? fileManager.contentsOfDirectory(atPath: dir.path) {
                for item in items {
                    let fullPath = dir.appendingPathComponent(item).path
                    if item.hasSuffix(".app") {
                        paths.insert(fullPath)
                    } else if !item.hasPrefix(".") && !item.hasSuffix(".app") {
                        // Scan 1 level deeper into subfolders (e.g. Setapp, Adobe, Chrome Apps, custom categories)
                        var isDir: ObjCBool = false
                        if fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                            if let subItems = try? fileManager.contentsOfDirectory(atPath: fullPath) {
                                for sub in subItems where sub.hasSuffix(".app") {
                                    paths.insert(URL(fileURLWithPath: fullPath).appendingPathComponent(sub).path)
                                }
                            }
                        }
                    }
                }
            }
        }

        let finderPath = "/System/Library/CoreServices/Finder.app"
        if fileManager.fileExists(atPath: finderPath) {
            paths.insert(finderPath)
        }

        return paths
    }

    // MARK: - Fast App Scanner with Deep Directory Fallback
    nonisolated private static func scanInstalledApps() -> [DiscoveredApp] {
        let fileManager = FileManager.default
        let searchDirectories: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        var candidateURLs: [URL] = []
        for dir in searchDirectories {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .isApplicationKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for item in contents {
                if item.pathExtension == "app" {
                    candidateURLs.append(item)
                } else if item.hasDirectoryPath {
                    // Check subfolders up to 1 level deeper (e.g. /Applications/Setapp, /Applications/Utilities, /Applications/Adobe ...)
                    if let sub = try? fileManager.contentsOfDirectory(
                        at: item,
                        includingPropertiesForKeys: [.isApplicationKey],
                        options: [.skipsHiddenFiles]
                    ) {
                        candidateURLs.append(contentsOf: sub.filter { $0.pathExtension == "app" })
                    }
                }
            }
        }

        let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        if fileManager.fileExists(atPath: finderURL.path) {
            candidateURLs.append(finderURL)
        }

        var results = buildDiscoveredApps(from: candidateURLs)
        results.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return results
    }

    // MARK: - Universal Single App Builder
    nonisolated static func buildApp(at url: URL) -> DiscoveredApp? {
        guard url.isFileURL else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        guard name.localizedCaseInsensitiveCompare("AppsChannel") != .orderedSame else { return nil }
        guard !url.path.lowercased().contains("/appschannel.app") else { return nil }
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }

        let path = url.path

        // Exclude internal system library helpers, input methods, and daemons
        if path.contains("/System/Library/Input Methods") || path.contains("/Library/Input Methods") { return nil }
        if path.contains("/System/Library/Image Capture") || path.contains("/Library/Image Capture") { return nil }
        if path.contains("/System/Library/Services") || path.contains("/Library/Services") { return nil }
        if path.contains("/System/Library/PrivateFrameworks") || path.contains("/Library/Apple/") { return nil }
        if path.contains("/System/Library/CoreServices") && !path.hasSuffix("/Finder.app") && !path.contains("/CoreServices/Applications/") { return nil }

        let bundle = Bundle(url: url)
        if let info = bundle?.infoDictionary {
            // Exclude background agents, daemons, and apps with no GUI
            if let uiElement = info["LSUIElement"] as? Bool, uiElement { return nil }
            if let uiElementStr = info["LSUIElement"] as? String, uiElementStr == "1" { return nil }
            if let bgOnly = info["LSBackgroundOnly"] as? Bool, bgOnly { return nil }
            if let bgOnlyStr = info["LSBackgroundOnly"] as? String, bgOnlyStr == "1" { return nil }
        }

        let bundleId = bundle?.bundleIdentifier

        let categoryRaw = bundle?.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
        let category = formatCategory(raw: categoryRaw, name: name)
        let tagBadge = deriveTagBadge(for: url, name: name, bundleId: bundleId)
        let sizeStr = fastCalculateSize(of: url)
        let accentColor = deriveAccentColor(category: category, name: name)
        let icon = getCachedIcon(forPath: url.path)

        return DiscoveredApp(
            id: UUID(),
            name: name,
            url: url,
            bundleIdentifier: bundleId,
            icon: icon,
            category: category,
            tagBadge: tagBadge,
            sizeString: sizeStr,
            accentColor: accentColor
        )
    }

    // MARK: - Batch App Builder
    nonisolated private static func buildDiscoveredApps(from urls: [URL]) -> [DiscoveredApp] {
        var results: [DiscoveredApp] = []
        var seenNames = Set<String>()
        var seenPaths = Set<String>()

        for url in urls {
            let path = url.standardizedFileURL.path
            guard !seenPaths.contains(path) else { continue }
            seenPaths.insert(path)

            let name = url.deletingPathExtension().lastPathComponent
            guard !seenNames.contains(name) else { continue }
            seenNames.insert(name)

            if let app = buildApp(at: url) {
                results.append(app)
            }
        }
        return results
    }

    // MARK: - Spotlight NSMetadataQuery Integration
    private func setupSpotlightQuery() {
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemContentTypeTree == 'com.apple.application-bundle' || kMDItemContentType == 'com.apple.application-bundle'")
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        query.operationQueue = .main

        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMetadataQueryResults()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleMetadataQueryResults()
            }
        }

        query.start()
        self.metadataQuery = query
    }

    private func handleMetadataQueryResults() {
        guard let query = metadataQuery else { return }
        query.disableUpdates()
        defer { query.enableUpdates() }

        var appURLs: [URL] = []
        for item in query.results {
            guard let mdItem = item as? NSMetadataItem,
                  let path = mdItem.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }

            guard path.hasSuffix(".app") else { continue }
            guard !path.contains("/DerivedData/"),
                  !path.contains("/build/"),
                  !path.contains("/.Trash/"),
                  !path.contains(".framework/"),
                  !path.contains(".app/Contents/Frameworks/"),
                  !path.contains(".app/Contents/XPCServices/"),
                  !path.contains(".app/Contents/Library/") else { continue }
            guard !path.lowercased().contains("/appschannel.app") else { continue }
            guard !path.contains("/System/Library/Input Methods"),
                  !path.contains("/Library/Input Methods"),
                  !path.contains("/System/Library/Image Capture"),
                  !path.contains("/Library/Image Capture"),
                  !path.contains("/System/Library/Services"),
                  !path.contains("/Library/Services"),
                  !path.contains("/System/Library/PrivateFrameworks"),
                  !path.contains("/Library/Apple/"),
                  (!path.contains("/System/Library/CoreServices") || path.hasSuffix("/Finder.app") || path.contains("/CoreServices/Applications/")) else { continue }

            let url = URL(fileURLWithPath: path)
            appURLs.append(url)
        }

        Task.detached(priority: .userInitiated) {
            let processedApps = Self.buildDiscoveredApps(from: appURLs)
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.integrateSpotlightDiscoveredApps(processedApps)
            }
        }
    }

    private func integrateSpotlightDiscoveredApps(_ freshApps: [DiscoveredApp]) {
        let existingPaths = Set(self.allDiscoveredApps.map { $0.url.path })
        let freshPaths = Set(freshApps.map { $0.url.path })

        if existingPaths == freshPaths {
            return
        }

        var merged = self.allDiscoveredApps.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        let currentPaths = Set(merged.map { $0.url.path })

        for app in freshApps where !currentPaths.contains(app.url.path) && !app.isAppsChannelApp {
            merged.append(app)
        }

        merged.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        Self.saveCacheToDisk(apps: merged)

        self.allDiscoveredApps = merged
        self.apps = self.applySavedOrder(to: merged)
        if self.selectedIndex >= self.apps.count {
            self.selectedIndex = max(0, self.apps.count / 2)
        }
    }

    // MARK: - Fast Icon Lookup (AppKit internally caches system icons)
    nonisolated private static func getCachedIcon(forPath path: String) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 160, height: 160)
        return icon
    }

    // MARK: - Instant Approximate Size Lookup (No deep recursive traversal!)
    nonisolated private static func fastCalculateSize(of url: URL) -> String {
        guard url.isFileURL else { return "--" }
        let fm = FileManager.default
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        // Fast check: inspect bundle executable size
        if let execURL = Bundle(url: url)?.executableURL,
           let attrs = try? fm.attributesOfItem(atPath: execURL.path),
           let size = attrs[.size] as? Int64, size > 0 {
            // Rough estimate based on binary footprint
            let estimatedTotal = size * 3
            return formatter.string(fromByteCount: max(size, estimatedTotal))
        }

        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64, size > 1024 * 100 {
            return formatter.string(fromByteCount: size)
        }

        return "Universal"
    }

    nonisolated private static func formatCategory(raw: String?, name: String) -> String {
        let lower = name.lowercased()
        if lower == "finder" {
            return "SYSTEM & UTILITY"
        }
        if lower.contains("terminal") || lower.contains("iterm") || lower.contains("warp") || lower.contains("kitty") || lower.contains("alacritty") {
            return "SHELL & CLI"
        }
        if lower.contains("xcode") || lower.contains("code") || lower.contains("git") || lower.contains("sublime") || lower.contains("zed") {
            return "DEVELOPER"
        }
        if lower.contains("safari") || lower.contains("chrome") || lower.contains("firefox") || lower.contains("edge") || lower.contains("arc") || lower.contains("brave") {
            return "INTERNET"
        }
        if lower.contains("final cut") || lower.contains("davinci") || lower.contains("quicktime") || lower.contains("imovie") || lower.contains("screenflow") {
            return "VIDEO STUDIO"
        }
        if lower.contains("logic") || lower.contains("garageband") || lower.contains("ableton") || lower.contains("music") || lower.contains("spotify") || lower.contains("podcasts") {
            return "AUDIO DAW"
        }
        if lower.contains("blender") || lower.contains("maya") || lower.contains("cinema 4d") || lower.contains("unreal") || lower.contains("unity") {
            return "3D & VFX"
        }
        if lower.contains("figma") || lower.contains("sketch") || lower.contains("photoshop") || lower.contains("illustrator") || lower.contains("photos") {
            return "DESIGN & ART"
        }

        guard let raw = raw?.lowercased() else { return "APPLICATIONS" }
        if raw.contains("developer") { return "DEVELOPER" }
        if raw.contains("video") { return "VIDEO STUDIO" }
        if raw.contains("music") || raw.contains("audio") { return "AUDIO DAW" }
        if raw.contains("graphics") || raw.contains("design") { return "DESIGN & ART" }
        if raw.contains("productivity") { return "PRODUCTIVITY" }
        if raw.contains("utilities") { return "SYSTEM & UTILITY" }
        if raw.contains("social") { return "COMMUNICATION" }
        if raw.contains("games") { return "GAMES" }
        return "APPLICATIONS"
    }

    nonisolated private static func deriveTagBadge(for url: URL, name: String, bundleId: String?) -> String {
        let lower = name.lowercased()
        if lower == "finder" {
            return "File System"
        }
        if lower.contains("terminal") || lower.contains("iterm") || lower.contains("warp") {
            return "M (17+ Devs)"
        }
        if lower.contains("xcode") {
            return "E (Everyone)"
        }
        if lower.contains("logic pro") || lower.contains("final cut") {
            return "Pro Suite"
        }
        return "Universal"
    }

    nonisolated private static func deriveAccentColor(category: String, name: String) -> Color {
        // Pure monochrome white glass highlight
        return Color.white.opacity(0.85)
    }
}
