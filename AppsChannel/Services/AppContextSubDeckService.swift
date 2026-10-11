import Foundation
import AppKit
import SwiftUI
import Combine

// MARK: - App Context Kinds
enum AppContextKind: String, CaseIterable, Sendable {
    case clipboard
    case browser
    case photos
    case media
    case developer
    case documents
    case systemAction
    case appGlance

    var title: String {
        switch self {
        case .clipboard: return "Clipboard History"
        case .browser: return "Web Browser"
        case .photos: return "Photos & Graphics"
        case .media: return "Media & Playback"
        case .developer: return "Developer Workspace"
        case .documents: return "Recent Documents"
        case .systemAction: return "System Action"
        case .appGlance: return "App Glance"
        }
    }

    var systemIcon: String {
        switch self {
        case .clipboard: return "doc.on.clipboard.fill"
        case .browser: return "safari.fill"
        case .photos: return "photo.on.rectangle.angled"
        case .media: return "play.circle.fill"
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .documents: return "clock.arrow.circlepath"
        case .systemAction: return "command.circle.fill"
        case .appGlance: return "info.circle.fill"
        }
    }

    var buttonLabel: String {
        switch self {
        case .clipboard: return "Clippings (⌘↓)"
        case .browser: return "Browser (⌘↓)"
        case .photos: return "Photos (⌘↓)"
        case .media: return "Media (⌘↓)"
        case .developer: return "Projects (⌘↓)"
        case .documents: return "Recent (⌘↓)"
        case .systemAction: return "Action (⌘↓)"
        case .appGlance: return "Inspector (⌘↓)"
        }
    }
}

// MARK: - Sub-Deck Keyboard Navigation Location
struct SubDeckLocation: Equatable, Hashable, Sendable {
    var row: Int
    var column: Int
}

// MARK: - Specialized Data Models
struct AppGlanceInfo: Sendable {
    let architectureBadge: String
    let versionString: String
    let bundleSizeString: String
    let isRunning: Bool
    let processID: pid_t?
    let launchCount: Int
    let lastLaunchedText: String
    let bundleIdentifier: String
    let bundlePath: String
}

struct PhotoDeckItem: Identifiable, Hashable, @unchecked Sendable {
    let id: UUID
    let name: String
    let url: URL
    let icon: NSImage
    let pixelDimensions: String?
    let lastUsedDate: Date?

    var formattedRelativeDate: String {
        guard let date = lastUsedDate else { return "Recent" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: PhotoDeckItem, rhs: PhotoDeckItem) -> Bool {
        lhs.url == rhs.url
    }
}

struct DevProjectItem: Identifiable, Hashable, @unchecked Sendable {
    let id: UUID
    let name: String
    let url: URL
    let icon: NSImage
    let projectKind: String
    let lastUsedDate: Date?

    var formattedRelativeDate: String {
        guard let date = lastUsedDate else { return "Recent" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: DevProjectItem, rhs: DevProjectItem) -> Bool {
        lhs.url == rhs.url
    }
}

struct BrowserDownloadItem: Identifiable, Hashable, @unchecked Sendable {
    let id: UUID
    let name: String
    let url: URL
    let icon: NSImage
    let formattedSize: String
    let lastUsedDate: Date?

    var formattedRelativeDate: String {
        guard let date = lastUsedDate else { return "Recent" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: BrowserDownloadItem, rhs: BrowserDownloadItem) -> Bool {
        lhs.url == rhs.url
    }
}

struct BrowserURLItem: Identifiable, Hashable, @unchecked Sendable {
    let id: UUID
    let title: String
    let url: URL
    let domain: String
    let iconName: String
    let isPinned: Bool

    init(id: UUID = UUID(), title: String, url: URL, domain: String? = nil, iconName: String = "globe", isPinned: Bool = false) {
        self.id = id
        self.url = url
        let resolvedDomain = domain ?? (url.host?.replacingOccurrences(of: "www.", with: "") ?? "web")
        self.domain = resolvedDomain
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = cleanTitle.isEmpty ? resolvedDomain : cleanTitle
        self.iconName = iconName
        self.isPinned = isPinned
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: BrowserURLItem, rhs: BrowserURLItem) -> Bool {
        lhs.url == rhs.url
    }
}

struct NowPlayingMediaInfo: Sendable {
    let trackName: String
    let artistName: String
    let albumName: String?
    let isPlaying: Bool
    let appName: String
}

// MARK: - App Context Sub-Deck Service
@MainActor
final class AppContextSubDeckService: ObservableObject {
    static let shared = AppContextSubDeckService()

    @Published private(set) var activeApp: DiscoveredApp? = nil
    @Published private(set) var contextKind: AppContextKind = .appGlance
    @Published private(set) var isLoading: Bool = false

    // Context Payloads
    @Published private(set) var recentDocuments: [RecentDocumentItem] = []
    @Published private(set) var recentPhotos: [PhotoDeckItem] = []
    @Published private(set) var recentDevProjects: [DevProjectItem] = []
    @Published private(set) var recentDownloads: [BrowserDownloadItem] = []
    @Published private(set) var recentURLs: [BrowserURLItem] = []
    @Published private(set) var appGlanceInfo: AppGlanceInfo? = nil
    @Published private(set) var nowPlayingInfo: NowPlayingMediaInfo? = nil

    // Sub-Deck Presentation & Focus State (Observed across Quick Launcher and Main App)
    @Published var isSubDeckVisible: Bool = false
    @Published var focusedLocation: SubDeckLocation? = nil

