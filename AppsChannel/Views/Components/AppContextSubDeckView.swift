import SwiftUI
import AppKit

struct AppContextSubDeckView: View {
    let app: DiscoveredApp
    let onClose: () -> Void

    @ObservedObject private var service = AppContextSubDeckService.shared
    @ObservedObject private var clipboardService = ClipboardMonitorService.shared
    @State private var hoveredItemId: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Header Bar
            headerBar

            // MARK: - Polymorphic Content Area
            if service.isLoading {
                loadingView
            } else {
                switch service.contextKind {
                case .clipboard:
                    clipboardContentView
                case .browser:
                    browserContentView
                case .photos:
                    photosContentView
                case .media:
                    mediaContentView
                case .developer:
                    developerContentView
                case .documents:
                    documentsContentView
                case .systemAction:
                    systemActionContentView
                case .appGlance:
                    appGlanceContentView
                }
            }
        }
        .padding(14)
        .frame(maxWidth: 680)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.12).opacity(0.96), Color(white: 0.06).opacity(0.98)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.55), radius: 20, x: 0, y: 10)
        .task(id: app.id) {
            await service.loadContext(for: app)
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            HStack(spacing: 7) {
                Image(systemName: service.contextKind.systemIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(app.accentColor)

                Text(app.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("•")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))

                Text(service.contextKind.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

                itemCountBadge
            }

            Spacer()

            Text("⌘↑ to close")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.trailing, 6)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var itemCountBadge: some View {
        let count: Int = {
            switch service.contextKind {
            case .clipboard: return clipboardService.items.count
            case .browser: return service.recentDownloads.count
            case .photos: return service.recentPhotos.count
            case .media: return service.recentDocuments.count
            case .developer: return service.recentDevProjects.count
            case .documents: return service.recentDocuments.count
            case .systemAction, .appGlance: return 0
            }
        }()

        if count > 0 {
            Text("\(count)")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.15), in: Capsule())
        }
    }

    // MARK: - Loading Indicator
    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Gathering context for \(app.name)...")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 65)
    }

    // MARK: - Clipboard Deck Content
    private var clipboardContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if clipboardService.items.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("No clippings captured yet. Copy text or images anywhere to see them here.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity, minHeight: 65)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(clipboardService.items.prefix(8)) { item in
                            ClipboardDeckTile(
                                item: item,
                                isHovered: hoveredItemId == item.id,
                                onPaste: {
                                    clipboardService.pasteToFrontmostApp(item)
                                    SoundEffectsManager.shared.playLaunch()
                                    onClose()
                                },
                                onCopy: {
                                    clipboardService.copyToPasteboard(item)
                                    SoundEffectsManager.shared.playAction()
                                }
                            )
                            .onHover { isHovered in
                                hoveredItemId = isHovered ? item.id : nil
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Web Browser Deck Content
    private var browserContentView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Quick Browser Action Buttons
            HStack(spacing: 8) {
                Button {
                    service.launchBrowserNewWindow(app: app)
                    SoundEffectsManager.shared.playLaunch()
                    onClose()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.rectangle.on.rectangle")
                        Text("New Window")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    service.launchBrowserPrivateWindow(app: app)
                    SoundEffectsManager.shared.playLaunch()
                    onClose()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "eye.slash.fill")
                        Text("Private Window")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    service.launchWebSearch()
                    SoundEffectsManager.shared.playLaunch()
                    onClose()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass")
                        Text("Google Search")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()
            }

            // Recent Downloads
            if !service.recentDownloads.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Downloads")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(service.recentDownloads) { download in
                                BrowserDownloadTile(
                                    download: download,
                                    isHovered: hoveredItemId == download.id,
                                    onOpen: {
                                        NSWorkspace.shared.open(download.url)
                                        SoundEffectsManager.shared.playLaunch()
                                        onClose()
                                    }
                                )
                                .onHover { isHovered in
                                    hoveredItemId = isHovered ? download.id : nil
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    // MARK: - Photos & Graphics Deck Content
    private var photosContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if service.recentPhotos.isEmpty {
                appGlanceContentView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(service.recentPhotos) { photo in
                            PhotoDeckTile(
                                photo: photo,
                                isHovered: hoveredItemId == photo.id,
                                onOpen: {
                                    openFileInApp(photo.url)
                                }
                            )
                            .onHover { isHovered in
                                hoveredItemId = isHovered ? photo.id : nil
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Media Deck Content
    private var mediaContentView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let nowPlaying = service.nowPlayingInfo {
                HStack(spacing: 12) {
                    Image(systemName: nowPlaying.isPlaying ? "waveform" : "pause.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(app.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(nowPlaying.trackName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(nowPlaying.artistName)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.8))

                            if let album = nowPlaying.albumName {
                                Text("• \(album)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.white.opacity(0.5))
                                    .lineLimit(1)
                            }
                        }
                    }

                    Spacer()

                    Button {
                        service.togglePlayback()
                    } label: {
                        Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.18), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if !service.recentDocuments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(service.recentDocuments) { doc in
                            RecentDocumentTile(
                                doc: doc,
                                isHovered: hoveredItemId == doc.id,
                                onOpen: {
                                    openFileInApp(doc.url)
                                }
                            )
                            .onHover { isHovered in
                                hoveredItemId = isHovered ? doc.id : nil
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else if service.nowPlayingInfo == nil {
                appGlanceContentView
            }
        }
    }

    // MARK: - Developer Deck Content
    private var developerContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if service.recentDevProjects.isEmpty {
                appGlanceContentView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(service.recentDevProjects) { project in
                            DevProjectDeckTile(
                                project: project,
                                isHovered: hoveredItemId == project.id,
                                onOpen: {
                                    openFileInApp(project.url)
                                }
                            )
                            .onHover { isHovered in
                                hoveredItemId = isHovered ? project.id : nil
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Documents Deck Content
    private var documentsContentView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if service.recentDocuments.isEmpty {
                appGlanceContentView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(service.recentDocuments) { doc in
                            RecentDocumentTile(
                                doc: doc,
                                isHovered: hoveredItemId == doc.id,
                                onOpen: {
                                    openFileInApp(doc.url)
                                }
                            )
                            .onHover { isHovered in
                                hoveredItemId = isHovered ? doc.id : nil
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - System Action Deck Content
    private var systemActionContentView: some View {
        HStack(spacing: 14) {
            Image(systemName: app.systemAction?.iconSymbolName ?? "macwindow.on.rectangle")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(app.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.white.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(app.systemAction?.subtitle ?? app.windowAction?.title ?? "System level trigger")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.65))
            }

            Spacer()

            Button {
                if let action = app.systemAction {
                    SystemActionService.shared.execute(action)
                } else if let windowAction = app.windowAction {
                    WindowManagementService.shared.performAction(windowAction)
                }
                SoundEffectsManager.shared.playLaunch()
                onClose()
            } label: {
                Text("Execute Action")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(app.accentColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Universal App Glance Deck Content
    private var appGlanceContentView: some View {
        VStack(alignment: .leading, spacing: 10) {
            let glance = service.appGlanceInfo ?? AppContextSubDeckService.extractGlanceInfo(for: app)

            // 4 Metrics Grid
            HStack(spacing: 10) {
                MetricChip(
                    icon: "cpu",
                    label: "Architecture",
                    value: glance.architectureBadge
                )
                MetricChip(
                    icon: "tag",
                    label: "Version",
                    value: glance.versionString
                )
                MetricChip(
                    icon: "internaldrive",
                    label: "Disk Size",
                    value: glance.bundleSizeString
                )
                MetricChip(
                    icon: "circle.fill",
                    label: "Process State",
                    value: glance.isRunning ? "Active" : "Inactive",
                    valueColor: glance.isRunning ? Color.green : Color.white.opacity(0.7)
                )
            }

            // Quick Actions & Usage Row
            HStack {
                HStack(spacing: 8) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([app.url])
                        SoundEffectsManager.shared.playAction()
                        onClose()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                            Text("Reveal (⌘↵)")
                        }
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(app.url.path, forType: .string)
                        SoundEffectsManager.shared.playAction()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Path (⇧↵)")
                        }
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 9))
                    Text("\(glance.launchCount) launches • \(glance.lastLaunchedText)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func openFileInApp(_ fileURL: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = false
        NSWorkspace.shared.open([fileURL], withApplicationAt: app.url, configuration: config) { _, _ in }
        SoundEffectsManager.shared.playLaunch()
        onClose()
    }
}

// MARK: - Metric Chip View
private struct MetricChip: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.5))
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

// MARK: - Specialized Sub-Deck Tiles

private struct ClipboardDeckTile: View {
    let item: ClipboardItem
    let isHovered: Bool
    let onPaste: () -> Void
    let onCopy: () -> Void

    var body: some View {
        Button(action: onPaste) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Image(systemName: item.type.systemIcon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(item.type.accentColor)

                    Text(item.type.rawValue)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    Text(item.formattedRelativeTime)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }

                if item.type == .color, let hex = item.colorHex {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: hex) ?? .gray)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        Text(hex)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .frame(height: 32)
                } else {
                    Text(item.previewText)
                        .font(.system(size: 10, design: item.type == .code ? .monospaced : .default))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .frame(height: 32, alignment: .topLeading)
                }

                HStack {
                    Text("↵ Paste")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12), in: Capsule())

                    Spacer()

                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(9)
            .frame(width: 140, height: 86)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.16 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(isHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PhotoDeckTile: View {
    let photo: PhotoDeckItem
    let isHovered: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 5) {
                Image(nsImage: photo.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)

                Text(photo.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: 86)

                if let dims = photo.pixelDimensions {
                    Text(dims)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.blue.opacity(0.9))
                } else {
                    Text(photo.formattedRelativeDate)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.16 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct DevProjectDeckTile: View {
    let project: DevProjectItem
    let isHovered: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 5) {
                Image(nsImage: project.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)

                Text(project.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: 90)

                Text(project.projectKind)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.orange.opacity(0.9))
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.16 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct BrowserDownloadTile: View {
    let download: BrowserDownloadItem
    let isHovered: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 5) {
                Image(nsImage: download.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 34, height: 34)

                Text(download.name)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(width: 86)

                Text(download.formattedSize)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.16 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct RecentDocumentTile: View {
    let doc: RecentDocumentItem
    let isHovered: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 6) {
                Image(nsImage: doc.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)

                Text(doc.name)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 82)

                Text(doc.formattedRelativeDate)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.16 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isHovered ? Color.white.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
