import SwiftUI
import AppKit

struct AppCardView: View {
    let app: DiscoveredApp
    let isSelected: Bool
    let offset: CGFloat
    let isCompact: Bool
    let onSelect: () -> Void
    let onLaunch: () -> Void

    var cardWidth: CGFloat { isCompact ? 190 : 236 }
    var cardHeight: CGFloat { isCompact ? 232 : 290 }
    var iconSize: CGFloat { isCompact ? 76 : 100 }
    var canvasWidth: CGFloat { isCompact ? 168 : 210 }
    var canvasHeight: CGFloat { isCompact ? 150 : 190 }
    var reflectionHeight: CGFloat { isCompact ? 65 : 85 }

    var body: some View {
        let angle = calculateRotation(offset: offset)
        let scale = calculateScale(offset: offset)

        VStack(spacing: 0) {
            // Main Card Body
            VStack(spacing: isCompact ? 8 : 12) {
                // Top Header: "macOS • [CATEGORY]"
                HStack(spacing: 5) {
                    Text("macOS")
                        .font(.system(size: isCompact ? 10 : 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.9))

                    Circle()
                        .fill(app.accentColor)
                        .frame(width: 4, height: 4)

                    Spacer()

                    Text(app.category.uppercased())
                        .font(.system(size: isCompact ? 9 : 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineLimit(1)
                }
                .padding(.horizontal, isCompact ? 10 : 14)
                .padding(.top, isCompact ? 10 : 14)

                // Center Icon Canvas
                ZStack {
                    RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
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
                            RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.2), .white.opacity(0.04)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )

                    VStack(spacing: isCompact ? 10 : 14) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                            .shadow(color: app.accentColor.opacity(isSelected ? 0.45 : 0.2), radius: isCompact ? 10 : 14, x: 0, y: 5)

                        Text(app.name)
                            .font(.system(size: isCompact ? 15 : 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                    }
                    .padding(.vertical, isCompact ? 12 : 16)
                    .padding(.horizontal, isCompact ? 8 : 12)
                }
                .frame(width: canvasWidth, height: canvasHeight)

                // Bottom Footer: Tag & Size
                HStack {
                    Text(app.tagBadge)
                        .font(.system(size: isCompact ? 8 : 9, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.12), in: Capsule())

                    Spacer()

                    Text(app.sizeString)
                        .font(.system(size: isCompact ? 9 : 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .padding(.horizontal, isCompact ? 10 : 14)
                .padding(.bottom, isCompact ? 10 : 14)
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(
                RoundedRectangle(cornerRadius: isCompact ? 20 : 24, style: .continuous)
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
                RoundedRectangle(cornerRadius: isCompact ? 20 : 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: isSelected ?
                                [Color.white, Color.white.opacity(0.65), Color.white.opacity(0.25)] :
                                [Color.white.opacity(0.28), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 1.5 : 1.0
                    )
            )
            .shadow(
                color: isSelected ? Color.white.opacity(0.28) : Color.black.opacity(0.3),
                radius: isSelected ? 18 : 10,
                x: 0,
                y: isSelected ? 8 : 4
            )

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
        .onTapGesture {
            if isSelected {
                onLaunch()
            } else {
                onSelect()
            }
        }
    }

    private var reflectionView: some View {
        VStack {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: isCompact ? 64 : 85, height: isCompact ? 64 : 85)
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
        .padding(.top, 4)
    }

    private func calculateRotation(offset: CGFloat) -> Double {
        if abs(offset) < 0.001 { return 0 }
        let maxAngle: Double = 46.0
        let sign: Double = offset > 0 ? -1 : 1
        return sign * min(maxAngle, 36.0 + Double(abs(offset)) * 2.0)
    }

    private func calculateScale(offset: CGFloat) -> CGFloat {
        let absOffset = abs(offset)
        if absOffset < 0.2 { return 1.05 }
        return max(0.78, 1.0 - (absOffset * 0.06))
    }
}
