import SwiftUI
import AppKit

struct CoverFlowWallView: View {
    let apps: [DiscoveredApp]
    let activeIndex: Int
    var isCompact: Bool = false
    var isOrganizeMode: Bool = false
    let onSelect: (Int) -> Void
    let onLaunch: () -> Void
    let onNavigate: (Int) -> Void
    var onMoveApp: ((Int, Int) -> Void)? = nil

    @State private var dragOffset: CGFloat = 0.0
    @State private var draggedIndex: Int? = nil

    private let rowsCount: Int = 3
    private var cardWidth: CGFloat { isCompact ? 104 : 138 }
    private var cardHeight: CGFloat { isCompact ? 128 : 176 }
    private var iconSize: CGFloat { isCompact ? 42 : 58 }
    private var colSpacing: CGFloat { isCompact ? 120 : 158 }
    private var rowSpacing: CGFloat { isCompact ? 138 : 192 }
    private var totalHeight: CGFloat { isCompact ? 440 : 590 }

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
                        if abs(colOffset) < (isCompact ? 4.8 : 5.2) {
                            let angle = calculateColumnRotation(offset: colOffset)
                            let posX = centerX + colOffset * (colSpacing * 0.94)

                            ForEach(0..<rowsCount, id: \.self) { row in
                                let index = col * rowsCount + row
                                if index < apps.count {
                                    let app = apps[index]
                                    let isSelected = (index == activeIndex)
                                    let posY = centerY + CGFloat(row - 1) * rowSpacing

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
            VStack(spacing: isCompact ? 4 : 6) {
                // Top Header Pill: Channel Slot / Quick Shortcut Badge
                HStack(spacing: 4) {
                    if index < 9 {
                        Text("⌥\(index + 1)")
                            .font(.system(size: isCompact ? 7.5 : 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color.cyan, in: Capsule())
                    } else {
                        Text("CH \(index + 1)")
                            .font(.system(size: isCompact ? 7.5 : 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }

                    Spacer()

                    Circle()
                        .fill(app.accentColor)
                        .frame(width: isCompact ? 3.5 : 4, height: isCompact ? 3.5 : 4)
                }
                .padding(.horizontal, isCompact ? 6 : 8)
                .padding(.top, isCompact ? 5 : 7)

                // App Icon with specular shadow
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .shadow(color: isSelected ? app.accentColor.opacity(0.65) : Color.black.opacity(0.4), radius: isSelected ? (isCompact ? 8 : 10) : 4, x: 0, y: 3)
                    .padding(.top, 1)

                // App Title
                Text(app.name)
                    .font(.system(size: isCompact ? 9.5 : 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 4)

                // Category Tag Pill
                Text(app.category)
                    .font(.system(size: isCompact ? 6.5 : 7.5, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .padding(.bottom, isCompact ? 4 : 6)
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 13 : 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isSelected ?
                                [Color(white: 0.22).opacity(0.96), Color(white: 0.10).opacity(0.98)] :
                                [Color(white: 0.16).opacity(0.88), Color(white: 0.08).opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: isCompact ? 13 : 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isSelected ?
                                [Color.white, app.accentColor, Color.cyan] :
                                [Color.white.opacity(0.2), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? (isCompact ? 1.6 : 2.0) : 0.8
                    )
            )
            .shadow(
                color: isSelected ? app.accentColor.opacity(0.45) : Color.black.opacity(0.3),
                radius: isSelected ? (isCompact ? 12 : 16) : 8,
                x: 0,
                y: isSelected ? 6 : 3
            )

            // Floor Reflection for Bottom Row Cards (smooth fade, zero cutoff line)
            if row == 2 && abs(CGFloat(index / rowsCount - activeColumn)) < 2.5 {
                reflectionView(for: app.icon)
                    .frame(width: cardWidth, height: isCompact ? 22 : 32)
                    .opacity(isSelected ? 0.32 : 0.14)
            } else {
                Spacer().frame(height: isCompact ? 22 : 32)
            }
        }
        .onTapGesture {
            if isSelected {
                onLaunch()
            } else {
                onSelect(index)
            }
        }
    }

    private func reflectionView(for icon: NSImage) -> some View {
        VStack {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: isCompact ? 30 : 42, height: isCompact ? 30 : 42)
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

    // MARK: - 3D Geometry Mathematics for Curved Cylindrical Perspective
    private func calculateColumnRotation(offset: CGFloat) -> Double {
        if abs(offset) < 0.001 { return 0 }
        let angleStep: Double = isCompact ? -7.5 : -8.5
        let rawAngle = Double(offset) * angleStep
        return max(-38.0, min(38.0, rawAngle))
    }

    private func calculateScale(offset: CGFloat, isSelected: Bool) -> CGFloat {
        let baseScale = max(0.84, 1.0 - (abs(offset) * 0.035))
        return isSelected ? baseScale * 1.06 : baseScale
    }

    private func calculateZIndex(offset: CGFloat, isSelected: Bool) -> Double {
        if isSelected { return 200.0 }
        return 100.0 - Double(abs(offset)) * 10.0
    }
}
