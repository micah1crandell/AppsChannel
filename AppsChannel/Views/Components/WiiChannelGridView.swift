import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Wii Paged Channel Grid View
struct WiiChannelGridView: View {
    let apps: [DiscoveredApp]
    let activeIndex: Int
    var isOrganizeMode: Bool = false
    let onSelect: (Int) -> Void
    let onLaunch: () -> Void
    let onNavigate: (Int) -> Void
    var onMoveApp: ((Int, Int) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var discoveryService = AppDiscoveryService.shared

    // Constants for 4x3 Grid
    private let columnsCount = 4
    private let rowsCount = 3
    private let pageSize = 12

    // Local Page Tracking
    @State private var currentPage: Int = 0
    @State private var hoveredSlotIndex: Int? = nil
    @State private var draggedAppIndex: Int? = nil
    @State private var dragTargetIndex: Int? = nil

    private var totalPages: Int {
        max(1, Int(ceil(Double(apps.count) / Double(pageSize))))
    }

    private var currentActivePage: Int {
        guard activeIndex >= 0 && activeIndex < apps.count else { return currentPage }
        return activeIndex / pageSize
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height

            // Calculate responsive tile dimensions
            let horizontalPadding: CGFloat = 64
            let verticalPadding: CGFloat = 80
            let gridWidth = max(400, availableWidth - (horizontalPadding * 2))
            let gridHeight = max(260, availableHeight - (verticalPadding * 2))

            let tileSpacingX: CGFloat = 16
            let tileSpacingY: CGFloat = 14

            let computedTileWidth = max(90, (gridWidth - (tileSpacingX * CGFloat(columnsCount - 1))) / CGFloat(columnsCount))
            let computedTileHeight = max(64, (gridHeight - (tileSpacingY * CGFloat(rowsCount - 1))) / CGFloat(rowsCount))

            // Keep realistic 16:11 aspect ratio
            let tileWidth = min(computedTileWidth, computedTileHeight * 1.48)
            let tileHeight = tileWidth / 1.48

            ZStack {
                // Main 4x3 Paged Matrix
                HStack(spacing: 0) {
                    VStack(spacing: tileSpacingY) {
                        ForEach(0..<rowsCount, id: \.self) { row in
                            HStack(spacing: tileSpacingX) {
                                ForEach(0..<columnsCount, id: \.self) { col in
                                    let slot = row * columnsCount + col
                                    let globalIndex = currentPage * pageSize + slot

                                    channelTileView(
                                        slot: slot,
                                        globalIndex: globalIndex,
                                        width: tileWidth,
                                        height: tileHeight
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Left Paging Chevron
                if currentPage > 0 {
                    HStack {
                        sidePagingChevron(isLeft: true) {
                            changePage(by: -1)
                        }
                        .padding(.leading, 12)
                        Spacer()
                    }
                    .transition(.opacity)
                }

                // Right Paging Chevron
                if currentPage < totalPages - 1 || isOrganizeMode {
                    HStack {
                        Spacer()
                        sidePagingChevron(isLeft: false) {
                            changePage(by: 1)
                        }
                        .padding(.trailing, 12)
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: availableWidth, height: availableHeight)
            .contentShape(Rectangle())
            .onAppear {
                syncPageWithActiveIndex()
            }
            .onChange(of: activeIndex) { _, newIndex in
                let targetPage = newIndex / pageSize
                if targetPage != currentPage && targetPage < totalPages {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        currentPage = targetPage
                    }
                }
            }
        }
    }

    // MARK: - Channel Tile (App Card or Empty Slot)
    @ViewBuilder
    private func channelTileView(slot: Int, globalIndex: Int, width: CGFloat, height: CGFloat) -> some View {
        let hasApp = globalIndex < apps.count
        let isSelected = hasApp && globalIndex == activeIndex
        let isHovered = hoveredSlotIndex == slot

        if hasApp {
            let app = apps[globalIndex]
            WiiBeveledChannelCard(
                app: app,
                isSelected: isSelected,
                isHovered: isHovered,
                width: width,
                height: height,
                isOrganizeMode: isOrganizeMode,
                onLaunch: onLaunch,
                onSelect: {
                    SoundEffectsManager.shared.playNavigation()
                    onSelect(globalIndex)
                }
            )
            .onHover { hovering in
                if hovering {
                    hoveredSlotIndex = slot
                } else if hoveredSlotIndex == slot {
                    hoveredSlotIndex = nil
                }
            }
            .onDrag {
                guard isOrganizeMode else { return NSItemProvider() }
                self.draggedAppIndex = globalIndex
                return NSItemProvider(object: String(globalIndex) as NSString)
            }
            .onDrop(of: [.text], delegate: WiiTileDropDelegate(
                targetIndex: globalIndex,
                draggedIndex: $draggedAppIndex,
                onMoveApp: onMoveApp
            ))
        } else {
            // Authentic Empty Channel Filler
            WiiEmptyChannelSlot(
                width: width,
                height: height,
                isHovered: isHovered && isOrganizeMode
            )
            .onHover { hovering in
                if hovering && isOrganizeMode {
                    hoveredSlotIndex = slot
                } else if hoveredSlotIndex == slot {
                    hoveredSlotIndex = nil
                }
            }
            .onDrop(of: [.text], delegate: WiiTileDropDelegate(
                targetIndex: min(apps.count, globalIndex),
                draggedIndex: $draggedAppIndex,
                onMoveApp: onMoveApp
            ))
        }
    }

    // MARK: - Side Paging Chevrons (Wii Glossy Cyan 3D Arrow)
    private func sidePagingChevron(isLeft: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            SoundEffectsManager.shared.playNavigation()
            action()
        }) {
            ZStack {
                // Soft blue ambient glow
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.05, green: 0.65, blue: 0.95).opacity(0.18))
                    .frame(width: 44, height: 64)
                    .blur(radius: 6)

                // 3D Beveled Cyan Chevron Pill
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.35, green: 0.85, blue: 1.0),
                                Color(red: 0.08, green: 0.58, blue: 0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 38, height: 56)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.9), Color.white.opacity(0.3)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: Color(red: 0.0, green: 0.45, blue: 0.85).opacity(0.4), radius: 6, x: 0, y: 3)

                // Inner Specular Arc
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: 34, height: 26)
                    .offset(y: -12)

                // Arrow Glyph
                Image(systemName: isLeft ? "chevron.left" : "chevron.right")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help(isLeft ? "Previous Channels Page" : "Next Channels Page")
    }

    private func changePage(by offset: Int) {
        let newPage = max(0, min(currentPage + offset, totalPages - 1))
        guard newPage != currentPage else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            currentPage = newPage
            let newActiveIndex = newPage * pageSize
            if newActiveIndex < apps.count {
                onSelect(newActiveIndex)
            }
        }
    }