    private init() {}

    // MARK: - Sub-Deck Presentation & Navigation
    func openSubDeck(for app: DiscoveredApp) {
        guard !app.isSeparator else { return }
        SoundEffectsManager.shared.playAction()
        isSubDeckVisible = true
        focusedLocation = SubDeckLocation(row: 0, column: 0)
    }

    func closeSubDeck() {
        if isSubDeckVisible || focusedLocation != nil {
            SoundEffectsManager.shared.playAction()
            isSubDeckVisible = false
            focusedLocation = nil
        }
    }

    func toggleSubDeck(for app: DiscoveredApp) {
        if isSubDeckVisible {
            closeSubDeck()
        } else {
            openSubDeck(for: app)
        }
    }

    func moveFocusDown(for app: DiscoveredApp) {
        guard !app.isSeparator else { return }
        if !isSubDeckVisible {
            openSubDeck(for: app)
            return
        }
        guard let loc = focusedLocation else {
            focusedLocation = SubDeckLocation(row: 0, column: 0)
            SoundEffectsManager.shared.playNavigation()
            return
        }
        let rows = availableRows(for: app)
        if loc.row < rows.count - 1 {
            let nextRow = loc.row + 1
            let maxCols = rows.indices.contains(nextRow) ? rows[nextRow] : 1
            focusedLocation = SubDeckLocation(row: nextRow, column: min(loc.column, max(0, maxCols - 1)))
            SoundEffectsManager.shared.playNavigation()
        }
    }

    func moveFocusUp(for app: DiscoveredApp) {
        guard let loc = focusedLocation else { return }
        if loc.row > 0 {
            let nextRow = loc.row - 1
            let rows = availableRows(for: app)
            let maxCols = rows.indices.contains(nextRow) ? rows[nextRow] : 1
            focusedLocation = SubDeckLocation(row: nextRow, column: min(loc.column, max(0, maxCols - 1)))
            SoundEffectsManager.shared.playNavigation()
        } else {
            // Reached top row (row 0) -> move focus back UP to highlight the carousel card!
            focusedLocation = nil
            SoundEffectsManager.shared.playNavigation()
        }
    }

    func moveFocusLeft() {
        guard let loc = focusedLocation else { return }
        if loc.column > 0 {
            focusedLocation = SubDeckLocation(row: loc.row, column: loc.column - 1)
            SoundEffectsManager.shared.playNavigation()
        }
    }

    func moveFocusRight(for app: DiscoveredApp) {
        guard let loc = focusedLocation else { return }
        let rows = availableRows(for: app)
        let curRow = loc.row
        let maxCols = rows.indices.contains(curRow) ? rows[curRow] : 1
        if loc.column < maxCols - 1 {
            focusedLocation = SubDeckLocation(row: loc.row, column: loc.column + 1)
            SoundEffectsManager.shared.playNavigation()
        }
    }

    // MARK: - Dynamic Context Detection (Universal, Any App)
    nonisolated func detectContext(for app: DiscoveredApp) -> AppContextKind {
        // 1. System Action & Clipboard Checking
        if app.systemAction == .clipboardHistory || app.name.localizedCaseInsensitiveContains("clipboard history") {
            return .clipboard
        }
        if app.systemAction != nil || app.windowAction != nil {
            return .systemAction
        }
        if let bundleId = app.bundleIdentifier?.lowercased(),
           bundleId.contains("clipboard") || bundleId.contains("maccy") || bundleId.contains("paste") {
            return .clipboard
        }

        guard app.url.isFileURL else {
            return .appGlance
        }

        let bundle = app.url.isFileURL ? Bundle(url: app.url) : nil

        // 2. Browser Detection via URL Scheme Handlers (e.g. http / https)
        if isWebBrowser(bundle: bundle, category: app.category, bundleId: app.bundleIdentifier) {
            return .browser
        }

        // 3. Document UTI & Extension Inspection
        let (types, exts) = RecentDocumentsService.extractDocumentTypes(forAppAt: app.url)

        // Developer / Code / Terminal Apps
        if isDeveloperApp(types: types, exts: exts, category: app.category, bundleId: app.bundleIdentifier) {
            return .developer
        }

        // Photo / Graphic Apps
        if isPhotoOrGraphicApp(types: types, exts: exts, category: app.category, bundleId: app.bundleIdentifier) {
            return .photos
        }

        // Media / Audio / Video Apps
        if isMediaApp(types: types, exts: exts, category: app.category, bundleId: app.bundleIdentifier) {
            return .media
        }

        // Standard Document Editing Apps
        if !types.isEmpty || !exts.isEmpty {
            return .documents
        }

        // 4. Default Fallback for all Utilities, Settings, and Standalone Apps
        return .appGlance
    }

