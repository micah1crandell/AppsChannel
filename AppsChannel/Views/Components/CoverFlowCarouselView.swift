import SwiftUI
import AppKit

struct CoverFlowCarouselView: View {
    let apps: [DiscoveredApp]
    let activeIndex: Int
    let isCompact: Bool
    let onSelect: (Int) -> Void
    let onLaunch: () -> Void
    let onNavigate: (Int) -> Void

    @State private var dragOffset: CGFloat = 0.0

    var body: some View {
        GeometryReader { proxy in
            let centerX = proxy.size.width / 2
            let centerY = proxy.size.height / 2

            ZStack {
                if apps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.folder.dashed")
                            .font(.system(size: isCompact ? 36 : 48))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("No matching applications found")
                            .font(isCompact ? .subheadline : .headline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .position(x: centerX, y: centerY)
                } else {
                    ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                        let offsetFromCenter = CGFloat(index - activeIndex) + (dragOffset / (isCompact ? 200.0 : 260.0))

                        // Limit visible cards range for maximum performance
                        if abs(offsetFromCenter) < (isCompact ? 3.5 : 4.5) {
                            AppCardView(
                                app: app,
                                isSelected: index == activeIndex,
                                offset: offsetFromCenter,
                                isCompact: isCompact,
                                onSelect: {
                                    onSelect(index)
                                },
                                onLaunch: onLaunch
                            )
                            .position(
                                x: centerX + calculateCardX(offset: offsetFromCenter),
                                y: centerY
                            )
                            .zIndex(calculateZIndex(offset: offsetFromCenter))
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
                        let threshold: CGFloat = isCompact ? 40.0 : 55.0
                        if value.translation.width < -threshold {
                            onNavigate(1)
                        } else if value.translation.width > threshold {
                            onNavigate(-1)
                        }
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.85)) {
                            dragOffset = 0
                        }
                    }
            )
        }
        .frame(height: isCompact ? 360 : 540)
    }

    private func calculateCardX(offset: CGFloat) -> CGFloat {
        if abs(offset) < 0.001 { return 0 }
        let sign: CGFloat = offset > 0 ? 1 : -1
        let baseSpacing: CGFloat = isCompact ? 105 : 135
        let centerGap: CGFloat = isCompact ? 95 : 120
        return sign * (centerGap + (abs(offset) - 1) * baseSpacing)
    }

    private func calculateZIndex(offset: CGFloat) -> Double {
        if abs(offset) < 0.1 { return 200.0 }
        return 100.0 - Double(abs(offset)) * 10.0
    }
}
