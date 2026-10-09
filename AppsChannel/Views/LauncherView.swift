import SwiftUI
import AppKit

struct LauncherView: View {
    @AppStorage("defaultMode") private var defaultModeSetting: String = LauncherMode.quickLauncher.rawValue
    @State private var currentMode: LauncherMode = .quickLauncher

    var body: some View {
        ZStack {
            switch currentMode {
            case .quickLauncher:
                quickLauncherContainer
                    .transition(.scale(scale: 0.94).combined(with: .opacity))

            case .fullScreen:
                MainAppView(
                    onSwitchToQuickLauncher: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            currentMode = .quickLauncher
                        }
                    },
                    onDismiss: {
                        PanelController.shared.hide()
                    }
                )
                .transition(.scale(scale: 1.04).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear {
            if let mode = LauncherMode(rawValue: defaultModeSetting) {
                currentMode = mode
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .panelDidShow)) { notification in
            if let targetMode = notification.object as? LauncherMode {
                currentMode = targetMode
            } else if let mode = LauncherMode(rawValue: defaultModeSetting) {
                currentMode = mode
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentMode)
    }

    // MARK: - Quick Launcher Mode Container
    private var quickLauncherContainer: some View {
        ZStack {
            // Invisible dismiss backdrop (clicking outside the 820x480 HUD closes it)
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    PanelController.shared.hide()
                }

            // Spotlight-style floating HUD
            QuickLauncherView(
                onExpandToFullScreen: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        currentMode = .fullScreen
                    }
                },
                onDismiss: {
                    PanelController.shared.hide()
                }
            )
        }
    }
}
