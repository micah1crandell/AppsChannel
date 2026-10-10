import SwiftUI
import AppKit

struct AppCardView: View {
    let app: DiscoveredApp
    let isSelected: Bool
    let offset: CGFloat
    let isCompact: Bool
    var isIconOnly: Bool = false
    let onSelect: () -> Void
    let onLaunch: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var discoveryService = AppDiscoveryService.shared

    var cardWidth: CGFloat {
        if isIconOnly {
            return isCompact ? 136 : 180
        }
        return isCompact ? 190 : 236
    }

    var cardHeight: CGFloat {
        if isIconOnly {
            return isCompact ? 160 : 216
        }
        return isCompact ? 232 : 290
    }

    var iconSize: CGFloat {
        if isIconOnly {
            return isCompact ? 116 : 158
        }
        return isCompact ? 76 : 100
    }

    var canvasWidth: CGFloat { isCompact ? 168 : 210 }
    var canvasHeight: CGFloat { isCompact ? 150 : 190 }

    var reflectionHeight: CGFloat {
        if isIconOnly {
            return isCompact ? 56 : 76
        }
        return isCompact ? 65 : 85
    }

    var body: some View {
        let angle = calculateRotation(offset: offset)
        let scale = calculateScale(offset: offset)

        VStack(spacing: 0) {
            if app.isSeparator {
                // Sleek Vertical Separator Divider Card
                HiddenAppsSeparatorCardView(
                    width: cardWidth,
                    height: cardHeight,
                    isCompact: isCompact,
                    isIconOnly: isIconOnly,
                    isSelected: isSelected
                )
            } else if isIconOnly {
                // Pure App Icon Display Style (Minimalist Cover Flow)
                VStack(spacing: isCompact ? 8 : 12) {
                    ZStack(alignment: .topTrailing) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                            .shadow(
                                color: isSelected ? app.accentColor.opacity(0.65) : Color.black.opacity(0.38),
                                radius: isSelected ? 22 : 12,
                                x: 0,
                                y: isSelected ? 10 : 5
                            )
                            .overlay(
                                Group {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: iconSize * 0.225, style: .continuous)
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [Color.white, Color.white.opacity(0.35)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2.0
                                            )
                                            .padding(-3)
                                    }
                                }
                            )

                        if app.isHiddenApp {
                            HStack(spacing: 3) {
                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: isCompact ? 9 : 11, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, isCompact ? 5 : 6)
                            .padding(.vertical, isCompact ? 3 : 4)
                            .background(Color.orange, in: Capsule())
                            .shadow(color: .orange.opacity(0.6), radius: 4)
                            .offset(x: isCompact ? 4 : 6, y: isCompact ? -4 : -6)
                        }
                    }

                    HStack(spacing: 5) {
                        if app.isHiddenApp {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: isCompact ? 9 : 11))
                                .foregroundStyle(.orange)
                        } else if discoveryService.isRunning(app: app) {
                            Circle()
                                .fill(Color(red: 0.25, green: 0.90, blue: 0.55))
                                .frame(width: isCompact ? 5 : 6, height: isCompact ? 5 : 6)
                                .shadow(color: Color(red: 0.25, green: 0.90, blue: 0.55).opacity(0.85), radius: 3)
                        }

