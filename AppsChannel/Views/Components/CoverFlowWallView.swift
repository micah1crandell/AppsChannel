import SwiftUI
import AppKit

struct CoverFlowWallView: View {
    let apps: [DiscoveredApp]
    let activeIndex: Int
    var isCompact: Bool = false
    var isIconOnly: Bool = false
    var isOrganizeMode: Bool = false
    let onSelect: (Int) -> Void
    let onLaunch: () -> Void
    let onNavigate: (Int) -> Void
    var onMoveApp: ((Int, Int) -> Void)? = nil

    @State private var dragOffset: CGFloat = 0.0
    @State private var draggedIndex: Int? = nil

    private let rowsCount: Int = 3

    // Dynamic dimensions based on isIconOnly
    private var cardWidth: CGFloat {
        if isIconOnly {
            return isCompact ? 124 : 160
        } else {
            return isCompact ? 116 : 152
        }
    }

    private var cardHeight: CGFloat {
        if isIconOnly {
            return isCompact ? 134 : 168
        } else {
            return isCompact ? 148 : 192
        }
    }

    private var iconSize: CGFloat {
        if isIconOnly {
            return isCompact ? 94 : 124
        } else {
            return isCompact ? 46 : 60
        }
    }

    private var colSpacing: CGFloat {
        if isIconOnly {
            return isCompact ? 116 : 148
        } else {
            return isCompact ? 114 : 148
        }
    }

    private var rowSpacing: CGFloat {
        if isIconOnly {
            return isCompact ? 118 : 148
        } else {
            return isCompact ? 134 : 172
        }
    }

    private var totalHeight: CGFloat { isCompact ? 440 : 570 }

    private var totalColumns: Int {
        guard !apps.isEmpty else { return 0 }
        return Int(ceil(Double(apps.count) / Double(rowsCount)))
    }

    private var activeColumn: Int {
        guard !apps.isEmpty else { return 0 }
        return activeIndex / rowsCount
    }

