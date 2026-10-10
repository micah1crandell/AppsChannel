import SwiftUI
import Combine

struct RetroHUDView: View {
    @Binding var searchText: String
    @Binding var selectedCategory: String
    @Binding var layoutMode: MainLayoutViewMode
    let categories: [String]
    let totalAppsCount: Int
    let selectedApp: DiscoveredApp?
    let onLaunch: () -> Void
    let onDismiss: () -> Void
    let onPrevious: () -> Void
    let onNext: () -> Void
    var onNavigateStep: ((Int) -> Void)? = nil
    var onSwitchToQuick: (() -> Void)? = nil
    var onOpenSettings: (() -> Void)? = nil
    var onToggleOrganize: (() -> Void)? = nil
    var isOrganizeMode: Bool = false
    var onToggleRecentDocuments: (() -> Void)? = nil
    var onAddCustomChannel: (() -> Void)? = nil

    @FocusState private var isSearchFocused: Bool
    @AppStorage("threeDSGridRows") private var threeDSGridRows: Int = 3

    private var topPadding: CGFloat { 20 }

    var body: some View {
        VStack {
            topHUD
            Spacer()
            bottomHUD
        }
        .padding(.horizontal, 24)
        .padding(.top, topPadding)
        .padding(.bottom, 20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidShow)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFocused = true
            }
        }
    }

    // MARK: - Top Modern Liquid Glass Capsule
    private var topHUD: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                // Reserved space for native macOS Traffic Light controls (Close, Minimize, Zoom)
                Spacer().frame(width: 54)

                // Liquid Glass Search Field (Automatically Focused)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))

                    TextField("Type to search apps...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .focused($isSearchFocused)
                        .onSubmit {
                            onLaunch()
                        }
                        .onKeyPress(.return) {
                            onLaunch()
                            return .handled
                        }
                        .onKeyPress(.leftArrow) {
                            if !searchText.isEmpty {
                                return .ignored
                            }
                            let step: Int = {
                                switch layoutMode {
                                case .coverFlow: return -1
                                case .gridWall: return -3
                                case .flatGrid: return -threeDSGridRows
                                }
                            }()
                            if let onNavigateStep = onNavigateStep {
                                onNavigateStep(step)
                            } else {
                                onPrevious()
                            }
                            return .handled
                        }
                        .onKeyPress(.rightArrow) {
                            if !searchText.isEmpty {
                                return .ignored
                            }
                            let step: Int = {
                                switch layoutMode {
                                case .coverFlow: return 1
                                case .gridWall: return 3
                                case .flatGrid: return threeDSGridRows
                                }
                            }()
                            if let onNavigateStep = onNavigateStep {
                                onNavigateStep(step)
                            } else {
                                onNext()
                            }
                            return .handled
                        }
                        .onKeyPress(.downArrow) {
                            if let onNavigateStep = onNavigateStep {
                                onNavigateStep(1)
                            } else {
                                onNext()
                            }
                            return .handled
                        }
                        .onKeyPress(.upArrow) {
                            if let onNavigateStep = onNavigateStep {
                                onNavigateStep(-1)
                            } else {
                                onPrevious()
                            }
                            return .handled
                        }
                        .onKeyPress(.escape) {
                            if !searchText.isEmpty {
                                searchText = ""
                            } else {
                                onDismiss()
                            }
                            return .handled
                        }

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minWidth: 180, maxWidth: 300)
                .background(Color(white: 0.08).opacity(0.85), in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                )

                Spacer()

                // Rearrange Channels Icon Button
                if let onOrganize = onToggleOrganize {
                    Button(action: onOrganize) {
                        Image(systemName: isOrganizeMode ? "checkmark.circle.fill" : "arrow.left.arrow.right.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isOrganizeMode ? Color.green : Color.white.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .background(isOrganizeMode ? Color.green.opacity(0.25) : Color(white: 0.08).opacity(0.85), in: Circle())
                            .overlay(
                                Circle().strokeBorder(isOrganizeMode ? Color.green.opacity(0.6) : Color.white.opacity(0.22), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(isOrganizeMode ? "Done Arranging" : "Rearrange Channels")
                }

                // Layout View Mode Switcher: Cover Flow vs Wall Grid vs Flat Grid
                HStack(spacing: 2) {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            layoutMode = .coverFlow
                        }
                    }) {
                        Image(systemName: "rectangle.portrait.on.rectangle.portrait.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(layoutMode == .coverFlow ? Color.black : Color.white.opacity(0.75))
                            .frame(width: 28, height: 26)
                            .background(layoutMode == .coverFlow ? Color.white : Color.clear, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                    .help("Cover Flow (⌘V)")

                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            layoutMode = .gridWall
                        }
                    }) {
                        Image(systemName: "square.grid.3x3.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(layoutMode == .gridWall ? Color.black : Color.white.opacity(0.75))
                            .frame(width: 28, height: 26)
                            .background(layoutMode == .gridWall ? Color.white : Color.clear, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                    .help("Curved Wall Grid (⌘V)")

                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            layoutMode = .flatGrid
                        }
                    }) {
                        Image(systemName: "square.grid.3x2.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(layoutMode == .flatGrid ? Color.black : Color.white.opacity(0.75))
                            .frame(width: 28, height: 26)
                            .background(layoutMode == .flatGrid ? Color.white : Color.clear, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Capsule())
                    .help("Flat Grid (⌘V)")
                }
                .padding(3)
                .background(Color(white: 0.08).opacity(0.85), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1))

                // Switch to Quick Launcher Icon Button
                if let onSwitch = onSwitchToQuick {
                    Button(action: onSwitch) {
                        Image(systemName: "rectangle.inset.filled.and.cursorarrow")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .background(Color(white: 0.08).opacity(0.85), in: Circle())
                            .overlay(
                                Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Quick Launcher (⌘O)")
                }

                // Settings Button
                if let onSettings = onOpenSettings {
                    Button(action: onSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .background(Color(white: 0.08).opacity(0.85), in: Circle())
                            .overlay(
                                Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }

                // Dismiss button
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(Color(white: 0.08).opacity(0.85), in: Circle())
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help("Dismiss (⎋)")
            }

            // Category Filter Pills with Direct Command Shortcuts (⌘1, ⌘2, etc.)
            HStack(spacing: 5) {
                ForEach(Array(categories.enumerated()), id: \.element) { index, category in
                    let isSelected = selectedCategory == category
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedCategory = category
                        }
                    }) {
                        HStack(spacing: 3.5) {
                            if index < 8 {
                                Text("⌘\(index + 1)")
                                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.85))
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 2.5))
                            }

                            Text(category)
                                .font(.system(size: 9.5, weight: isSelected ? .bold : .semibold))
                                .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.75))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            Group {
                                if isSelected {
                                    Capsule().fill(Color.white)
                                } else {
                                    Capsule().fill(Color(white: 0.08).opacity(0.85))
                                }
                            }
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? Color.white : Color.white.opacity(0.18),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Bottom Modern Liquid Glass Deck
    private var bottomHUD: some View {
        HStack(spacing: 20) {
            // Selected App Location & Info
            if let app = selectedApp {
                if app.isSeparator {
                    HStack(spacing: 12) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hidden Apps Section")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)

                            Text("Hidden applications matching search query")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.08).opacity(0.88), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
                    )
                } else {
                    HStack(spacing: 12) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(app.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)

                                if app.isHiddenApp {
                                    HStack(spacing: 3) {
                                        Image(systemName: "eye.slash.fill")
                                            .font(.system(size: 8.5))
                                        Text("Hidden")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(Color.orange.opacity(0.18), in: Capsule())
                                }
                            }

                            Text(app.channelType != nil ? app.url.absoluteString : app.url.path)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.08).opacity(0.88), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    )

                    if app.channelType == nil && !app.isSeparator && !app.isAppsChannelApp && RecentDocumentsService.hasDocumentTypes(forAppAt: app.url),
                       let onToggleRecent = onToggleRecentDocuments {
                        Button(action: onToggleRecent) {
                            HStack(spacing: 5) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 11, weight: .bold))
                                Text("Recent (⌘↓)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(white: 0.08).opacity(0.88), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Show recent documents for this app (⌘↓)")
                    }
                }
            }

            Spacer()

            // System Storage & Status Pill
            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Text(diskFreeDescription())
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Divider()
                    .frame(height: 12)
                    .background(.white.opacity(0.2))

                // Action Pills
                HStack(spacing: 8) {
                    if isOrganizeMode, let onAdd = onAddCustomChannel {
                        Button(action: onAdd) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add Channel")
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    keyboardShortcutBadge(key: "⌘1-8", label: "Groups")
                    keyboardShortcutBadge(key: "⌥1-9", label: "Quick Launch")
                    keyboardShortcutBadge(key: "⌘V", label: "View")
                    keyboardShortcutBadge(key: "↵", label: "Open")
                    keyboardShortcutBadge(key: "⎋", label: "Close")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(white: 0.08).opacity(0.88), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
            )

            // Primary Launch / Next Button
            Button(action: onLaunch) {
                HStack(spacing: 8) {
                    if selectedApp?.isSeparator == true {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Next App")
                            .font(.system(size: 13, weight: .bold))
                    } else {
                        Image(systemName: "arrow.up.forward.app.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Launch")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(selectedApp?.isSeparator == true ? Color.orange : Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(selectedApp?.isSeparator == true ? Color.orange : Color.white, lineWidth: 1)
                )
                .shadow(color: (selectedApp?.isSeparator == true ? Color.orange : Color.white).opacity(0.25), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    private func keyboardShortcutBadge(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func diskFreeDescription() -> String {
        let fileManager = FileManager.default
        if let attrs = try? fileManager.attributesOfFileSystem(forPath: "/"),
           let freeSize = attrs[.systemFreeSize] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "\(formatter.string(fromByteCount: freeSize)) free"
        }
        return "macOS Ready"
    }
}
