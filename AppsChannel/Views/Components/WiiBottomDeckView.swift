import SwiftUI
import AppKit
import Combine

// MARK: - Wii Bottom Console Dashboard View
struct WiiBottomDeckView: View {
    let selectedApp: DiscoveredApp?
    let onLaunch: () -> Void
    var onOpenSettings: (() -> Void)? = nil
    var onAddCustomChannel: (() -> Void)? = nil
    var onSwitchToQuick: (() -> Void)? = nil

    @State private var currentTime: String = ""
    @State private var currentDate: String = ""
    @State private var timer: AnyCancellable? = nil
    @ObservedObject private var modifierManager = KeyboardModifierManager.shared

    var body: some View {
        ZStack(alignment: .top) {
            // Background Curved Console Deck
            consoleDeckBackground

            // True Window-Centered Concave Clock & Date
            centerClockBay
                .frame(maxWidth: .infinity, alignment: .top)

            // Side Controls pinned to their respective margins
            HStack(alignment: .top) {
                // Left Controls: Settings Gear & Add Channel Plus
                HStack(spacing: 12) {
                    settingsMenuButton
                    addChannelButton
                }
                .padding(.leading, 28)
                .padding(.top, 16)

                Spacer()

                // Right Controls: Start Pill & Quick Launcher
                HStack(spacing: 14) {
                    if let app = selectedApp, !app.isSeparator {
                        launchAppPill(app: app)
                    }
                    quickLauncherButton
                }
                .padding(.trailing, 28)
                .padding(.top, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 78)
        .onAppear {
            updateClock()
            timer = Timer.publish(every: 1.0, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    updateClock()
                }
        }
        .onDisappear {
            timer?.cancel()
            timer = nil
        }
    }

    // MARK: - Curved Console Deck Background
    private var consoleDeckBackground: some View {
        ZStack(alignment: .top) {
            // Curved Base Deck
            WiiDeckCurvedShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.98),
                            Color(white: 0.93),
                            Color(white: 0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Top Beveled Specular Lip
            WiiDeckCurvedShape()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(white: 0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )

            // Distinctive Cyan/Sky-Blue Curved Accent Trim Line
            WiiDeckAccentTrimShape()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.78, blue: 1.0),
                            Color(red: 0.05, green: 0.62, blue: 0.92)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2.5
                )
                .shadow(color: Color(red: 0.05, green: 0.65, blue: 0.95).opacity(0.35), radius: 3, x: 0, y: 1)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: -2)
    }

    // MARK: - Center Concave Clock Bay (Authentic Wii: Time above curve, Date below curve)
    private var centerClockBay: some View {
        VStack(spacing: 0) {
            // Digital Retro Clock (Nestled comfortably inside the valley ABOVE the cyan curve)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                // Invisible counterbalance to ensure currentTime digits are centered exactly at 50% width
                Text(meridiemString)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .opacity(0)

                Text(currentTime)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.22))
                    .tracking(1.6)
                    .shadow(color: Color.white.opacity(0.8), radius: 0.5, x: 0, y: 1)