    private func syncPageWithActiveIndex() {
        if activeIndex >= 0 && activeIndex < apps.count {
            let targetPage = activeIndex / pageSize
            if targetPage < totalPages {
                currentPage = targetPage
            }
        }
    }
}

// MARK: - Wii Beveled Channel Card
struct WiiBeveledChannelCard: View {
    let app: DiscoveredApp
    let isSelected: Bool
    let isHovered: Bool
    let width: CGFloat
    let height: CGFloat
    var isOrganizeMode: Bool = false
    let onLaunch: () -> Void
    let onSelect: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var discoveryService = AppDiscoveryService.shared

    private var outerCornerRadius: CGFloat { 14 }
    private var innerCornerRadius: CGFloat { 9 }

    // Dynamic lift & scale on focus or hover
    private var isEmphasized: Bool {
        isSelected || isHovered
    }

    var body: some View {
        Button(action: {
            if isSelected {
                onLaunch()
            } else {
                onSelect()
            }
        }) {
            ZStack {
                // Outer 3D Beveled Frame
                outerBeveledFrame

                // Inset Channel Screen
                ZStack {
                    // Inner Canvas Background
                    innerChannelCanvas

                    // Channel Content Banner with GIF/WebP and Procedural Animations
                    AnimatedChannelBannerView(
                        app: app,
                        width: width - 12,
                        height: height - 12,
                        isSelected: isSelected,
                        isHovered: isHovered
                    )

                    // Glass Specular Reflection Highlight Arc
                    glassReflectionArc
                }
                .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous))
                .padding(6) // Inset within the outer beveled bezel

                // Highlight Outline when focused/selected
                if isEmphasized {
                    RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.75, blue: 1.0),
                                    Color(red: 0.05, green: 0.55, blue: 0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                }
            }
            .frame(width: width, height: height)
            .scaleEffect(isEmphasized ? 1.04 : 1.0)
            .shadow(
                color: isEmphasized
                    ? Color(red: 0.0, green: 0.60, blue: 0.95).opacity(0.45)
                    : Color.black.opacity(0.18),
                radius: isEmphasized ? 10 : 4,
                x: 0,
                y: isEmphasized ? 4 : 2
            )
            .animation(reduceMotion ? .none : .spring(response: 0.28, dampingFraction: 0.78), value: isEmphasized)
        }
        .buttonStyle(.plain)
        .appContextMenu(for: app, onLaunch: onLaunch)
    }

    // MARK: - Outer 3D Beveled Plastic Frame
    private var outerBeveledFrame: some View {
        ZStack {
            // Main glossy white shell
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.99),
                            Color(white: 0.94),
                            Color(white: 0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Top-down specular bevel edge highlight
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0.0),
                            .init(color: Color(white: 0.92), location: 0.4),
                            .init(color: Color(white: 0.76), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )

            // Inner recess shadow groove
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.8)
                .padding(4.5)
        }
    }

    // MARK: - Inset Channel Canvas
    private var innerChannelCanvas: some View {
        ZStack {
            // Base backdrop: subtle off-white/cyan tint
            LinearGradient(
                colors: [
                    Color(white: 0.97),
                    Color(white: 0.91)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle scanline overlay
            WiiScanlineTexture()
                .opacity(0.04)

            // Dynamic category accent glow in bottom center
            RadialGradient(
                colors: [
                    app.accentColor.opacity(0.22),
                    Color.clear
                ],
                center: .bottom,
                startRadius: 0,
                endRadius: height * 0.75
            )
        }
    }

    // MARK: - Channel Content (Icon + Title + Badges)
    private var channelContent: some View {
        VStack(spacing: max(2, height * 0.03)) {
            Spacer().frame(height: 2)

            // App Icon with authentic subtle ground shadow
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: max(28, height * 0.44), height: max(28, height * 0.44))
                .shadow(color: Color.black.opacity(0.20), radius: 3, x: 0, y: 2)

            // Channel Title
            Text(app.name)
                .font(.system(size: max(8.5, min(12.5, width * 0.076)), weight: .bold, design: .rounded))
                .foregroundStyle(Color(white: 0.16))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 6)

            // Bottom Sub-Header / Running Status Pill
            HStack(spacing: 3) {
                if discoveryService.isRunning(app: app) {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.85, blue: 0.45))
                        .frame(width: 4, height: 4)
                        .shadow(color: Color(red: 0.15, green: 0.85, blue: 0.45).opacity(0.8), radius: 2)
                }

                Text(app.channelType != nil ? (app.channelType == .web ? "WEB" : "SHORTCUT") : app.category.uppercased())
                    .font(.system(size: max(6, width * 0.048), weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color(white: 0.42))
                    .lineLimit(1)
            }
            .padding(.bottom, max(4, height * 0.05))
        }
    }

    // MARK: - Glass Specular Highlight Arc
    private var glassReflectionArc: some View {
        VStack {
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.42), location: 0.0),
                    .init(color: .white.opacity(0.12), location: 0.55),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height * 0.42)
            .mask(
                // Curved arch shape simulating tubular glass
                Ellipse()
                    .scale(1.2)
                    .offset(y: -height * 0.15)
            )

            Spacer()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Wii Empty Channel Slot
