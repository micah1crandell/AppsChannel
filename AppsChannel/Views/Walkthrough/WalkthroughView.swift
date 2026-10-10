import SwiftUI
import AppKit

// MARK: - Real App Icon Provider
struct AppIconProvider {
    static var appsChannelIcon: NSImage {
        if let img = NSImage(named: "AppIcon"), img.isValid {
            return img
        }
        if let img = NSImage(named: NSImage.Name("AppIcon")), img.isValid {
            return img
        }
        if let appIcon = NSApp.applicationIconImage, appIcon.isValid {
            return appIcon
        }
        return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }

    static func icon(for name: String, fallbackBundleId: String? = nil) -> NSImage {
        // 1. Check if asking for AppsChannel itself
        if name.localizedCaseInsensitiveCompare("AppsChannel") == .orderedSame {
            return appsChannelIcon
        }

        // 2. Search already discovered applications from user's system
        if let found = AppDiscoveryService.shared.apps.first(where: {
            $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame ||
            $0.name.localizedCaseInsensitiveContains(name)
        }) {
            return found.icon
        }

        // 3. Search system application by bundle identifier
        if let bundleId = fallbackBundleId,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            let img = NSWorkspace.shared.icon(forFile: url.path)
            img.size = NSSize(width: 160, height: 160)
            return img
        }

        // 4. Search standard macOS directories
        let searchPaths = [
            "/System/Applications/\(name).app",
            "/Applications/\(name).app",
            "/System/Applications/Utilities/\(name).app",
            "/System/Library/CoreServices/\(name).app"
        ]
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                let img = NSWorkspace.shared.icon(forFile: path)
                img.size = NSSize(width: 160, height: 160)
                return img
            }
        }

        // 5. Fallback Finder icon
        return NSWorkspace.shared.icon(forFile: "/System/Library/CoreServices/Finder.app")
    }
}

// MARK: - Walkthrough View
struct WalkthroughView: View {
    @Binding var isPresented: Bool
    var onComplete: (() -> Void)? = nil

    @State private var currentStep: Int = 0
    @State private var previewPerspective: Int = 1 // 0: Icon Flow, 1: Cards Flow, 2: Wall Grid
    @State private var cardTilt: CGSize = .zero
    @State private var isHoveringCard: Bool = false
    @State private var pulseGlow: Bool = false
    @AppStorage("hasCompletedWalkthrough") private var hasCompletedWalkthrough: Bool = false

    private let totalSteps = 5

    var body: some View {
        ZStack {
            // Ambient Backdrop Glow
            RadialGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.02),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 450
            )
            .blur(radius: 40)
            .allowsHitTesting(false)

            // Main Walkthrough Window Container
            VStack(spacing: 0) {
                // Header Bar
                headerBar

                Divider()
                    .background(Color.white.opacity(0.08))

                // Slide Content with Animated Transitions
                ZStack {
                    switch currentStep {
                    case 0:
                        slideWelcome
                            .transition(slideTransition)
                    case 1:
                        slideSummon
                            .transition(slideTransition)
                    case 2:
                        slidePerspectives
                            .transition(slideTransition)
                    case 3:
                        slideNavigation
                            .transition(slideTransition)
                    case 4:
                        slideOrganizeAndLaunch
                            .transition(slideTransition)
                    default:
                        EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                Divider()
                    .background(Color.white.opacity(0.08))

                // Footer Bar (Step Indicators & Navigation Buttons)
                footerBar
            }
            .frame(width: 780, height: 530)
            .background(
                ZStack {
                    VisualEffectBackground(material: .popover, blendingMode: .withinWindow)
                    Color(red: 0.05, green: 0.05, blue: 0.07).opacity(0.93)
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear,
                            Color.black.opacity(0.4)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.75), radius: 40, x: 0, y: 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .walkthroughNext)) { _ in
            nextStep()
        }
        .onReceive(NotificationCenter.default.publisher(for: .walkthroughPrevious)) { _ in
            previousStep()
        }
    }

