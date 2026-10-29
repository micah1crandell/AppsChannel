import SwiftUI
import AppKit

struct FloatingLauncherHostView: View {
    @AppStorage("defaultMode") private var defaultModeSetting: String = LauncherMode.classicLauncher.rawValue
    @AppStorage("floatingLauncherStyle") private var floatingLauncherStyle: String = "classic"

    let onExpandToFullScreen: () -> Void
    let onDismiss: () -> Void

    private var isClassicMode: Bool {
        if floatingLauncherStyle == "classic" {
            return true
        } else if floatingLauncherStyle == "quick" {
            return false
        }
        return defaultModeSetting != LauncherMode.quickLauncher.rawValue
    }

    var body: some View {
        Group {
            if isClassicMode {
                ClassicLauncherView(
                    onExpandToFullScreen: onExpandToFullScreen,
                    onSwitchToQuickHUD: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            floatingLauncherStyle = "quick"
                        }
                    },
                    onDismiss: onDismiss
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            } else {
                QuickLauncherView(
                    onExpandToFullScreen: onExpandToFullScreen,
                    onSwitchToClassic: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            floatingLauncherStyle = "classic"
                        }
                    },
                    onDismiss: onDismiss
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isClassicMode)
    }
}