struct WiiEmptyChannelSlot: View {
    let width: CGFloat
    let height: CGFloat
    var isHovered: Bool = false

    private var outerCornerRadius: CGFloat { 14 }
    private var innerCornerRadius: CGFloat { 9 }

    var body: some View {
        ZStack {
            // Beveled outer frame (same as active channel)
            RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.97), Color(white: 0.90)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: outerCornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white, Color(white: 0.75)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.2
                        )
                )

            // Inner Empty Channel Recess (Distinctive brushed scanlines)
            ZStack {
                // Silver/gray brushed well
                LinearGradient(
                    colors: [
                        Color(white: 0.88),
                        Color(white: 0.81)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Dense horizontal scanlines
                WiiScanlineTexture()
                    .opacity(0.12)

                // Glass Specular Highlight
                VStack {
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.35), location: 0.0),
                            .init(color: .white.opacity(0.05), location: 0.6),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: height * 0.4)

                    Spacer()
                }

                if isHovered {
                    RoundedRectangle(cornerRadius: innerCornerRadius)
                        .strokeBorder(Color(red: 0.05, green: 0.65, blue: 0.95), lineWidth: 2)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous))
            .padding(6)
        }
        .frame(width: width, height: height)
        .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 1.5)
    }
}

// MARK: - Procedural Scanline Texture (High-Performance GPU Canvas)
struct WiiScanlineTexture: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 3.0
            for y in stride(from: 0, to: size.height, by: step) {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(Color.black))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Tile Drop Delegate for Drag & Reorder
struct WiiTileDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var draggedIndex: Int?
    var onMoveApp: ((Int, Int) -> Void)?

    func dropEntered(info: DropInfo) {
        guard let from = draggedIndex, from != targetIndex else { return }
        onMoveApp?(from, targetIndex)
        draggedIndex = targetIndex
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedIndex = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