                        Text(app.name)
                            .font(.system(size: isCompact ? 13 : 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.85), radius: 4, x: 0, y: 2)
                    }
                    .opacity(isSelected ? 1.0 : max(0.25, 1.0 - abs(offset) * 0.55))
                }
                .frame(width: cardWidth, height: cardHeight)
                .contentShape(Rectangle())
            } else {
                // Channel Card Display Style (Nintendo Wii / macOS Glass Card)
                ChannelCardDesignView(
                    app: app,
                    isSelected: isSelected,
                    width: cardWidth,
                    height: cardHeight,
                    showFooter: true,
                    showHeader: true
                )
            }

            // Mirror Glass Reflection (naturally feathered, no clipping bounds)
            if abs(offset) < 2.2 {
                reflectionView
                    .frame(width: cardWidth, height: reflectionHeight)
                    .opacity(isSelected ? 0.32 : 0.16)
            } else {
                Spacer().frame(height: reflectionHeight)
            }
        }
        .compositingGroup()
        .scaleEffect(scale)
        .rotation3DEffect(
            .degrees(angle),
            axis: (x: 0.0, y: 1.0, z: 0.0),
            anchor: .center,
            perspective: 0.45
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(app.isSeparator ? "Hidden Apps Section" : "\(app.name), \(app.category)\(app.isHiddenApp ? ", Hidden" : "")\(discoveryService.isRunning(app: app) ? ", Running" : "")")
        .accessibilityValue(app.tagBadge.isEmpty ? "" : app.tagBadge)
        .accessibilityHint(app.isSeparator ? "Press Return to navigate to hidden apps" : (isSelected ? "Press Return to launch application" : "Click to select application"))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
        .onTapGesture {
            if isSelected {
                onLaunch()
            } else {
                onSelect()
            }
        }
        .appContextMenu(for: app, onLaunch: onLaunch)
    }

    private var reflectionView: some View {
        VStack {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: isIconOnly ? (isCompact ? 96 : 132) : (isCompact ? 64 : 85),
                    height: isIconOnly ? (isCompact ? 96 : 132) : (isCompact ? 64 : 85)
                )
                .scaleEffect(y: -1)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.15), location: 0.45),
                            .init(color: .white.opacity(0.75), location: 1.0)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
        }
        .padding(.top, isIconOnly ? 2 : 4)
    }

    private func calculateRotation(offset: CGFloat) -> Double {
        if reduceMotion || abs(offset) < 0.001 { return 0 }
        let maxAngle: Double = 46.0
        let sign: Double = offset > 0 ? -1 : 1
        return sign * min(maxAngle, 36.0 + Double(abs(offset)) * 2.0)
    }

    private func calculateScale(offset: CGFloat) -> CGFloat {
        let absOffset = abs(offset)
        if reduceMotion {
            return isSelected ? 1.02 : 0.98
        }
        if absOffset < 0.2 { return 1.05 }
        return max(0.78, 1.0 - (absOffset * 0.06))
    }
}

// MARK: - Reusable Unified Nintendo Wii / macOS Channel Card View
struct ChannelCardDesignView: View {
    let app: DiscoveredApp
    let isSelected: Bool
    let width: CGFloat
    let height: CGFloat
    var showFooter: Bool = true
    var showHeader: Bool = true

    private var cornerRadius: CGFloat {
        max(10, width * 0.105)
    }

    private var canvasCornerRadius: CGFloat {
        max(7, width * 0.085)
    }

    private var canvasWidth: CGFloat {
        width * 0.88
    }

    private var canvasHeight: CGFloat {
        if showHeader && showFooter {
            return height * 0.63
        } else if showHeader || showFooter {
            return height * 0.74
        } else {
            return height * 0.84
        }
    }

    private var iconSize: CGFloat {
        max(24, canvasHeight * 0.50)
    }

    private var titleFontSize: CGFloat {
        max(8.0, min(18, width * 0.082))
    }

    private var headerFontSize: CGFloat {
        max(6.0, min(11, width * 0.052))
    }

    private var footerFontSize: CGFloat {
        max(5.5, min(10, width * 0.046))
    }