    // MARK: - Fetch Context Data
    func loadContext(for app: DiscoveredApp) async {
        self.activeApp = app
        let kind = detectContext(for: app)
        self.contextKind = kind

        // Always compute glance info as high-speed instant metadata
        let glance = Self.extractGlanceInfo(for: app)
        self.appGlanceInfo = glance

        switch kind {
        case .clipboard, .systemAction, .appGlance:
            self.isLoading = false
            return

        case .browser:
            self.isLoading = true
            let appBundleId = app.bundleIdentifier
            let appURL = app.url
            let (downloads, urls) = await Task.detached(priority: .userInitiated) { () -> ([BrowserDownloadItem], [BrowserURLItem]) in
                let dl = Self.fetchRecentDownloads()
                let u = Self.fetchRecentBrowserURLs(forBundleId: appBundleId, appURL: appURL)
                return (dl, u)
            }.value

            if self.activeApp?.id == app.id {
                self.recentDownloads = downloads
                self.recentURLs = urls
                self.isLoading = false
            }

        case .photos:
            guard app.url.isFileURL else {
                self.isLoading = false
                return
            }
            self.isLoading = true
            let appURL = app.url
            let photos = await Task.detached(priority: .userInitiated) { () -> [PhotoDeckItem] in
                return Self.querySpotlightRecentPhotos(forAppAt: appURL)
            }.value

            if self.activeApp?.id == app.id {
                self.recentPhotos = photos
                self.isLoading = false
            }

        case .media:
            self.isLoading = true
            let appURL = app.url
            let (nowPlaying, mediaFiles) = await Task.detached(priority: .userInitiated) { () -> (NowPlayingMediaInfo?, [RecentDocumentItem]) in
                let now = Self.queryNowPlaying()
                let files = appURL.isFileURL ? RecentDocumentsService.querySpotlightRecentDocuments(forAppAt: appURL) : []
                return (now, files)
            }.value

            if self.activeApp?.id == app.id {
                self.nowPlayingInfo = nowPlaying
                self.recentDocuments = mediaFiles
                self.isLoading = false
            }

        case .developer:
            guard app.url.isFileURL else {
                self.isLoading = false
                return
            }
            self.isLoading = true
            let appURL = app.url
            let devProjects = await Task.detached(priority: .userInitiated) { () -> [DevProjectItem] in
                return Self.querySpotlightDevProjects(forAppAt: appURL)
            }.value

            if self.activeApp?.id == app.id {
                self.recentDevProjects = devProjects
                self.isLoading = false
            }

        case .documents:
            guard app.url.isFileURL else {
                self.isLoading = false
                return
            }
            self.isLoading = true
            let appURL = app.url
            let docs = await Task.detached(priority: .userInitiated) { () -> [RecentDocumentItem] in
                return RecentDocumentsService.querySpotlightRecentDocuments(forAppAt: appURL)
            }.value

            if self.activeApp?.id == app.id {
                self.recentDocuments = docs
                self.isLoading = false
            }
        }
    }

    // MARK: - Browser Actions
    func launchBrowserNewWindow(app: DiscoveredApp) {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: app.url, configuration: config) { _, _ in }
    }

    func launchBrowserPrivateWindow(app: DiscoveredApp) {
        let bundleId = app.bundleIdentifier?.lowercased() ?? ""
        if bundleId.contains("safari") {
            let script = "tell application \"Safari\" to make new document"
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
            }
            return
        }

        // Chromium / Firefox CLI flag arguments for incognito/private
        let flag: String = {
            if bundleId.contains("firefox") { return "--private-window" }
            if bundleId.contains("microsoft.edgemac") { return "--inprivate" }
            return "--incognito"
        }()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", app.url.path, "-n", "--args", flag]
        try? process.run()
    }

    func launchWebSearch(query: String = "") {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = encoded.isEmpty
            ? URL(string: "https://www.google.com")!
            : URL(string: "https://www.google.com/search?q=\(encoded)")!
        NSWorkspace.shared.open(searchURL)
    }

