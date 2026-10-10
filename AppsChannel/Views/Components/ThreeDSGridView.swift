import SwiftUI
import AppKit

struct ThreeDSGridView: View {
    let apps: [DiscoveredApp]
    let activeIndex: Int
    let rowsCount: Int
    var isCompact: Bool = false
    var isIconOnly: Bool = false
    var isOrganizeMode: Bool = false
    let onSelect: (Int) -> Void
    let onLaunch: () -> Void
    let onNavigate: (Int) -> Void
    var onMoveApp: ((Int, Int) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var dragOffset: CGFloat = 0.0

    private var effectiveRows: Int {
        max(1, min(rowsCount, 5))
    }

    private var tileSize: CGFloat {
        if isCompact {
            switch effectiveRows {
            case 1: return 118
            case 2: return 92
            case 3: return 70
            case 4: return 54
            default: return 44
            }
        } else {
            switch effectiveRows {
            case 1: return 164
            case 2: return 126
            case 3: return 96
            case 4: return 78
            default: return 64
            }
        }
    }

    private var cardWidth: CGFloat {
        if isCompact {
            switch effectiveRows {
            case 1: return 168
            case 2: return 110
            case 3: return 84
            case 4: return 68
            default: return 56
            }
        } else {
            switch effectiveRows {
            case 1: return 220
            case 2: return 144
            case 3: return 112
            case 4: return 88
            default: return 74
            }
        }
    }

    private var cardHeight: CGFloat {
        if isCompact {
            switch effectiveRows {
            case 1: return 210
            case 2: return 138
            case 3: return 106
            case 4: return 86
            default: return 72
            }
        } else {
            switch effectiveRows {
            case 1: return 275
            case 2: return 180
            case 3: return 140
            case 4: return 112
            default: return 94
            }
        }
    }

    private var tileSpacing: CGFloat {
        if isCompact {
            switch effectiveRows {
            case 1: return 18
            case 2: return 13
            case 3: return 10
            case 4: return 8
            default: return 6
            }
        } else {
            switch effectiveRows {
            case 1: return 24
            case 2: return 18
            case 3: return 14
            case 4: return 10
            default: return 8
            }
        }
    }

    private var cardHSpacing: CGFloat {
        if isCompact {
            switch effectiveRows {
            case 1: return 18
            case 2: return 14
            case 3: return 10
            case 4: return 8
            default: return 6
            }
        } else {
            switch effectiveRows {
            case 1: return 26
            case 2: return 18
            case 3: return 14
            case 4: return 10
            default: return 8
            }
        }
    }

    private var cardVSpacing: CGFloat {
        if isCompact {
            switch effectiveRows {
            case 1: return 16
            case 2: return 12
            case 3: return 8
            case 4: return 6
            default: return 5
            }
        } else {
            switch effectiveRows {
            case 1: return 24
            case 2: return 16
            case 3: return 12
            case 4: return 10
            default: return 8
            }
        }
    }

    private var itemWidth: CGFloat {
        isIconOnly ? tileSize : cardWidth
    }

    private var itemHeight: CGFloat {
        isIconOnly ? tileSize : cardHeight
    }

    private var colStep: CGFloat {
        isIconOnly ? (tileSize + tileSpacing) : (cardWidth + cardHSpacing)
    }

    private var rowStep: CGFloat {
        isIconOnly ? (tileSize + tileSpacing) : (cardHeight + cardVSpacing)
    }

    private var totalColumns: Int {
        guard !apps.isEmpty else { return 0 }
        return Int(ceil(Double(apps.count) / Double(effectiveRows)))
    }

    private var activeColumn: Int {
        guard !apps.isEmpty else { return 0 }
        return activeIndex / effectiveRows
    }

    private var activeRow: Int {
        guard !apps.isEmpty else { return 0 }
        return activeIndex % effectiveRows
    }

    private var totalHeight: CGFloat {
        isCompact ? 360 : 500
    }

    var body: some View {
        GeometryReader { proxy in
            let centerX = proxy.size.width / 2
            let centerY = proxy.size.height / 2

            ZStack {
                if apps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.3x2.fill")
                            .font(.system(size: isCompact ? 36 : 48))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("No matching applications found")
                            .font(isCompact ? .subheadline : .headline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .position(x: centerX, y: centerY)
                } else {
                    // Floating Speech Bubble Tooltip above active column (3DS Style)
                    if activeIndex < apps.count {
                        let activeApp = apps[activeIndex]
                        let bubbleY = centerY - (CGFloat(effectiveRows) * rowStep) / 2 - (isCompact ? 28 : 36)

                        speechBubble(for: activeApp)
                            .position(x: centerX, y: max(bubbleY, isCompact ? 30 : 42))
                            .zIndex(300)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    }

                    // Flat 3DS Horizontal App Grid
                    ForEach(0..<totalColumns, id: \.self) { col in
                        let colOffset = CGFloat(col - activeColumn) + (dragOffset / colStep)

                        // Cull out-of-view columns for high performance
                        if abs(colOffset) < (isCompact ? 4.5 : 5.8) {
                            let posX = centerX + colOffset * colStep

                            ForEach(0..<effectiveRows, id: \.self) { row in
                                let index = col * effectiveRows + row
                                if index < apps.count {
                                    let app = apps[index]
                                    let isSelected = (index == activeIndex)
                                    let rowOffsetFromCenter = CGFloat(row) - CGFloat(effectiveRows - 1) / 2.0
                                    let posY = centerY + rowOffsetFromCenter * rowStep + (isCompact ? 12 : 16)

                                    threeDSTile(app: app, index: index, isSelected: isSelected)
                                        .position(x: posX, y: posY)
                                        .zIndex(isSelected ? 200 : 100 - Double(abs(colOffset)))
                                }
                            }
                        }
                    }

                    // 3DS Side Arrow Navigation Buttons (<- and ->)
                    if activeColumn > 0 {
                        Button(action: {
                            onNavigate(-effectiveRows)
                        }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: isCompact ? 24 : 30))
                                .foregroundStyle(Color.white.opacity(0.65))
                                .background(Color.black.opacity(0.4), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .position(x: 36, y: centerY)
                        .zIndex(250)
                    }

                    if activeColumn < totalColumns - 1 {
                        Button(action: {
                            onNavigate(effectiveRows)
                        }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: isCompact ? 24 : 30))
                                .foregroundStyle(Color.white.opacity(0.65))
                                .background(Color.black.opacity(0.4), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .position(x: proxy.size.width - 36, y: centerY)
                        .zIndex(250)
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
                        let threshold: CGFloat = colStep * 0.35
                        if value.translation.width < -threshold {
                            onNavigate(effectiveRows)
                        } else if value.translation.width > threshold {
                            onNavigate(-effectiveRows)
                        }
                        withAnimation(.responsive(reduceMotion: reduceMotion, spring: .spring(response: 0.30, dampingFraction: 0.85))) {
                            dragOffset = 0
                        }
                    }
            )
        }
        .frame(height: totalHeight)
    }

    // MARK: - Individual 3DS App Tile
    private func threeDSTile(app: DiscoveredApp, index: Int, isSelected: Bool) -> some View {
        let cursorInset: CGFloat = 3.5

        return ZStack {
            if isIconOnly {
                // Pure App Icon Look (no background box, pure pristine macOS app icon squircle!)
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: tileSize, height: tileSize)
                    .shadow(
                        color: isSelected ? app.accentColor.opacity(0.65) : Color.black.opacity(0.35),
                        radius: isSelected ? 14 : 6,
                        x: 0,
                        y: isSelected ? 6 : 3
                    )
            } else {
                // Unified Channel Card Look (Matching Cover Flow & Wall Grid!)
                ChannelCardDesignView(
                    app: app,
                    isSelected: isSelected,
                    width: cardWidth,
                    height: cardHeight,
                    showFooter: cardHeight >= 115,
                    showHeader: cardHeight >= 90
                )
            }

            // Iconic Nintendo 3DS Cyan Corner Reticle Selection Cursor [  ]
            if isSelected {
                ThreeDSCursorOverlay(
                    width: itemWidth + cursorInset * 2,
                    height: itemHeight + cursorInset * 2,
                    bracketSize: min(20, itemWidth * 0.28)
                )
            }
        }
        .scaleEffect(isSelected ? (reduceMotion ? 1.03 : 1.08) : 1.0)
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(app.name), \(app.category)\(AppDiscoveryService.shared.isRunning(app: app) ? ", Running" : "")")
        .accessibilityHint(isSelected ? "Press Return to launch application" : "Click to select application")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
        .onTapGesture {
            if isSelected {
                onLaunch()
            } else {
                onSelect(index)
            }
        }
        .appContextMenu(for: app, onLaunch: onLaunch)
    }

    // MARK: - 3DS Speech Bubble Tooltip
    private func speechBubble(for app: DiscoveredApp) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: isCompact ? 16 : 20, height: isCompact ? 16 : 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.name)
                    .font(.system(size: isCompact ? 11 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(app.category.uppercased())
                    .font(.system(size: isCompact ? 8 : 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, isCompact ? 10 : 14)
        .padding(.vertical, isCompact ? 5 : 7)
        .background(
            ZStack {
                VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                Color(red: 0.08, green: 0.08, blue: 0.12).opacity(0.92)
            }
            .clipShape(Capsule())
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(red: 0.0, green: 0.95, blue: 0.85).opacity(0.6), Color.white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Nintendo 3DS Neon Cyan Corner Reticle Cursor
struct ThreeDSCursorOverlay: View {
    var width: CGFloat
    var height: CGFloat
    let bracketSize: CGFloat
    let color: Color = Color(red: 0.0, green: 0.95, blue: 0.85) // 3DS vibrant cyan/turquoise

    init(size: CGFloat, bracketSize: CGFloat) {
        self.width = size
        self.height = size
        self.bracketSize = bracketSize
    }

    init(width: CGFloat, height: CGFloat, bracketSize: CGFloat) {
        self.width = width
        self.height = height
        self.bracketSize = bracketSize
    }

    var body: some View {
        ZStack {
            // Top-Left L-bracket
            VStack {
                HStack {
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: bracketSize))
                        p.addLine(to: CGPoint(x: 0, y: 3.5))
                        p.addQuadCurve(to: CGPoint(x: 3.5, y: 0), control: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: bracketSize, y: 0))
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    .frame(width: bracketSize, height: bracketSize)
                    Spacer()
                }
                Spacer()
            }

            // Top-Right ⅂-bracket
            VStack {
                HStack {
                    Spacer()
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: bracketSize - 3.5, y: 0))
                        p.addQuadCurve(to: CGPoint(x: bracketSize, y: 3.5), control: CGPoint(x: bracketSize, y: 0))
                        p.addLine(to: CGPoint(x: bracketSize, y: bracketSize))
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    .frame(width: bracketSize, height: bracketSize)
                }
                Spacer()
            }

            // Bottom-Left ⅃-bracket
            VStack {
                Spacer()
                HStack {
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: 0, y: bracketSize - 3.5))
                        p.addQuadCurve(to: CGPoint(x: 3.5, y: bracketSize), control: CGPoint(x: 0, y: bracketSize))
                        p.addLine(to: CGPoint(x: bracketSize, y: bracketSize))
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    .frame(width: bracketSize, height: bracketSize)
                    Spacer()
                }
            }

            // Bottom-Right ⸢-bracket
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Path { p in
                        p.move(to: CGPoint(x: bracketSize, y: 0))
                        p.addLine(to: CGPoint(x: bracketSize, y: bracketSize - 3.5))
                        p.addQuadCurve(to: CGPoint(x: bracketSize - 3.5, y: bracketSize), control: CGPoint(x: bracketSize, y: bracketSize))
                        p.addLine(to: CGPoint(x: 0, y: bracketSize))
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                    .frame(width: bracketSize, height: bracketSize)
                }
            }
        }
        .frame(width: width, height: height)
        .shadow(color: color.opacity(0.85), radius: 5, x: 0, y: 0)
    }
}