    var body: some View {
        if app.isSeparator {
            HiddenAppsSeparatorCardView(
                width: width,
                height: height,
                isCompact: width < 150,
                isIconOnly: false,
                isSelected: isSelected
            )
        } else {
            VStack(spacing: max(2, height * 0.03)) {
                // Top Header: "macOS • [CATEGORY]" or "HIDDEN • [CATEGORY]"
                if showHeader {
                    HStack(spacing: max(2, width * 0.025)) {
                        Text("macOS")
                            .font(.system(size: headerFontSize, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.9))

                        Circle()
                            .fill(app.isHiddenApp ? Color.orange : app.accentColor)
                            .frame(width: max(2.5, width * 0.022), height: max(2.5, width * 0.022))

                        Spacer()

                        HStack(spacing: max(2.5, width * 0.02)) {
                            if app.isHiddenApp {
                                HStack(spacing: 2.5) {
                                    Image(systemName: "eye.slash.fill")
                                        .font(.system(size: max(4.5, headerFontSize * 0.8), weight: .bold))
                                    Text("HIDDEN")
                                        .font(.system(size: max(4.5, headerFontSize * 0.8), weight: .heavy, design: .monospaced))
                                }
                                .foregroundStyle(Color.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Color.orange.opacity(0.2), in: Capsule())
                            } else if AppDiscoveryService.shared.isRunning(app: app) {
                                Circle()
                                    .fill(Color(red: 0.25, green: 0.90, blue: 0.55))
                                    .frame(width: max(4.5, width * 0.032), height: max(4.5, width * 0.032))
                                    .shadow(color: Color(red: 0.25, green: 0.90, blue: 0.55).opacity(0.85), radius: 2.5)
                            }

                            Text(app.category.uppercased())
                                .font(.system(size: max(5.5, headerFontSize * 0.92), weight: .heavy, design: .monospaced))
                                .foregroundStyle(app.isHiddenApp ? Color.orange.opacity(0.9) : Color.white.opacity(0.75))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, max(5, width * 0.055))
                    .padding(.top, max(4, height * 0.045))
                }

                // Center Icon Canvas
                ZStack {
                    RoundedRectangle(cornerRadius: canvasCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.65),
                                    Color.black.opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: canvasCornerRadius, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.2), .white.opacity(0.04)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )

                    VStack(spacing: max(2, canvasHeight * 0.06)) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                            .shadow(
                                color: (app.isHiddenApp ? Color.orange : app.accentColor).opacity(isSelected ? 0.45 : 0.2),
                                radius: max(3, iconSize * 0.15),
                                x: 0,
                                y: max(1.5, iconSize * 0.06)
                            )

                        Text(app.name)
                            .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.6), radius: 2.5, x: 0, y: 1.5)
                    }
                    .padding(.vertical, max(3, canvasHeight * 0.07))
                    .padding(.horizontal, max(4, canvasWidth * 0.05))
                }
                .frame(width: canvasWidth, height: canvasHeight)

                // Bottom Footer: Tag & Size
                if showFooter {
                    HStack {
                        if app.isHiddenApp {
                            HStack(spacing: 3) {
                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: footerFontSize * 0.9))
                                Text("HIDDEN APP")
                                    .font(.system(size: footerFontSize, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, max(3.5, width * 0.03))
                            .padding(.vertical, max(1.5, height * 0.012))
                            .background(Color.orange.opacity(0.2), in: Capsule())
                        } else {
                            Text(app.tagBadge)
                                .font(.system(size: footerFontSize, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .padding(.horizontal, max(3.5, width * 0.03))
                                .padding(.vertical, max(1.5, height * 0.012))
                                .background(Color.white.opacity(0.12), in: Capsule())
                        }

                        Spacer()

                        Text(app.sizeString)
                            .font(.system(size: footerFontSize, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, max(5, width * 0.055))
                    .padding(.bottom, max(4, height * 0.045))
                }
            }
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.10).opacity(0.96),
                                Color(white: 0.04).opacity(0.98)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isSelected ?
                                [Color.white, Color.white.opacity(0.65), Color.white.opacity(0.25)] :
                                [Color.white.opacity(0.28), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? max(1.3, width * 0.01) : 1.0
                    )
            )
            .shadow(
                color: isSelected ? Color.white.opacity(0.28) : Color.black.opacity(0.3),
                radius: isSelected ? max(8, width * 0.09) : 6,
                x: 0,
                y: isSelected ? max(4, height * 0.035) : 3
            )
        }
    }
}
