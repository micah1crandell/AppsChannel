import SwiftUI
import AppKit
import ImageIO

// MARK: - Animated Channel Banner View
struct AnimatedChannelBannerView: View {
    let app: DiscoveredApp
    let width: CGFloat
    let height: CGFloat
    let isSelected: Bool
    let isHovered: Bool

    @State private var gifFrames: [NSImage] = []
    @State private var currentFrameIndex: Int = 0
    @State private var frameTimer: Timer? = nil
    @State private var rotationAngle: Double = 0.0
    @State private var wavePhase: CGFloat = 0.0
    @State private var shimmerOffset: CGFloat = -1.2
    @State private var blinkCursor: Bool = true
    @State private var photoTilt: Double = 0.0

    private var isEmphasized: Bool {
        isSelected || isHovered
    }

    var body: some View {
        ZStack {
            // 1. If custom GIF/WebP asset exists for this app, display animated frame loop
            if !gifFrames.isEmpty {
                Image(nsImage: gifFrames[currentFrameIndex])
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                // 2. Procedural Wii Channel Animations
                proceduralChannelAnimation
            }

            // 3. Sweeping Specular Glass Shimmer (on hover or periodic)
            if isEmphasized {
                GeometryReader { geo in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: Color.white.opacity(0.35), location: 0.45),
                                    .init(color: Color.white.opacity(0.60), location: 0.50),
                                    .init(color: Color.white.opacity(0.35), location: 0.55),
                                    .init(color: .clear, location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(25))
                        .offset(x: shimmerOffset * geo.size.width * 2)
                        .allowsHitTesting(false)
                }
                .clipped()
            }
        }
        .frame(width: width, height: height)
        .onAppear {
            loadCustomAnimationIfNeeded()
            updateAnimationState()
        }
        .onDisappear {
            frameTimer?.invalidate()
            frameTimer = nil
        }
        .onChange(of: isEmphasized) { _, emphasized in
            updateAnimationState()
        }
    }

    // MARK: - Procedural Animations by App Type
    @ViewBuilder
    private var proceduralChannelAnimation: some View {
        let bundleID = app.bundleIdentifier?.lowercased() ?? ""
        let cat = app.category.lowercased()
        let name = app.name.lowercased()

        if bundleID.contains("finder") || name == "finder" {
            // Wii Disc Channel: Spinning Optical Disc
            discChannelAnimation
        } else if bundleID.contains("music") || bundleID.contains("spotify") || cat.contains("music") || cat.contains("audio") {
            // Wii Sound Channel: Dynamic Equalizer Spectrum
            musicChannelAnimation
        } else if bundleID.contains("terminal") || bundleID.contains("iterm") || bundleID.contains("vscode") || cat.contains("developer") {
            // Developer Channel: Retro Matrix / Terminal Typing Cursor
            terminalChannelAnimation
        } else if bundleID.contains("safari") || bundleID.contains("chrome") || bundleID.contains("firefox") || app.channelType == .web {
            // Forecast/News Channel: Rotating Globe & Radar Rings
            globeChannelAnimation
        } else if bundleID.contains("photos") || bundleID.contains("preview") || cat.contains("photo") || cat.contains("design") {
            // Photo Channel: Floating Bouncing Polaroid Cards
            photoChannelAnimation
        } else if bundleID.contains("appstore") || name.contains("app store") {
            // Wii Shop Channel: Bouncing Shopping Bag & Star Sparkles
            shopChannelAnimation
        } else {
            // Default App Channel: Icon with gentle floating motion and ambient glow
            defaultAppChannelContent
        }
    }

    // MARK: - 1. Wii Disc Channel Animation
    private var discChannelAnimation: some View {
        VStack(spacing: 3) {
            ZStack {
                // Rotating Metallic Hologram Optical Disc
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(white: 0.95),
                                Color(red: 0.85, green: 0.95, blue: 1.0),
                                Color(white: 0.90),
                                Color(red: 1.0, green: 0.88, blue: 0.95),
                                Color(white: 0.95)
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: height * 0.46, height: height * 0.46)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1.5)
                    .rotationEffect(.degrees(rotationAngle))

                // Center Disc Spindle Hole
                Circle()
                    .fill(Color(white: 0.92))
                    .frame(width: height * 0.14, height: height * 0.14)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 1))

                // Disc Inner Ring
                Circle()
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    .frame(width: height * 0.26, height: height * 0.26)
            }

            Text("Disc Channel")
                .font(.system(size: max(8, width * 0.07), weight: .bold, design: .rounded))
                .foregroundStyle(Color(white: 0.20))
        }
    }

    // MARK: - 2. Music Channel: Dynamic Equalizer
    private var musicChannelAnimation: some View {
        VStack(spacing: 4) {
            ZStack {
                // App Icon
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: height * 0.38, height: height * 0.38)
                    .shadow(color: app.accentColor.opacity(0.35), radius: 4, x: 0, y: 2)

                // Equalizer Waveform overlay along the bottom
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<6) { idx in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(
                                LinearGradient(
                                    colors: [app.accentColor, Color(red: 0.1, green: 0.8, blue: 0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(
                                width: 3.5,
                                height: max(4, abs(sin(wavePhase + CGFloat(idx) * 0.8)) * (height * 0.28))
                            )
                    }
                }
                .offset(y: height * 0.12)
            }

            Text(app.name)
                .font(.system(size: max(8, width * 0.07), weight: .bold, design: .rounded))
                .foregroundStyle(Color(white: 0.20))
                .lineLimit(1)
        }
    }

    // MARK: - 3. Developer / Terminal Channel
    private var terminalChannelAnimation: some View {
        VStack(spacing: 3) {
            ZStack {
                // Mini CRT / Terminal Screen
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.18))
                    .frame(width: width * 0.65, height: height * 0.44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 1.5)

                HStack(spacing: 3) {
                    Text("$")
                        .font(.system(size: max(8, height * 0.15), weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.2, green: 0.9, blue: 0.4))

                    Text("run")
                        .font(.system(size: max(8, height * 0.15), weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)

                    // Blinking Terminal Cursor
                    Rectangle()
                        .fill(Color(red: 0.2, green: 0.9, blue: 0.4))
                        .frame(width: 4, height: max(8, height * 0.15))
                        .opacity(blinkCursor ? 1.0 : 0.0)
                }
            }

            Text(app.name)
                .font(.system(size: max(8, width * 0.07), weight: .bold, design: .rounded))
                .foregroundStyle(Color(white: 0.20))
                .lineLimit(1)
        }
    }

    // MARK: - 4. Forecast / News Globe Channel
    private var globeChannelAnimation: some View {
        VStack(spacing: 3) {
            ZStack {
                // Soft blue glowing globe background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.65, blue: 0.98),
                                Color(red: 0.08, green: 0.38, blue: 0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: height * 0.42, height: height * 0.42)
                    .shadow(color: Color(red: 0.1, green: 0.5, blue: 0.9).opacity(0.35), radius: 4, x: 0, y: 2)

                // Rotating wireframe latitudes & longitudes
                Image(systemName: "globe.americas.fill")
                    .font(.system(size: height * 0.38))
                    .foregroundStyle(.white.opacity(0.85))
                    .rotationEffect(.degrees(rotationAngle * 0.5))

                // Radar pulse ring
                Circle()
                    .strokeBorder(Color.white.opacity(0.4), lineWidth: 1.2)
                    .frame(width: height * 0.46, height: height * 0.46)
                    .scaleEffect(1.0 + abs(sin(wavePhase * 0.8)) * 0.12)
                    .opacity(1.0 - abs(sin(wavePhase * 0.8)) * 0.6)
            }

            Text(app.name)
                .font(.system(size: max(8, width * 0.07), weight: .bold, design: .rounded))
                .foregroundStyle(Color(white: 0.20))
                .lineLimit(1)
        }
    }

    // MARK: - 5. Photo Channel
    private var photoChannelAnimation: some View {
        VStack(spacing: 3) {
            ZStack {
                // Background tilted Polaroid
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: height * 0.38, height: height * 0.42)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color.black.opacity(0.1), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 1)
                    .rotationEffect(.degrees(-photoTilt))

                // Foreground Polaroid with App Icon
                VStack(spacing: 2) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: height * 0.28, height: height * 0.28)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    Spacer().frame(height: 2)
                }
                .padding(4)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 1.5)
                .rotationEffect(.degrees(photoTilt))
            }

            Text(app.name)
                .font(.system(size: max(8, width * 0.07), weight: .bold, design: .rounded))
                .foregroundStyle(Color(white: 0.20))
                .lineLimit(1)
        }
    }

    // MARK: - 6. Wii Shop Channel
    private var shopChannelAnimation: some View {
        VStack(spacing: 3) {
            ZStack {
                // Cyan gradient backdrop
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.75, blue: 0.95), Color(red: 0.05, green: 0.5, blue: 0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: width * 0.60, height: height * 0.42)

                // Bouncing Bag Icon
                Image(systemName: "bag.fill")
                    .font(.system(size: height * 0.26, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: sin(wavePhase * 2) * 3)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            }

            Text("Wii Shop Channel")
                .font(.system(size: max(7.5, width * 0.065), weight: .bold, design: .rounded))
                .foregroundStyle(Color(white: 0.20))
        }
    }

    // MARK: - 7. Default App Channel Content
    private var defaultAppChannelContent: some View {
        VStack(spacing: max(2, height * 0.03)) {
            Spacer().frame(height: 2)

            // App Icon with gentle floating bounce on hover
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: max(28, height * 0.44), height: max(28, height * 0.44))
                .offset(y: isEmphasized ? sin(wavePhase * 1.5) * 2.5 : 0)
                .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)

            // Title
            Text(app.name)
                .font(.system(size: max(8.5, min(12.5, width * 0.076)), weight: .bold, design: .rounded))
                .foregroundStyle(Color(white: 0.16))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 6)

            // Category / Status
            Text(app.channelType != nil ? (app.channelType == .web ? "WEB" : "SHORTCUT") : app.category.uppercased())
                .font(.system(size: max(6, width * 0.048), weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(white: 0.42))
                .lineLimit(1)
                .padding(.bottom, max(3, height * 0.04))
        }
    }

    // MARK: - Animation Drivers
    private func updateAnimationState() {
        if isEmphasized {
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                rotationAngle = 360.0
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                wavePhase = .pi * 2
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                photoTilt = 6.0
            }
            triggerShimmer()
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                rotationAngle = 0.0
                wavePhase = 0.0
                photoTilt = 0.0
            }
        }
    }

    private func triggerShimmer() {
        shimmerOffset = -1.2
        withAnimation(.easeInOut(duration: 0.75)) {
            shimmerOffset = 1.2
        }
    }

    // MARK: - Custom Animated GIF / WebP Loader
    private func loadCustomAnimationIfNeeded() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let animDir = appSupport.appendingPathComponent("AppsChannel/Animations", isDirectory: true)

        let safeName = app.name.replacingOccurrences(of: " ", with: "_")
        let safeBundleID = app.bundleIdentifier ?? ""
        var candidates = [
            animDir.appendingPathComponent("\(safeName).gif"),
            animDir.appendingPathComponent("\(safeName).webp")
        ]
        if !safeBundleID.isEmpty {
            candidates.insert(animDir.appendingPathComponent("\(safeBundleID).gif"), at: 0)
            candidates.insert(animDir.appendingPathComponent("\(safeBundleID).webp"), at: 1)
        }

        for fileURL in candidates {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                loadFrames(from: fileURL)
                break
            }
        }
    }

    private func loadFrames(from url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        let count = CGImageSourceGetCount(source)
        guard count > 1 else { return }

        var loaded: [NSImage] = []
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                loaded.append(NSImage(cgImage: cgImage, size: NSSize(width: width, height: height)))
            }
        }

        guard !loaded.isEmpty else { return }
        self.gifFrames = loaded

        // Start playback timer
        frameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            currentFrameIndex = (currentFrameIndex + 1) % gifFrames.count
        }
    }
}