    func openURLInBrowser(_ url: URL, browserApp: DiscoveredApp) {
        if browserApp.url.isFileURL {
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = false
            NSWorkspace.shared.open([url], withApplicationAt: browserApp.url, configuration: config) { _, _ in }
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    nonisolated func classifyAppKind(for app: DiscoveredApp) -> AppContextKind {
        detectContext(for: app)
    }

    // MARK: - Now Playing Controls
    func togglePlayback() {
        let script = """
        if application "Music" is running then
            tell application "Music" to playpause
        else if application "Spotify" is running then
            tell application "Spotify" to playpause
        end if
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
        // Refresh state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.nowPlayingInfo = Self.queryNowPlaying()
        }
    }

    // MARK: - Classifiers & Dynamic Checkers
    nonisolated private func isWebBrowser(bundle: Bundle?, category: String, bundleId: String?) -> Bool {
        if category.caseInsensitiveCompare("WEB") == .orderedSame {
            return true
        }

        if let id = bundleId?.lowercased() {
            if id.contains("safari") || id.contains("chrome") || id.contains("arc") ||
               id.contains("brave") || id.contains("firefox") || id.contains("edge") ||
               id.contains("orion") || id.contains("vivaldi") || id.contains("duckduckgo") ||
               id.contains("zen") {
                return true
            }
        }

        // Universal check: inspect CFBundleURLTypes for http or https schemes
        if let urlTypes = bundle?.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] {
            for typeDict in urlTypes {
                if let schemes = typeDict["CFBundleURLSchemes"] as? [String] {
                    for scheme in schemes {
                        let lower = scheme.lowercased()
                        if lower == "http" || lower == "https" {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }

    nonisolated private func isPhotoOrGraphicApp(types: [String], exts: [String], category: String, bundleId: String?) -> Bool {
        if category.caseInsensitiveCompare("DEVELOPER") == .orderedSame {
            return false
        }

        if category.caseInsensitiveCompare("GRAPHICS") == .orderedSame ||
           category.caseInsensitiveCompare("PHOTOS") == .orderedSame ||
           category.caseInsensitiveCompare("PHOTOGRAPHY") == .orderedSame {
            return true
        }

        if let id = bundleId?.lowercased() {
            if id.contains("photos") || id.contains("preview") || id.contains("pixelmator") ||
               id.contains("photoshop") || id.contains("lightroom") || id.contains("figma") ||
               id.contains("sketch") || id.contains("affinity") {
                return true
            }
        }

        let photoTypes: Set<String> = [
            "public.image", "com.adobe.photoshop-image", "public.camera-raw-image",
            "com.adobe.raw-image", "public.heic", "public.png", "public.jpeg",
            "public.tiff", "com.compuserve.gif", "public.svg-image", "org.webmproject.webp"
        ]

        for t in types {
            if photoTypes.contains(t) || t.contains("image") {
                return true
            }
        }

        let photoExts: Set<String> = [
            "png", "jpg", "jpeg", "heic", "raw", "cr2", "nef", "arw", "psd", "ai",
            "svg", "webp", "tiff", "gif", "bmp", "sketch", "fig"
        ]

        for e in exts {
            if photoExts.contains(e) {
                return true
            }
        }

        return false
    }

    nonisolated private func isMediaApp(types: [String], exts: [String], category: String, bundleId: String?) -> Bool {
        if category.caseInsensitiveCompare("DEVELOPER") == .orderedSame {
            return false
        }

        if category.caseInsensitiveCompare("AUDIO") == .orderedSame ||
           category.caseInsensitiveCompare("VIDEO") == .orderedSame ||
           category.caseInsensitiveCompare("MUSIC") == .orderedSame {
            return true
        }

        if let id = bundleId?.lowercased() {
            if id.contains("music") || id.contains("spotify") || id.contains("podcasts") ||
               id.contains("quicktime") || id.contains("vlc") || id.contains("iina") {
                return true
            }
        }

        let mediaTypes: Set<String> = [
            "public.audio", "public.movie", "public.video", "public.audiovisual-content",
            "com.apple.quicktime-movie", "public.mp3", "public.mpeg-4", "com.apple.m4a"
        ]

        for t in types {
            if mediaTypes.contains(t) || t.contains("audio") || t.contains("movie") || t.contains("video") {
                return true
            }
        }

        let mediaExts: Set<String> = [
            "mp3", "m4a", "wav", "flac", "aac", "mp4", "mov", "mkv", "avi", "logicx"
        ]

        for e in exts {
            if mediaExts.contains(e) {
                return true
            }
        }

        return false
    }

    nonisolated private func isDeveloperApp(types: [String], exts: [String], category: String, bundleId: String?) -> Bool {
        if category.caseInsensitiveCompare("DEVELOPER") == .orderedSame {
            return true
        }

        if let id = bundleId?.lowercased() {
            if id.contains("xcode") || id.contains("vscode") || id.contains("vscodium") ||
               id.contains("cursor") || id.contains("terminal") || id.contains("iterm") ||
               id.contains("ghostty") || id.contains("zed") || id.contains("sublime") ||
               id.contains("fleet") || id.contains("intellij") {
                return true
            }
        }

        let devTypes: Set<String> = [
            "public.source-code", "com.apple.xcode.project", "com.apple.dt.document.workspace",
            "public.script", "public.shell-script", "public.json", "public.xml",
            "com.netscape.javascript-source", "public.c-header", "public.c-source",
            "public.swift-source", "public.python-script"
        ]

        for t in types {
            if devTypes.contains(t) || t.contains("source-code") {
                return true
            }
        }

        let devExts: Set<String> = [
            "xcodeproj", "xcworkspace", "swift", "py", "js", "ts", "rs", "go",
            "c", "cpp", "h", "rb", "php", "sh", "code-workspace"
        ]

        for e in exts {
            if devExts.contains(e) {
                return true
            }
        }

        return false
    }

    // MARK: - App Glance Metadata Extractor
    static func extractGlanceInfo(for app: DiscoveredApp) -> AppGlanceInfo {
        let bundle: Bundle? = app.url.isFileURL ? Bundle(url: app.url) : nil
        let bundleId = app.bundleIdentifier ?? bundle?.bundleIdentifier ?? "Unknown"

        // 1. Architecture Detection (Universal 2, Apple Silicon, Intel)
        let archBadge: String = {
            if app.windowAction != nil {
                return "Window Action"
            }
            if app.systemAction != nil {
                return "System Action"
            }
            if let archs = bundle?.executableArchitectures as? [NSNumber] {
                let archInts = archs.map { $0.intValue }
                // NSBundleExecutableArchitectureARM64 = 0x0100000c, NSBundleExecutableArchitectureX86_64 = 0x01000007
                let hasArm = archInts.contains(0x0100000c)
                let hasX86 = archInts.contains(0x01000007)
                if hasArm && hasX86 {
                    return "Universal (Apple Silicon & Intel)"
                } else if hasArm {
                    return "Apple Silicon (arm64)"
                } else if hasX86 {
                    return "Intel (x86_64)"
                }
            }
            if !app.url.isFileURL {
                return "System Trigger"
            }
            return "Universal"
        }()

        // 2. Version & Build
        let shortVersion = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String
        let buildVersion = bundle?.infoDictionary?["CFBundleVersion"] as? String
        let versionStr: String = {
            if let v = shortVersion, let b = buildVersion, v != b {
                return "v\(v) (\(b))"
            } else if let v = shortVersion ?? buildVersion {
                return "v\(v)"
            }
            if app.windowAction != nil {
                return "Window Snapping"
            }
            if app.systemAction != nil {
                return "Native Action"
            }
            return "Latest"
        }()

        // 3. Process Running State & PID
        let runningApps = (bundleId != "Unknown" && !bundleId.isEmpty && !bundleId.contains("windowAction") && !bundleId.contains("systemAction"))
            ? NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            : []
        let isRunning = !runningApps.isEmpty
        let pid = runningApps.first?.processIdentifier

        // 4. Launch Stats from AppUsageTracker
        let record = app.url.isFileURL ? AppUsageTracker.shared.stats.appRecords[app.url.path] : nil
        let count = record?.launchCount ?? 0
        let lastLaunchedText: String = {
            guard let date = record?.lastLaunchedAt else {
                return (app.systemAction != nil || app.windowAction != nil) ? "Always ready" : "Never launched"
            }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: date, relativeTo: Date())
        }()

        return AppGlanceInfo(
            architectureBadge: archBadge,
            versionString: versionStr,
            bundleSizeString: app.sizeString.isEmpty ? "—" : app.sizeString,
            isRunning: isRunning,
            processID: pid,
            launchCount: count,
            lastLaunchedText: lastLaunchedText,
            bundleIdentifier: bundleId,
            bundlePath: app.url.isFileURL ? app.url.path : app.url.absoluteString
        )
    }

    // MARK: - Spotlight Photo Query
    nonisolated static func querySpotlightRecentPhotos(forAppAt url: URL) -> [PhotoDeckItem] {
        guard url.isFileURL else { return [] }
        let (types, exts) = RecentDocumentsService.extractDocumentTypes(forAppAt: url)
        var subClauses: [String] = []

        let photoTypes = types.filter { $0.contains("image") || $0.contains("photo") || $0.contains("heic") || $0.contains("png") || $0.contains("jpeg") }
        for ct in photoTypes.prefix(6) {
            subClauses.append("kMDItemContentTypeTree == '\(ct)'")
        }

        let photoExts = exts.filter { ["png", "jpg", "jpeg", "heic", "raw", "cr2", "nef", "arw", "psd", "ai", "svg", "webp"].contains($0) }
        for ext in photoExts.prefix(6) {
            subClauses.append("kMDItemFSName == '*.\(ext)'")
        }

        if subClauses.isEmpty {
            subClauses.append("kMDItemContentTypeTree == 'public.image'")
        }

        let typesQuery = subClauses.joined(separator: " || ")
        let fullQuery = "(\(typesQuery)) && (kMDItemContentTypeTree != 'com.apple.application-bundle') && (kMDItemLastUsedDate >= $time.today(-60) || kMDItemContentModificationDate >= $time.today(-60))"

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", homeDir, fullQuery]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            let lines = output.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let fileManager = FileManager.default
            var items: [PhotoDeckItem] = []

            for path in lines {
                guard fileManager.fileExists(atPath: path),
                      !path.contains("/.Trash/"),
                      !path.contains("/Library/"),
                      !path.contains("/DerivedData/"),
                      !path.contains("/build/"),
                      !path.contains("/node_modules/"),
                      !path.contains(".appiconset/"),
                      !path.contains("/.git/") else {
                    continue
                }

                let fileURL = URL(fileURLWithPath: path)
                let name = fileURL.lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 48, height: 48)

                let mdItem = MDItemCreateWithURL(kCFAllocatorDefault, fileURL as CFURL)
                let lastUsedDate: Date? = {
                    if let md = mdItem, let cfDate = MDItemCopyAttribute(md, kMDItemLastUsedDate) as? Date {
                        return cfDate
                    }
                    let attrs = try? fileManager.attributesOfItem(atPath: path)
                    return attrs?[.modificationDate] as? Date
                }()

                let dimensions: String? = {
                    guard let md = mdItem,
                          let width = MDItemCopyAttribute(md, kMDItemPixelWidth) as? Int,
                          let height = MDItemCopyAttribute(md, kMDItemPixelHeight) as? Int else {
                        return nil
                    }
                    return "\(width) × \(height)"
                }()

                items.append(PhotoDeckItem(
                    id: UUID(),
                    name: name,
                    url: fileURL,
                    icon: icon,
                    pixelDimensions: dimensions,
                    lastUsedDate: lastUsedDate
                ))

                if items.count >= 12 { break }
            }

            let sorted = items.sorted { ($0.lastUsedDate ?? .distantPast) > ($1.lastUsedDate ?? .distantPast) }
            return Array(sorted.prefix(6))
        } catch {
            return []
        }
    }

    // MARK: - Spotlight Dev Projects Query
    nonisolated static func querySpotlightDevProjects(forAppAt url: URL) -> [DevProjectItem] {
        guard url.isFileURL else { return [] }
        let fullQuery = "(kMDItemFSName == '*.xcodeproj' || kMDItemFSName == '*.xcworkspace' || kMDItemFSName == '*.code-workspace') && (kMDItemLastUsedDate >= $time.today(-60) || kMDItemContentModificationDate >= $time.today(-60))"

        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments = ["-onlyin", homeDir, fullQuery]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }

            let lines = output.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let fileManager = FileManager.default
            var items: [DevProjectItem] = []

            for path in lines {
                guard fileManager.fileExists(atPath: path),
                      !path.contains("/.Trash/"),
                      !path.contains("/Library/"),
                      !path.contains("/DerivedData/"),
                      !path.contains("/build/"),
                      !path.contains("/SourcePackages/"),
                      !path.contains("/node_modules/"),
                      !path.contains("/.git/") else {
                    continue
                }

                let fileURL = URL(fileURLWithPath: path)
                let name = fileURL.lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 36, height: 36)

                let mdItem = MDItemCreateWithURL(kCFAllocatorDefault, fileURL as CFURL)
                let lastUsedDate: Date? = {
                    if let md = mdItem, let cfDate = MDItemCopyAttribute(md, kMDItemLastUsedDate) as? Date {
                        return cfDate
                    }
                    let attrs = try? fileManager.attributesOfItem(atPath: path)
                    return attrs?[.modificationDate] as? Date
                }()

                let kind: String = {
                    if path.hasSuffix(".xcworkspace") { return "Xcode Workspace" }
                    if path.hasSuffix(".code-workspace") { return "VS Code Workspace" }
                    return "Xcode Project"
                }()

                items.append(DevProjectItem(
                    id: UUID(),
                    name: name,
                    url: fileURL,
                    icon: icon,
                    projectKind: kind,
                    lastUsedDate: lastUsedDate
                ))

                if items.count >= 10 { break }
            }

            let sorted = items.sorted { ($0.lastUsedDate ?? .distantPast) > ($1.lastUsedDate ?? .distantPast) }
            return Array(sorted.prefix(6))
        } catch {
            return []
        }
    }

    // MARK: - Browser Downloads Fetcher
    nonisolated static func fetchRecentDownloads() -> [BrowserDownloadItem] {
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ??
                           FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: downloadsURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var items: [BrowserDownloadItem] = []
        for fileURL in contents {
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isDirectoryKey]),
                  values.isDirectory == false else {
                continue
            }

            let name = fileURL.lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
            icon.size = NSSize(width: 36, height: 36)
            let date = values.contentModificationDate
            let bytes = values.fileSize ?? 0
            let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)

            items.append(BrowserDownloadItem(
                id: UUID(),
                name: name,
                url: fileURL,
                icon: icon,
                formattedSize: formattedSize,
                lastUsedDate: date
            ))
        }

        let sorted = items.sorted { ($0.lastUsedDate ?? .distantPast) > ($1.lastUsedDate ?? .distantPast) }
        return Array(sorted.prefix(6))
    }

    // MARK: - Browser Recent URLs & Bookmarks Fetcher
    nonisolated static func fetchRecentBrowserURLs(forBundleId bundleId: String?, appURL: URL) -> [BrowserURLItem] {
        var items: [BrowserURLItem] = []
        var seenURLs = Set<String>()

        let addURL: @Sendable (String, String, String, Bool) -> Void = { title, urlString, iconName, isPinned in
            let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  !seenURLs.contains(trimmed) else {
                return
            }
            seenURLs.insert(trimmed)
            let domain = url.host?.replacingOccurrences(of: "www.", with: "") ?? "web"
            let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? domain : title
            items.append(BrowserURLItem(
                title: cleanTitle,
                url: url,
                domain: domain,
                iconName: iconName,
                isPinned: isPinned
            ))
        }

        let lowerBundle = bundleId?.lowercased() ?? ""
        let appName = appURL.deletingPathExtension().lastPathComponent.lowercased()

        // 1. Arc Browser: parse StorableSidebar.json
        if lowerBundle.contains("arc") || appName.contains("arc") {
            let arcPath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/Arc/StorableSidebar.json")
            if let data = try? Data(contentsOf: arcPath),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let sidebar = json["sidebar"] as? [String: Any],
               let containers = sidebar["containers"] as? [[String: Any]] {
                for container in containers {
                    if let containerItems = container["items"] as? [[String: Any]] {
                        for itemDict in containerItems {
                            if let dataDict = itemDict["data"] as? [String: Any],
                               let tabDict = dataDict["tab"] as? [String: Any] {
                                let urlStr = (tabDict["savedURL"] as? String) ?? (tabDict["url"] as? String) ?? ""
                                let titleStr = (tabDict["savedTitle"] as? String) ?? (tabDict["title"] as? String) ?? ""
                                if !urlStr.isEmpty {
                                    addURL(titleStr, urlStr, "bookmark.fill", true)
                                }
                            }
                        }
                    }
                }
            }
        }

        // 2. Chromium Browsers (Google Chrome, Brave, Edge, Vivaldi)
        let chromiumPaths: [String] = [
            "Library/Application Support/Google/Chrome",
            "Library/Application Support/BraveSoftware/Brave-Browser",
            "Library/Application Support/Microsoft Edge",
            "Library/Application Support/Vivaldi"
        ]
        let home = FileManager.default.homeDirectoryForCurrentUser
        for relPath in chromiumPaths {
            let baseDir = home.appendingPathComponent(relPath)
            if FileManager.default.fileExists(atPath: baseDir.path) {
                if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: baseDir.path) {
                    for sub in subdirs where sub == "Default" || sub.hasPrefix("Profile ") {
                        let bookmarksFile = baseDir.appendingPathComponent(sub).appendingPathComponent("Bookmarks")
                        if let bData = try? Data(contentsOf: bookmarksFile),
                           let bJson = try? JSONSerialization.jsonObject(with: bData) as? [String: Any],
                           let roots = bJson["roots"] as? [String: Any] {
                            for rootKey in ["bookmark_bar", "other", "synced"] {
                                if let rootDict = roots[rootKey] as? [String: Any],
                                   let children = rootDict["children"] as? [[String: Any]] {
                                    parseChromiumBookmarkNodes(children, addURL: addURL)
                                }
                            }
                        }
                    }
                }
            }
        }

        // 3. Safari Running Tabs via AppleScript
        if lowerBundle.contains("safari") || appName.contains("safari") {
            let isSafariRunning = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").first != nil
            if isSafariRunning {
                let script = """
                tell application "Safari"
                    set res to {}
                    repeat with w in windows
                        repeat with t in tabs of w
                            set u to URL of t
                            set n to name of t
                            if u is not missing value and u is not "" then
                                set end of res to (n & "|||" & u)
                            end if
                        end repeat
                    end repeat
                    return res
                end tell
                """
                if let appleScript = NSAppleScript(source: script) {
                    var error: NSDictionary?
                    let desc = appleScript.executeAndReturnError(&error)
                    if error == nil {
                        for i in 1...desc.numberOfItems {
                            if let itemStr = desc.atIndex(i)?.stringValue {
                                let parts = itemStr.components(separatedBy: "|||")
                                if parts.count == 2 {
                                    addURL(parts[0], parts[1], "safari.fill", false)
                                }
                            }
                        }
                    }
                }
            }
        }

        // 4. Spotlight Internet Location (.webloc) files
        let weblocQuery = "kMDItemContentTypeTree == 'com.apple.web-internet-location' && (kMDItemLastUsedDate >= $time.today(-60) || kMDItemContentModificationDate >= $time.today(-60))"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
        proc.arguments = ["-onlyin", home.path, weblocQuery]
        let pipe = Pipe()
        proc.standardOutput = pipe
        if (try? proc.run()) != nil {
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                for p in lines.prefix(10) {
                    let fileURL = URL(fileURLWithPath: p)
                    if let dict = NSDictionary(contentsOf: fileURL) as? [String: Any],
                       let uStr = dict["URL"] as? String {
                        let name = fileURL.deletingPathExtension().lastPathComponent
                        addURL(name, uStr, "link", false)
                    }
                }
            }
        }

        // 5. Custom Web Channels from AppsChannel
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let customFile = appSupport.appendingPathComponent("AppsChannel/custom_channels.json")
            if let data = try? Data(contentsOf: customFile),
               let records = try? JSONDecoder().decode([CustomChannelRecord].self, from: data) {
                for rec in records where rec.kind == .web {
                    addURL(rec.name, rec.target, "star.fill", true)
                }
            }
        }

        // 6. Curated Fallback Destinations if empty
        if items.isEmpty {
            let defaults: [(String, String)] = [
                ("Google", "https://google.com"),
                ("ChatGPT", "https://chatgpt.com"),
                ("GitHub", "https://github.com"),
                ("Wikipedia", "https://wikipedia.org"),
                ("Apple", "https://apple.com")
            ]
            for (title, url) in defaults {
                addURL(title, url, "globe", false)
            }
        }

        return Array(items.prefix(12))
    }

    nonisolated private static func parseChromiumBookmarkNodes(_ nodes: [[String: Any]], addURL: (String, String, String, Bool) -> Void) {
        for node in nodes {
            if let type = node["type"] as? String, type == "url",
               let urlStr = node["url"] as? String {
                let name = (node["name"] as? String) ?? ""
                addURL(name, urlStr, "bookmark.fill", true)
            } else if let children = node["children"] as? [[String: Any]] {
                parseChromiumBookmarkNodes(children, addURL: addURL)
            }
        }
    }

    // MARK: - Now Playing Query (Music & Spotify)
    nonisolated static func queryNowPlaying() -> NowPlayingMediaInfo? {
        let script = """
        if application "Music" is running then
            tell application "Music"
                set pState to player state as string
                if pState is "playing" or pState is "paused" then
                    set tName to name of current track
                    set aName to artist of current track
                    set albName to album of current track
                    set isPlay to (pState is "playing")
                    return tName & "|||" & aName & "|||" & albName & "|||" & isPlay & "|||Music"
                end if
            end tell
        else if application "Spotify" is running then
            tell application "Spotify"
                set pState to player state as string
                if pState is "playing" or pState is "paused" then
                    set tName to name of current track
                    set aName to artist of current track
                    set albName to album of current track
                    set isPlay to (pState is "playing")
                    return tName & "|||" & aName & "|||" & albName & "|||" & isPlay & "|||Spotify"
                end if
            end tell
        end if
        return ""
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let desc = appleScript.executeAndReturnError(&error)
            if let output = desc.stringValue, !output.isEmpty {
                let parts = output.components(separatedBy: "|||")
                if parts.count >= 5 {
                    return NowPlayingMediaInfo(
                        trackName: parts[0],
                        artistName: parts[1],
                        albumName: parts[2].isEmpty ? nil : parts[2],
                        isPlaying: parts[3] == "true",
                        appName: parts[4]
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Keyboard Navigation Helper Methods
    func availableRows(for app: DiscoveredApp) -> [Int] {
        let kind = detectContext(for: app)
        switch kind {
        case .browser:
            var rows: [Int] = [3] // Row 0: New Window, Private Window, Google Search
            if !recentURLs.isEmpty {
                rows.append(recentURLs.count)
            }
            if !recentDownloads.isEmpty {
                rows.append(recentDownloads.count)
            }
            return rows

        case .clipboard:
            let count = min(8, ClipboardMonitorService.shared.items.count)
            return count > 0 ? [count] : [0]

        case .photos:
            if !recentPhotos.isEmpty {
                return [recentPhotos.count]
            }
            return [app.url.isFileURL ? 2 : 1]

        case .media:
            var rows: [Int] = []
            if nowPlayingInfo != nil {
                rows.append(1) // Play/pause toggle
            }
            if !recentDocuments.isEmpty {
                rows.append(recentDocuments.count)
            }
            if rows.isEmpty {
                rows = [app.url.isFileURL ? 2 : 1]
            }
            return rows

        case .developer:
            if !recentDevProjects.isEmpty {
                return [recentDevProjects.count]
            }
            return [app.url.isFileURL ? 2 : 1]

        case .documents:
            if !recentDocuments.isEmpty {
                return [recentDocuments.count]
            }
            return [app.url.isFileURL ? 2 : 1]

        case .systemAction:
            return [1]

        case .appGlance:
            return [app.url.isFileURL ? 2 : 1]
        }
    }

    func executeItem(at location: SubDeckLocation, app: DiscoveredApp, onActionExecuted: (() -> Void)? = nil) {
        let kind = detectContext(for: app)
        switch kind {
        case .browser:
            if location.row == 0 {
                switch location.column {
                case 0:
                    launchBrowserNewWindow(app: app)
                    SoundEffectsManager.shared.playLaunch()
                    onActionExecuted?()
                case 1:
                    launchBrowserPrivateWindow(app: app)
                    SoundEffectsManager.shared.playLaunch()
                    onActionExecuted?()
                case 2:
                    launchWebSearch()
                    SoundEffectsManager.shared.playLaunch()
                    onActionExecuted?()
                default:
                    break
                }
            } else if location.row == 1 && !recentURLs.isEmpty {
                if location.column < recentURLs.count {
                    let item = recentURLs[location.column]
                    openURLInBrowser(item.url, browserApp: app)
                    SoundEffectsManager.shared.playLaunch()
                    onActionExecuted?()
                }
            } else {
                if location.column < recentDownloads.count {
                    let item = recentDownloads[location.column]
                    NSWorkspace.shared.open(item.url)
                    SoundEffectsManager.shared.playLaunch()
                    onActionExecuted?()
                }
            }

        case .clipboard:
            let items = ClipboardMonitorService.shared.items
            if location.column < items.count {
                let item = items[location.column]
                ClipboardMonitorService.shared.pasteToFrontmostApp(item)
                SoundEffectsManager.shared.playLaunch()
                onActionExecuted?()
            }

        case .photos:
            if !recentPhotos.isEmpty {
                if location.column < recentPhotos.count {
                    let photo = recentPhotos[location.column]
                    openFileInApp(photo.url, app: app)
                    SoundEffectsManager.shared.playLaunch()
                    onActionExecuted?()
                }
            } else {
                executeGlanceAction(at: location.column, app: app, onActionExecuted: onActionExecuted)
            }

        case .media:
            if nowPlayingInfo != nil && location.row == 0 {
                togglePlayback()
                SoundEffectsManager.shared.playAction()
            } else if !recentDocuments.isEmpty {
                if location.column < recentDocuments.count {
                    let doc = recentDocuments[location.column]
                    openFileInApp(doc.url, app: app)
                    SoundEffectsManager.shared.playLaunch()
                    onActionExecuted?()
                }
            } else {
                executeGlanceAction(at: location.column, app: app, onActionExecuted: onActionExecuted)
            }

        case .developer:
            if !recentDevProjects.isEmpty {
                if location.column < recentDevProjects.count {
                    let project = recentDevProjects[location.column]
                    openFileInApp(project.url, app: app)
                    SoundEffectsManager.shared.playLaunch()
                    onActionExecuted?()
                }
            } else {
                executeGlanceAction(at: location.column, app: app, onActionExecuted: onActionExecuted)
            }

        case .documents:
            if !recentDocuments.isEmpty {
                if location.column < recentDocuments.count {
                    let doc = recentDocuments[location.column]
                    openFileInApp(doc.url, app: app)
                    SoundEffectsManager.shared.playLaunch()
                    onActionExecuted?()
                }
            } else {
                executeGlanceAction(at: location.column, app: app, onActionExecuted: onActionExecuted)
            }

        case .systemAction:
            if let action = app.systemAction {
                SystemActionService.shared.execute(action)
            } else if let windowAction = app.windowAction {
                WindowManagementService.shared.performAction(windowAction)
            }
            SoundEffectsManager.shared.playLaunch()
            onActionExecuted?()

        case .appGlance:
            executeGlanceAction(at: location.column, app: app, onActionExecuted: onActionExecuted)
        }
    }

    func executeGlanceAction(at column: Int, app: DiscoveredApp, onActionExecuted: (() -> Void)? = nil) {
        if column == 0 && app.url.isFileURL {
            NSWorkspace.shared.activateFileViewerSelecting([app.url])
            SoundEffectsManager.shared.playAction()
            onActionExecuted?()
        } else {
            NSPasteboard.general.clearContents()
            let path = app.url.isFileURL ? app.url.path : app.url.absoluteString
            NSPasteboard.general.setString(path, forType: .string)
            SoundEffectsManager.shared.playAction()
            onActionExecuted?()
        }
    }

    private func openFileInApp(_ fileURL: URL, app: DiscoveredApp) {
        if app.url.isFileURL {
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = false
            NSWorkspace.shared.open([fileURL], withApplicationAt: app.url, configuration: config) { _, _ in }
        } else {
            NSWorkspace.shared.open(fileURL)
        }
    }
}