                Text(meridiemString)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(white: 0.40))
            }
            .frame(height: 24)

            // Gap where the cyan curve glides through at y = 35
            Spacer().frame(height: 12)

            // Date (Resting on the lower console deck BELOW the cyan curve)
            Text(currentDate)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(white: 0.42))
                .shadow(color: Color.white.opacity(0.8), radius: 0.5, x: 0, y: 1)
                .frame(height: 14)
        }
        .padding(.top, 4)
    }

    // MARK: - Left Settings Gear Button
    private var settingsMenuButton: some View {
        Button(action: {
            SoundEffectsManager.shared.playAction()
            onOpenSettings?()
        }) {
            ZStack {
                // Outer Silver Beveled Ring
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.98), Color(white: 0.83)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(
                                colors: [Color.white, Color(white: 0.70)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 3, x: 0, y: 1.5)

                // Inner Recessed Button Core
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.95), Color(white: 0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 0.8))

                // Settings Gear Icon
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(white: 0.36))
                    .shadow(color: Color.white.opacity(0.9), radius: 0.5, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
        .help("Settings (⌘,)")
    }

    // MARK: - Left Add Custom Channel Plus Button
    private var addChannelButton: some View {
        Button(action: {
            SoundEffectsManager.shared.playAction()
            onAddCustomChannel?()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.98), Color(white: 0.84)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white, Color(white: 0.72)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.2
                            )
                    )
                    .shadow(color: Color.black.opacity(0.14), radius: 2, x: 0, y: 1)

                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(white: 0.38))
                    .shadow(color: Color.white.opacity(0.9), radius: 0.5, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
        .help("Add Custom Channel")
    }

    // MARK: - Right Quick Launcher Button
    private var quickLauncherButton: some View {
        Button(action: {
            SoundEffectsManager.shared.playAction()
            onSwitchToQuick?()
        }) {
            ZStack {
                // Circular Beveled Outer Ring
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.98), Color(white: 0.83)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(
                                colors: [Color.white, Color(white: 0.70)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                    )
                    .shadow(color: Color.black.opacity(0.16), radius: 3, x: 0, y: 1.5)

                // Inner Button Core with Quick Launcher Icon
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.95), Color(white: 0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.08), lineWidth: 0.8))

                Image(systemName: "rectangle.inset.filled.and.cursorarrow")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.36))
                    .shadow(color: Color.white.opacity(0.9), radius: 0.5, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
        .help("Quick Launcher (⌘O)")
    }

    // MARK: - Launch App Pill
    private func launchAppPill(app: DiscoveredApp) -> some View {
        Button(action: onLaunch) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.forward.app.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Start")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.75, blue: 1.0),
                        Color(red: 0.05, green: 0.55, blue: 0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: Capsule()
            )
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color(red: 0.0, green: 0.55, blue: 0.95).opacity(0.35), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Clock Helpers
    private func updateClock() {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        currentTime = formatter.string(from: Date())

        let dateForm = DateFormatter()
        dateForm.dateFormat = "EEE M/d"
        currentDate = dateForm.string(from: Date())
    }

    private var meridiemString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "a"
        return formatter.string(from: Date()).uppercased()
    }
}

// MARK: - Wii Deck Curved Geometry Shapes (Dips cleanly between Time and Date)
struct WiiDeckCurvedShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Start bottom-left
        path.move(to: CGPoint(x: 0, y: h))
        // Up to left shelf
        path.addLine(to: CGPoint(x: 0, y: 10))
        // Left horizontal shelf
        path.addLine(to: CGPoint(x: w * 0.28, y: 10))

        // Gentle concave downward scoop passing between time and date
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: 35),
            control1: CGPoint(x: w * 0.36, y: 10),
            control2: CGPoint(x: w * 0.43, y: 35)
        )
        // Gentle curve back up to right shelf
        path.addCurve(
            to: CGPoint(x: w * 0.72, y: 10),
            control1: CGPoint(x: w * 0.57, y: 35),
            control2: CGPoint(x: w * 0.64, y: 10)
        )

        // Right shelf
        path.addLine(to: CGPoint(x: w, y: 10))
        // Down to bottom-right
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        return path
    }
}

struct WiiDeckAccentTrimShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width

        path.move(to: CGPoint(x: 0, y: 10))
        path.addLine(to: CGPoint(x: w * 0.28, y: 10))
        path.addCurve(
            to: CGPoint(x: w * 0.50, y: 35),
            control1: CGPoint(x: w * 0.36, y: 10),
            control2: CGPoint(x: w * 0.43, y: 35)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.72, y: 10),
            control1: CGPoint(x: w * 0.57, y: 35),
            control2: CGPoint(x: w * 0.64, y: 10)
        )
        path.addLine(to: CGPoint(x: w, y: 10))
        return path
    }
}