    var body: some View {
        GeometryReader { proxy in
            let centerX = proxy.size.width / 2
            let centerY = proxy.size.height / 2

            ZStack {
                if apps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.3x3.topleft.filled")
                            .font(.system(size: isCompact ? 36 : 48))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("No applications found in this category")
                            .font(isCompact ? .subheadline : .headline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .position(x: centerX, y: centerY)
                } else {
                    // Render 3D Curved Cylindrical Wall of Cards
                    ForEach(0..<totalColumns, id: \.self) { col in
                        let colOffset = CGFloat(col - activeColumn) + (dragOffset / colSpacing)

                        // Performance cull: only render visible and nearby columns
                        if abs(colOffset) < (isCompact ? 4.8 : 5.4) {
                            let angle = calculateColumnRotation(offset: colOffset)
                            let posX = calculateColumnX(offset: colOffset, centerX: centerX)

                            ForEach(0..<rowsCount, id: \.self) { row in
                                let index = col * rowsCount + row
                                if index < apps.count {
                                    let app = apps[index]
                                    let isSelected = (index == activeIndex)
                                    let posY = calculateCardY(row: row, offset: colOffset, centerY: centerY)

                                    wallCard(app: app, index: index, isSelected: isSelected, row: row)
                                        .position(x: posX, y: posY)
                                        .zIndex(calculateZIndex(offset: colOffset, isSelected: isSelected))
                                        .scaleEffect(calculateScale(offset: colOffset, isSelected: isSelected))
                                        .rotation3DEffect(
                                            .degrees(angle),
                                            axis: (x: 0.0, y: 1.0, z: 0.0),
                                            anchor: .center,
                                            perspective: 0.35
                                        )
                                }
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = isCompact ? 36.0 : 50.0
                        if value.translation.width < -threshold {
                            onNavigate(rowsCount) // Next column
                        } else if value.translation.width > threshold {
                            onNavigate(-rowsCount) // Prev column
                        }
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                            dragOffset = 0
                        }
                    }
            )
        }
        .frame(height: totalHeight)
    }

    // MARK: - Individual Wall Cover Card (Apple Liquid Glass Style)
    private func wallCard(app: DiscoveredApp, index: Int, isSelected: Bool, row: Int) -> some View {
        VStack(spacing: 0) {
            if isIconOnly {
                // Pure App Icon Only Look (Properly scaled & tight spacing)
                VStack(spacing: isCompact ? 6 : 8) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                        .shadow(
                            color: isSelected ? app.accentColor.opacity(0.7) : Color.black.opacity(0.35),
                            radius: isSelected ? (isCompact ? 14 : 20) : 6,
                            x: 0,
                            y: isSelected ? 7 : 3
                        )
                        .overlay(
                            Group {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: iconSize * 0.225, style: .continuous)
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.white, Color.white.opacity(0.4)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: isCompact ? 1.8 : 2.2
                                        )
                                        .padding(isCompact ? -3 : -4)
                                }
                            }
                        )

                    Text(app.name)
                        .font(.system(size: isCompact ? 11 : 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.85), radius: 3, x: 0, y: 1.5)
                        .opacity(isSelected ? 1.0 : 0.85)
                }
                .frame(width: cardWidth, height: cardHeight)
                .scaleEffect(isSelected ? 1.08 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
                .contentShape(Rectangle())
            } else {
                // Classic Channel Card Look (Unified with Cover Flow AppCardView!)
                ChannelCardDesignView(
                    app: app,
                    isSelected: isSelected,
                    width: cardWidth,
                    height: cardHeight,
                    showFooter: true,
                    showHeader: true
                )
                .scaleEffect(isSelected ? 1.06 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
            }

            // Floor Reflection for Bottom Row Cards (smooth fade, zero cutoff line)
            if row == 2 && abs(CGFloat(index / rowsCount - activeColumn)) < 2.5 {
                reflectionView(for: app.icon)
                    .frame(width: cardWidth, height: isCompact ? 26 : 38)
                    .opacity(isSelected ? 0.32 : 0.14)
            } else {
                Spacer().frame(height: isCompact ? 26 : 38)
            }
        }
        .onTapGesture {
            if isSelected {
                onLaunch()
            } else {
                onSelect(index)
            }
        }
        .contextMenu {
            if !app.isAppsChannelApp {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([app.url])
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                }

                Divider()

                Button(role: .destructive) {
                    AppDiscoveryService.shared.hideApp(app)
                } label: {
                    Label("Hide from AppsChannel", systemImage: "eye.slash")
                }
            }
        }
    }

    private func reflectionView(for icon: NSImage) -> some View {
        VStack {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: isCompact ? 38 : 54, height: isCompact ? 38 : 54)
                .scaleEffect(y: -1)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.12), location: 0.45),
                            .init(color: .white.opacity(0.65), location: 1.0)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
        }
        .padding(.top, 2)
    }

    // MARK: - 3D Geometry Mathematics for Concave Amphitheater Wall Perspective (Wii Flow / IMAX Style)
    private func calculateColumnRotation(offset: CGFloat) -> Double {
        if abs(offset) < 0.001 { return 0 }
        // Inward facing angle: negative for right side (faces left toward center), positive for left side (faces right toward center)
        let angleStep: Double = isCompact ? 10.5 : 12.8
        let rawAngle = -Double(offset) * angleStep
        return max(-50.0, min(50.0, rawAngle))
    }

    private func calculateScale(offset: CGFloat, isSelected: Bool) -> CGFloat {
        // Concave curvature: sides wrap forward closer to viewer with tight, controlled growth
        let absOffset = Double(abs(offset))
        let growth = pow(absOffset, 1.10) * 0.045
        let baseScale = CGFloat(min(1.22, 1.0 + growth))
        return isSelected ? baseScale * 1.06 : baseScale
    }

    private func calculateZIndex(offset: CGFloat, isSelected: Bool) -> Double {
        if isSelected { return 500.0 }
        // Outer wrapping columns are physically closer to the viewer
        return 100.0 + Double(abs(offset)) * 20.0
    }

    private func calculateColumnX(offset: CGFloat, centerX: CGFloat) -> CGFloat {
        let sign: CGFloat = offset >= 0 ? 1.0 : -1.0
        let absOffset = abs(offset)
        let projected = absOffset * (colSpacing * 0.92) - CGFloat(pow(Double(absOffset), 1.35) * 1.5)
        return centerX + sign * projected
    }

    private func calculateCardY(row: Int, offset: CGFloat, centerY: CGFloat) -> CGFloat {
        // Subtle perspective flare: gentle upward/downward curve on outer columns without spreading rows far apart
        let absOffset = Double(abs(offset))
        let verticalFlare = 1.0 + (pow(absOffset, 1.12) * 0.030)
        return centerY + CGFloat(row - 1) * (rowSpacing * CGFloat(verticalFlare))
    }
}
