import SwiftUI

struct CursorView: View {
    let position: CGPoint
    let isHoveringCard: Bool

    var body: some View {
        ZStack {
            // Ambient liquid glass glow following cursor
            RadialGradient(
                colors: [
                    Color.cyan.opacity(isHoveringCard ? 0.35 : 0.18),
                    Color.blue.opacity(0.08),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: isHoveringCard ? 70 : 45
            )
            .frame(width: isHoveringCard ? 140 : 90, height: isHoveringCard ? 140 : 90)
            .blur(radius: 12)

            // Sleek glass pointer ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.8), .white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .background(Circle().fill(.ultraThinMaterial.opacity(0.6)))
                .frame(width: isHoveringCard ? 36 : 22, height: isHoveringCard ? 36 : 22)
                .shadow(color: .cyan.opacity(0.5), radius: isHoveringCard ? 8 : 4)

            // Center pin dot
            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
        }
        .position(position)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHoveringCard)
    }
}