    private var slideTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.97)),
            removal: .opacity.combined(with: .scale(scale: 1.02))
        )
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))

                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("APPSCHANNEL WALKTHROUGH")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .tracking(1.2)
            }

            Spacer()

            // Skip / Dismiss Button
            Button(action: finishWalkthrough) {
                HStack(spacing: 5) {
                    Text("Skip Tour")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                    Text("⎋")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .opacity(0.7)
                }
                .foregroundStyle(.white.opacity(0.65))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Skip Walkthrough (Esc)")
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 13)
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack {
            // Left: Back button
            if currentStep > 0 {
                Button(action: previousStep) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text("Back")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            } else {
                Spacer().frame(width: 70)
            }

            Spacer()

            // Center: Smooth Step Indicators
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index == currentStep ? Color.white : Color.white.opacity(0.25))
                        .frame(width: index == currentStep ? 24 : 7, height: 7)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentStep)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentStep = index
                                SoundEffectsManager.shared.playNavigation()
                            }
                        }
                }
            }

            Spacer()

            // Right: Continue / Finish Button
            if currentStep < totalSteps - 1 {
                Button(action: nextStep) {
                    HStack(spacing: 6) {
                        Text("Continue")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white, lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.white.opacity(0.25), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: finishWalkthrough) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                        Text("Get Started")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.white, Color(white: 0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white, lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.white.opacity(0.35), radius: 10, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    // MARK: - Slide 0: What is AppsChannel?
    private var slideWelcome: some View {
        VStack(spacing: 20) {
            Spacer()

            // Animated 3D Floating Channel Cards with Real App Icons
            HStack(spacing: 28) {
                // Left ghost card (Music)
                miniCoverFlowCard(
                    title: "Music",
                    icon: AppIconProvider.icon(for: "Music", fallbackBundleId: "com.apple.Music"),
                    accent: .pink,
                    category: "AUDIO",
                    angleY: 28,
                    scale: 0.82,
                    offsetZ: -40
                )

                // Center hero card (Actual AppsChannel app icon with real 3D tilt)
                miniHeroChannelCard(
                    title: "AppsChannel",
                    icon: AppIconProvider.appsChannelIcon,
                    accent: .blue,
                    category: "LAUNCHER"
                )

                // Right ghost card (Terminal)
                miniCoverFlowCard(
                    title: "Terminal",
                    icon: AppIconProvider.icon(for: "Terminal", fallbackBundleId: "com.apple.Terminal"),
                    accent: .green,
                    category: "DEV",
                    angleY: -28,
                    scale: 0.82,
                    offsetZ: -40
                )
            }
            .frame(height: 180)

            VStack(spacing: 8) {
                Text("A visual app launcher for Mac.")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Inspired by Cover Flow and retro channel menus—fast, clean, and out of your way.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 580)
            }

            // Indie Feature Badges
            HStack(spacing: 12) {
                featureBadge(icon: "bolt.fill", title: "Hardware accelerated")
                featureBadge(icon: "hand.raised.fill", title: "Zero telemetry or tracking")
                featureBadge(icon: "chart.line.uptrend.xyaxis", title: "Smart usage-based sorting")
            }

            Spacer()
        }
        .padding(.horizontal, 30)
    }

    // MARK: - Slide 1: Dual Launcher Experiences
    private var slideSummon: some View {
        VStack(spacing: 22) {
            Spacer()

            VStack(spacing: 6) {
                Text("Available anywhere on your screen.")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Runs in your menu bar and opens over any full-screen app or desktop space.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 580)
            }

            // Dual Launcher Cards Comparison
            HStack(spacing: 18) {
                // Quick Launcher Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 36, height: 36)
                            Image(systemName: "sparkle.magnifyingglass")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.blue)
                        }

                        Spacer()

                        // Keycap
                        HStack(spacing: 4) {
                            KeyCapView(symbol: "⌥")
                            KeyCapView(symbol: "L")
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Launcher")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("A minimal pop-up to launch an app and get right back to work.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.68))
                            .lineSpacing(2)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                        Text("Default global launcher")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(16)
                .frame(width: 320, height: 185)
                .background(Color(white: 0.08).opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )

                // Main App Window Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.purple.opacity(0.2))
                                .frame(width: 36, height: 36)
                            Image(systemName: "macwindow")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.purple)
                        }

                        Spacer()

                        // Keycap
                        HStack(spacing: 4) {
                            KeyCapView(symbol: "⌘")
                            KeyCapView(symbol: "0")
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Main Window")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("A dedicated window to browse, sort, and organize your entire app library.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.68))
                            .lineSpacing(2)
                    }

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Full-featured browser & arranger")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(16)
                .frame(width: 320, height: 185)
                .background(Color(white: 0.08).opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
            }

            Spacer()
        }
        .padding(.horizontal, 30)
    }

    // MARK: - Slide 2: Three Visual Perspectives
    private var slidePerspectives: some View {
        VStack(spacing: 18) {
            Spacer()

            VStack(spacing: 6) {
                Text("Three ways to view your apps.")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Press Command + V to switch views anytime.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.72))
            }

            // Interactive Perspective Mode Selector
            HStack(spacing: 12) {
                perspectiveTab(
                    index: 0,
                    title: "Icon Flow",
                    icon: "square.grid.2x2.fill",
                    desc: "Clean Cover Flow layout centered on your app icons."
                )
                perspectiveTab(
                    index: 1,
                    title: "Channel Cards",
                    icon: "rectangle.grid.2x2.fill",
                    desc: "Tactile channel cards that display category tags and running status."
                )
                perspectiveTab(
                    index: 2,
                    title: "Wall Grid",
                    icon: "circle.grid.3x3.fill",
                    desc: "A wide grid to scan your entire app collection at once."
                )
            }

            // Interactive Live Mini-Preview with REAL APP ICONS
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.04).opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )

                if previewPerspective == 0 {
                    // Minimalist App Icon Flow Preview (Featuring Real macOS Icons & AppsChannel)
                    HStack(spacing: 24) {
                        ForEach(["Safari", "Music", "AppsChannel", "Terminal", "Photos"], id: \.self) { name in
                            let isCenter = (name == "AppsChannel")
                            let realIcon = AppIconProvider.icon(for: name)

                            VStack(spacing: 6) {
                                Image(nsImage: realIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: isCenter ? 44 : 32, height: isCenter ? 44 : 32)
                                    .shadow(
                                        color: isCenter ? Color.blue.opacity(0.7) : Color.black.opacity(0.35),
                                        radius: isCenter ? 12 : 4,
                                        x: 0,
                                        y: isCenter ? 5 : 2
                                    )
                                    .overlay(
                                        Group {
                                            if isCenter {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .strokeBorder(
                                                        LinearGradient(
                                                            colors: [Color.white, Color.white.opacity(0.35)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 2
                                                    )
                                                    .padding(-3)
                                            }
                                        }
                                    )
                                    .scaleEffect(isCenter ? 1.15 : 0.88)

                                Text(name)
                                    .font(.system(size: 10, weight: isCenter ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(isCenter ? .white : .white.opacity(0.65))
                            }
                        }
                    }
                    .transition(.opacity)
                } else if previewPerspective == 1 {
                    // Channel Cards Preview (Featuring Real macOS Icons & AppsChannel)
                    HStack(spacing: 16) {
                        miniChannelCardPreview(
                            name: "Safari",
                            cat: "WEB",
                            icon: AppIconProvider.icon(for: "Safari", fallbackBundleId: "com.apple.Safari"),
                            accent: .blue,
                            isCenter: false
                        )
                        miniChannelCardPreview(
                            name: "AppsChannel",
                            cat: "LAUNCHER",
                            icon: AppIconProvider.appsChannelIcon,
                            accent: .cyan,
                            isCenter: true
                        )
                        miniChannelCardPreview(
                            name: "Terminal",
                            cat: "DEV",
                            icon: AppIconProvider.icon(for: "Terminal", fallbackBundleId: "com.apple.Terminal"),
                            accent: .green,
                            isCenter: false
                        )
                    }
                    .transition(.opacity)
                } else {
                    // Curved Wall Grid Preview (Featuring 2 Rows of Real macOS Icons)
                    VStack(spacing: 6) {
                        ForEach(0..<2, id: \.self) { row in
                            HStack(spacing: 8) {
                                let rowApps = (row == 0)
                                    ? ["Finder", "Safari", "AppsChannel", "Terminal", "Music"]
                                    : ["Arc", "Calendar", "Calculator", "Photos", "Settings"]

                                ForEach(0..<rowApps.count, id: \.self) { col in
                                    let appName = rowApps[col]
                                    let isHighlighted = (row == 0 && col == 2)
                                    let realIcon = AppIconProvider.icon(for: appName)

                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isHighlighted ? Color.white.opacity(0.24) : Color.white.opacity(0.08))
                                        .frame(width: 58, height: 32)
                                        .overlay(
                                            HStack(spacing: 4) {
                                                Image(nsImage: realIcon)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 16, height: 16)

                                                Text(appName)
                                                    .font(.system(size: 8, weight: isHighlighted ? .bold : .medium, design: .rounded))
                                                    .foregroundStyle(isHighlighted ? .white : .white.opacity(0.75))
                                                    .lineLimit(1)
                                            }
                                            .padding(.horizontal, 4)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .strokeBorder(
                                                    isHighlighted ? Color.white : Color.white.opacity(0.12),
                                                    lineWidth: isHighlighted ? 1.5 : 0.5
                                                )
                                        )
                                }
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: 660, height: 95)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: previewPerspective)

            Spacer()
        }
        .padding(.horizontal, 30)
    }

    private func perspectiveTab(index: Int, title: String, icon: String, desc: String) -> some View {
        let isSelected = previewPerspective == index
        return Button(action: {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                previewPerspective = index
                SoundEffectsManager.shared.playAction()
            }
        }) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isSelected ? Color.black : Color.white.opacity(0.85))

                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.black : Color.white)

                    Spacer()

                    if isSelected {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 6, height: 6)
                    }
                }

                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.black.opacity(0.75) : Color.white.opacity(0.55))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(width: 212, height: 78)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.white : Color(white: 0.08).opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.white : Color.white.opacity(0.14), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Slide 3: Fast Navigation & Shortcuts
    private var slideNavigation: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 6) {
                Text("Built for your keyboard.")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Find and open apps in a single keystroke without reaching for your mouse.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.72))
            }

            // Keyboard Shortcut Cheat Sheet Matrix
            VStack(spacing: 9) {
                HStack(spacing: 12) {
                    shortcutTile(
                        keys: ["←", "→"],
                        label: "Left / Right Arrows",
                        desc: "Scroll through apps"
                    )
                    shortcutTile(
                        keys: ["Return"],
                        label: "Return",
                        desc: "Open selected app"
                    )
                }

                HStack(spacing: 12) {
                    shortcutTile(
                        keys: ["⌥", "1-9"],
                        label: "Option + 1–9",
                        desc: "Launch your top pinned apps directly"
                    )
                    shortcutTile(
                        keys: ["Type..."],
                        label: "Type anywhere",
                        desc: "Search instantly"
                    )
                }

                HStack(spacing: 12) {
                    shortcutTile(
                        keys: ["⌘", "1-8"],
                        label: "Command + 1–8",
                        desc: "Filter by category"
                    )
                    shortcutTile(
                        keys: ["⌘", ","],
                        label: "Command + Comma",
                        desc: "Open preferences"
                    )
                }
            }
            .frame(width: 660)

            Spacer()
        }
        .padding(.horizontal, 30)
    }

    private func shortcutTile(keys: [String], label: String, desc: String) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { k in
                    KeyCapView(symbol: k)
                }
            }
            .frame(width: 70, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.08).opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Slide 4: Organize Mode & Ready to Launch
    private var slideOrganizeAndLaunch: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 6) {
                Text("Keep your most-used apps within reach.")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Pin apps in custom slots, or let smart sorting surface what you open most.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 580)
            }

            // Organization Features Comparison
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.orange.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Manual Organization")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Use Option + Arrows or click the hand icon to drag cards into custom positions.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer()
                }

                Divider().background(Color.white.opacity(0.08))

                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.blue.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Smart Center Sorting")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Automatically places your most frequently opened app in the center slot and fans the rest outward.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer()
                }
            }
            .padding(16)
            .frame(width: 660)
            .background(Color(white: 0.08).opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )

            // Indie Tagline
            Text("Crafted with nostalgia & care for macOS. You're ready to glide!")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            Spacer()
        }
        .padding(.horizontal, 30)
    }

    // MARK: - Navigation Actions
    func nextStep() {
        if currentStep < totalSteps - 1 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentStep += 1
            }
            SoundEffectsManager.shared.playNavigation()
        } else {
            finishWalkthrough()
        }
    }

    func previousStep() {
        if currentStep > 0 {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                currentStep -= 1
            }
            SoundEffectsManager.shared.playNavigation()
        }
    }

    func finishWalkthrough() {
        SoundEffectsManager.shared.playLaunch()
        hasCompletedWalkthrough = true
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isPresented = false
        }
        onComplete?()
    }

    // MARK: - Mini Visual Helpers
    private func featureBadge(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
    }

    private func miniHeroChannelCard(title: String, icon: NSImage, accent: Color, category: String) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack {
                    Text(category)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                    Spacer()
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)

                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .shadow(color: accent.opacity(0.75), radius: 14)
                    .scaleEffect(isHoveringCard ? 1.06 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHoveringCard)

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()
            }
            .frame(width: 140, height: 130)
            .background(
                ZStack {
                    Color(white: 0.12)
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.clear, Color.black.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.6), Color.white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: accent.opacity(0.4), radius: 20, x: 0, y: 8)

            // Mirror Glass Reflection
            LinearGradient(
                colors: [Color.white.opacity(0.18), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 130, height: 26)
            .blur(radius: 1)
            .mask(
                LinearGradient(
                    colors: [Color.white.opacity(0.5), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .rotation3DEffect(
            .degrees(Double(cardTilt.width)),
            axis: (x: 0, y: 1, z: 0)
        )
        .rotation3DEffect(
            .degrees(Double(-cardTilt.height)),
            axis: (x: 1, y: 0, z: 0)
        )
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHoveringCard = hovering
                if !hovering {
                    cardTilt = .zero
                }
            }
        }
    }

    private func miniCoverFlowCard(
        title: String,
        icon: NSImage,
        accent: Color,
        category: String,
        angleY: Double,
        scale: CGFloat,
        offsetZ: CGFloat
    ) -> some View {
        VStack(spacing: 6) {
            VStack(spacing: 6) {
                Text(category)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 6)

                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .shadow(color: accent.opacity(0.5), radius: 8)

                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()
            }
            .frame(width: 100, height: 95)
            .background(Color(white: 0.1).opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )

            // Reflection
            LinearGradient(
                colors: [Color.white.opacity(0.1), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 90, height: 18)
        }
        .scaleEffect(scale)
        .rotation3DEffect(
            .degrees(angleY),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.4
        )
    }

    private func miniChannelCardPreview(name: String, cat: String, icon: NSImage, accent: Color, isCenter: Bool) -> some View {
        VStack(spacing: 3) {
            HStack {
                Text(cat)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Circle()
                    .fill(accent)
                    .frame(width: 4, height: 4)
            }
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: isCenter ? 26 : 20, height: isCenter ? 26 : 20)
                .shadow(color: accent.opacity(0.6), radius: isCenter ? 8 : 4)

            Text(name)
                .font(.system(size: 9, weight: isCenter ? .bold : .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(8)
        .frame(width: 110, height: 65)
        .background(Color.white.opacity(isCenter ? 0.16 : 0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isCenter ? Color.white : Color.white.opacity(0.15), lineWidth: isCenter ? 1.5 : 1)
        )
        .scaleEffect(isCenter ? 1.05 : 0.95)
    }
}

// MARK: - Tactile Indie Keycap Component
struct KeyCapView: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3.5)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(white: 0.18))
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.5), radius: 2, x: 0, y: 1)
    }
}

extension Notification.Name {
    static let walkthroughNext = Notification.Name("AppsChannelWalkthroughNext")
    static let walkthroughPrevious = Notification.Name("AppsChannelWalkthroughPrevious")
    static let openWalkthrough = Notification.Name("AppsChannelOpenWalkthrough")
}
