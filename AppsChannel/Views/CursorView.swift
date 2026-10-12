import SwiftUI

// MARK: - Isolated High-Performance Cursor Tracking Overlay
struct WiiCursorTrackingOverlay: View {
    let isWiiMode: Bool
    let isGrabbing: Bool

    @State private var cursorPosition: CGPoint = .zero
    @State private var isCursorInside: Bool = false

    var body: some View {
        Group {
            if isWiiMode {
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            cursorPosition = location
                            isCursorInside = true
                        case .ended:
                            isCursorInside = false
                        }
                    }
                    .overlay(
                        Group {
                            if isCursorInside {
                                CursorView(
                                    position: cursorPosition,
                                    isHoveringCard: false,
                                    isGrabbing: isGrabbing,
                                    isWiiMode: true
                                )
                            }
                        }
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Wii & Modern Dynamic Cursor View
struct CursorView: View {
    let position: CGPoint
    let isHoveringCard: Bool
    var isGrabbing: Bool = false
    var isWiiMode: Bool = true

    var body: some View {
        Group {
            if isWiiMode {
                WiiHandCursorGraphic(isHovering: isHoveringCard, isGrabbing: isGrabbing)
            } else {
                modernGlassPointer
            }
        }
        .position(position)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHoveringCard)
        .animation(.spring(response: 0.20, dampingFraction: 0.75), value: isGrabbing)
    }

    // MARK: - Modern Glass Pointer (Fallback for Liquid Glass)
    private var modernGlassPointer: some View {
        ZStack {
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

            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
        }
    }
}

// MARK: - Authentic Wii P1 Cartoon Hand Pointer Graphic
struct WiiHandCursorGraphic: View {
    let isHovering: Bool
    let isGrabbing: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hover Target Glow Ring underneath fingertip
            if isHovering {
                Circle()
                    .strokeBorder(Color(red: 0.05, green: 0.65, blue: 0.95).opacity(0.8), lineWidth: 2)
                    .background(Circle().fill(Color(red: 0.05, green: 0.65, blue: 0.95).opacity(0.2)))
                    .frame(width: 24, height: 24)
                    .offset(x: -8, y: -8)
                    .shadow(color: Color(red: 0.05, green: 0.65, blue: 0.95), radius: 6)
            }

            // Ground Drop Shadow
            handBodyGraphic(isShadow: true)
                .offset(x: 2.5, y: 3.5)
                .opacity(0.22)

            // Crisp White Hand Graphic with Black Outline
            handBodyGraphic(isShadow: false)
        }
        .scaleEffect(isHovering ? 1.08 : (isGrabbing ? 0.96 : 1.0))
        .rotationEffect(.degrees(isHovering ? -10 : (isGrabbing ? -5 : 0)))
        .offset(x: -8, y: -4) // Align fingertip with system pointer hotspot
    }

    @ViewBuilder
    private func handBodyGraphic(isShadow: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            if isGrabbing {
                // Clenched Fist for Organize/Drag Mode
                WiiClenchedFistShape()
                    .fill(isShadow ? Color.black : Color(white: 0.98))
                    .overlay(
                        Group {
                            if !isShadow {
                                WiiClenchedFistShape()
                                    .stroke(Color.black, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                            }
                        }
                    )
                    .frame(width: 32, height: 32)
            } else {
                // Pointing Hand (Iconic P1 Pointer)
                WiiPointingHandShape()
                    .fill(isShadow ? Color.black : Color(white: 0.98))
                    .overlay(
                        Group {
                            if !isShadow {
                                WiiPointingHandShape()
                                    .stroke(Color.black, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                            }
                        }
                    )
                    .frame(width: 32, height: 42)
            }

            // P1 Blue Cuff Badge (Player 1)
            if !isShadow {
                HStack(spacing: 0) {
                    Text("1")
                        .font(.system(size: 8.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 13, height: 13)
                .background(
                    RoundedRectangle(cornerRadius: 3.5)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.15, green: 0.58, blue: 0.98),
                                    Color(red: 0.05, green: 0.42, blue: 0.88)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3.5)
                        .strokeBorder(Color.white.opacity(0.85), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 1, x: 0, y: 1)
                .offset(x: 2, y: -1)
            }
        }
    }
}

// MARK: - Wii Hand Pointer Geometry Path
struct WiiPointingHandShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Fingertip at top-left (hotspot)
        path.move(to: CGPoint(x: w * 0.32, y: h * 0.04))

        // Index finger right edge
        path.addQuadCurve(
            to: CGPoint(x: w * 0.46, y: h * 0.04),
            control: CGPoint(x: w * 0.39, y: 0)
        )
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.42))

        // Middle finger curl
        path.addQuadCurve(
            to: CGPoint(x: w * 0.80, y: h * 0.45),
            control: CGPoint(x: w * 0.78, y: h * 0.36)
        )
        // Ring finger curl
        path.addQuadCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.62),
            control: CGPoint(x: w * 0.88, y: h * 0.52)
        )
        // Pinky curl
        path.addQuadCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.78),
            control: CGPoint(x: w * 0.84, y: h * 0.72)
        )

        // Wrist right edge
        path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.98))

        // Wrist bottom edge (cuff)
        path.addLine(to: CGPoint(x: w * 0.15, y: h * 0.98))

        // Wrist left edge
        path.addLine(to: CGPoint(x: w * 0.14, y: h * 0.75))

        // Thumb curve
        path.addQuadCurve(
            to: CGPoint(x: w * 0.12, y: h * 0.50),
            control: CGPoint(x: 0, y: h * 0.60)
        )
        path.addQuadCurve(
            to: CGPoint(x: w * 0.28, y: h * 0.45),
            control: CGPoint(x: w * 0.16, y: h * 0.42)
        )

        // Index finger left edge leading to tip
        path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.04))

        path.closeSubpath()
        return path
    }
}

// MARK: - Wii Clenched Fist Geometry Path (Grab Mode)
struct WiiClenchedFistShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        path.move(to: CGPoint(x: w * 0.30, y: h * 0.18))
        path.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.18), control: CGPoint(x: w * 0.54, y: h * 0.06))
        path.addQuadCurve(to: CGPoint(x: w * 0.86, y: h * 0.60), control: CGPoint(x: w * 0.92, y: h * 0.38))
        path.addQuadCurve(to: CGPoint(x: w * 0.65, y: h * 0.95), control: CGPoint(x: w * 0.82, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.95))
        path.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.58), control: CGPoint(x: w * 0.10, y: h * 0.80))
        path.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.18), control: CGPoint(x: w * 0.10, y: h * 0.30))

        path.closeSubpath()
        return path
    }
}
