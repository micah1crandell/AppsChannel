import SwiftUI
import AppKit

// MARK: - Hidden Apps Section Separator Card (CoverFlow & Wall Grid)
struct HiddenAppsSeparatorCardView: View {
    let width: CGFloat
    let height: CGFloat
    var isCompact: Bool = false
    var isIconOnly: Bool = false
    let isSelected: Bool

    private var cornerRadius: CGFloat {
        max(10, width * 0.105)
    }

    private var barHeight: CGFloat {
        height * 0.55
    }

    var body: some View {
        ZStack {
            // Glass background with subtle amber glow
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.10, blue: 0.04).opacity(0.95),
                            Color(red: 0.08, green: 0.05, blue: 0.02).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Distinctive Vertical Divider Aesthetic
            HStack(spacing: max(8, width * 0.06)) {
                // Vertical glowing divider line |
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.3),
                                Color.orange,
                                Color.yellow.opacity(0.9),
                                Color.orange,
                                Color.orange.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: max(3.0, width * 0.022), height: barHeight)
                    .shadow(color: Color.orange.opacity(isSelected ? 0.9 : 0.5), radius: isSelected ? 8 : 4)

                // Label and Icon
                VStack(alignment: .leading, spacing: max(4, height * 0.03)) {
                    HStack(spacing: 5) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: isCompact ? 13 : 16, weight: .bold))
                            .foregroundStyle(Color.orange)

                        Text("SECTION")
                            .font(.system(size: isCompact ? 8 : 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.orange.opacity(0.85))
                    }

                    Text("Hidden Apps")
                        .font(.system(size: isCompact ? 13 : 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)

                    Text("Search Matches")
                        .font(.system(size: isCompact ? 8.5 : 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, max(10, width * 0.08))
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: isSelected ?
                            [Color.white, Color.orange, Color.orange.opacity(0.5)] :
                            [Color.orange.opacity(0.4), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? max(1.4, width * 0.012) : 1.0
                )
        )
        .shadow(
            color: isSelected ? Color.orange.opacity(0.45) : Color.black.opacity(0.35),
            radius: isSelected ? max(10, width * 0.1) : 6,
            x: 0,
            y: isSelected ? 5 : 3
        )
    }
}

// MARK: - Hidden Apps Section Separator Tile (Flat Grid)
struct HiddenAppsSeparatorTileView: View {
    let width: CGFloat
    let height: CGFloat
    var isCompact: Bool = false
    let isSelected: Bool

    private var cornerRadius: CGFloat {
        max(6, width * 0.12)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.11, blue: 0.05).opacity(0.95),
                            Color(red: 0.08, green: 0.05, blue: 0.02).opacity(0.98)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            HStack(spacing: max(3, width * 0.06)) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.4), Color.orange, Color.yellow.opacity(0.9), Color.orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: max(2.5, width * 0.03), height: height * 0.6)
                    .shadow(color: Color.orange.opacity(0.7), radius: 3)

                VStack(spacing: 2) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: max(9, min(14, width * 0.18)), weight: .bold))
                        .foregroundStyle(Color.orange)

                    if height >= 60 {
                        Text("HIDDEN")
                            .font(.system(size: max(6, min(9, width * 0.11)), weight: .heavy, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.orange : Color.orange.opacity(0.35),
                    lineWidth: isSelected ? 1.5 : 1.0
                )
        )
    }
}
