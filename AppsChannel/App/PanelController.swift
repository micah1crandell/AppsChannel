import AppKit
import SwiftUI

final class AppsChannelPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class MainAppWindowDelegate: NSObject, NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false // Keep in memory so state, ordering, and caches remain alive
    }
}

final class PanelController {
    static let shared = PanelController()

    private var mainAppWindow: NSWindow?
    private var quickLauncherPanel: AppsChannelPanel?
    private let windowDelegate = MainAppWindowDelegate()

    var isVisible: Bool {
        (mainAppWindow?.isVisible == true) || (quickLauncherPanel?.isVisible == true)
    }

    private var lastQuickShowTime: Date = .distantPast

    func setup() {
        setupQuickLauncherPanel()
        setupMainAppWindow()
        setupScreenChangeObserver()
    }

    private func setupScreenChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenParametersChanged()
        }
    }

    @objc private func handleScreenParametersChanged() {
        let activeScreen = Self.targetScreenForPointer()
        if let panel = quickLauncherPanel {
            panel.setFrame(activeScreen.frame, display: true)
        }
        if let window = mainAppWindow, window.isVisible {
            repositionWindowInsideVisibleScreen(window, on: activeScreen)
        }
    }

    static func targetScreenForPointer() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return screen
        }
        return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
    }

    private func repositionWindowInsideVisibleScreen(_ window: NSWindow, on targetScreen: NSScreen? = nil) {
        let screen = (targetScreen ?? Self.targetScreenForPointer()).visibleFrame
        var curFrame = window.frame

        // Clamp window dimensions if they exceed visible screen bounds (e.g. moving from large external monitor to laptop screen)
        if curFrame.width > screen.width || curFrame.height > screen.height {
            let clampedWidth = min(curFrame.width, max(window.minSize.width, screen.width * 0.92))
            let clampedHeight = min(curFrame.height, max(window.minSize.height, screen.height * 0.90))
            curFrame.size = NSSize(width: clampedWidth, height: clampedHeight)
            window.setFrame(curFrame, display: true)
        }

        let newX = max(screen.minX, min(screen.midX - (curFrame.width / 2), screen.maxX - curFrame.width))
        let newY = max(screen.minY, min(screen.midY - (curFrame.height / 2), screen.maxY - curFrame.height))
        window.setFrameOrigin(NSPoint(x: newX, y: newY))
    }

    private func setupQuickLauncherPanel() {
        let screenRect = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let panel = AppsChannelPanel(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        let quickHostView = ZStack {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    self.quickLauncherPanel?.orderOut(nil)
                }

            QuickLauncherView(
                onExpandToFullScreen: {
                    self.showMainApp()
                },
                onDismiss: {
                    self.quickLauncherPanel?.orderOut(nil)
                }
            )
        }

        let hostingView = NSHostingView(rootView: quickHostView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        self.quickLauncherPanel = panel

        // Quick Launcher (Spotlight mode): dismisses when losing key focus
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            // Ignore resignKey if panel was shown within 0.5s to prevent shortcut runner / launch race
            if Date().timeIntervalSince(self.lastQuickShowTime) < 0.5 {
                return
            }
            self.quickLauncherPanel?.orderOut(nil)
        }
    }

    private func setupMainAppWindow() {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let defaultWidth = min(1280.0, max(1060.0, screen.width * 0.88))
        let defaultHeight = min(820.0, max(680.0, screen.height * 0.85))
        let initialRect = NSRect(
            x: screen.midX - (defaultWidth / 2),
            y: screen.midY - (defaultHeight / 2),
            width: defaultWidth,
            height: defaultHeight
        )

        // Real Frameless macOS Window with native traffic lights, resizability, and dragging
        let window = NSWindow(
            contentRect: initialRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.minSize = NSSize(width: 960, height: 620)
        window.collectionBehavior = [.fullScreenPrimary]
        window.delegate = windowDelegate

        let mainView = MainAppView(
            onSwitchToQuickLauncher: { [weak self] in
                self?.showQuickLauncher()
            },
            onDismiss: { [weak self] in
                self?.mainAppWindow?.orderOut(nil)
            }
        )

        let hostingView = NSHostingView(rootView: mainView)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = hostingView
        self.mainAppWindow = window
    }

    var isMainAppVisible: Bool {
        mainAppWindow?.isVisible == true
    }

    var isQuickLauncherVisible: Bool {
        quickLauncherPanel?.isVisible == true
    }

    func toggleMainApp() {
        if isMainAppVisible {
            hideMainApp()
        } else {
            showMainApp()
        }
    }

    func toggleQuickLauncher() {
        if isQuickLauncherVisible {
            quickLauncherPanel?.orderOut(nil)
        } else {
            showQuickLauncher()
        }
    }

    func hideMainApp() {
        mainAppWindow?.orderOut(nil)
    }

    func toggle() {
        toggleQuickLauncher()
    }

    func show(mode: LauncherMode? = nil) {
        let targetMode = mode ?? (UserDefaults.standard.string(forKey: "defaultMode").flatMap(LauncherMode.init) ?? .quickLauncher)
        switch targetMode {
        case .quickLauncher:
            showQuickLauncher()
        case .fullScreen:
            showMainApp()
        }
    }

    func showMainApp() {
        quickLauncherPanel?.orderOut(nil)
        guard let window = mainAppWindow else { return }

        // Position on target screen where mouse is currently located
        let targetScreen = Self.targetScreenForPointer()
        repositionWindowInsideVisibleScreen(window, on: targetScreen)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .panelDidShow, object: LauncherMode.fullScreen)
        AppDiscoveryService.shared.performBackgroundDeltaCheck()
    }

    func showQuickLauncher() {
        mainAppWindow?.orderOut(nil)
        guard let panel = quickLauncherPanel else { return }

        let targetScreen = Self.targetScreenForPointer()
        panel.setFrame(targetScreen.frame, display: true)

        lastQuickShowTime = Date()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
            panel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        NotificationCenter.default.post(name: .panelDidShow, object: LauncherMode.quickLauncher)
        AppDiscoveryService.shared.performBackgroundDeltaCheck()
    }

    func setDockVisibility(showInDock: Bool) {
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func hide() {
        quickLauncherPanel?.orderOut(nil)
        mainAppWindow?.orderOut(nil)
    }
}

extension Notification.Name {
    static let panelDidShow = Notification.Name("AppsChannelPanelDidShow")
}
