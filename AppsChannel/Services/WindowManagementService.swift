import Foundation
import AppKit
import SwiftUI
import ApplicationServices
import Combine
import HotKey
import Carbon

// MARK: - Window Action Configuration
struct WindowActionConfig: Codable, Equatable, Sendable {
    var isEnabled: Bool
    var alias: String
    var keyCode: UInt32?
    var carbonModifiers: UInt32?
    var hotkeyLabel: String?

    init(
        isEnabled: Bool = true,
        alias: String = "",
        keyCode: UInt32? = nil,
        carbonModifiers: UInt32? = nil,
        hotkeyLabel: String? = nil
    ) {
        self.isEnabled = isEnabled
        self.alias = alias
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.hotkeyLabel = hotkeyLabel
    }
}

// MARK: - Window Management Service
@MainActor
final class WindowManagementService: ObservableObject {
    static let shared = WindowManagementService()

    @Published var isMasterEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isMasterEnabled, forKey: masterEnabledStorageKey)
            rebuildHotKeys()
        }
    }

    @Published var configs: [String: WindowActionConfig] = [:] {
        didSet {
            saveConfigs()
        }
    }

    @Published var isAccessibilityGranted: Bool = false

    /// The application that was frontmost before AppsChannel opened.
    var lastExternalApp: NSRunningApplication?

    private var registeredHotKeys: [WindowSnappingAction: HotKey] = [:]
    private var windowRestoreHistory: [pid_t: [CGRect]] = [:]

    private let configsStorageKey = "AppsChannelWindowActionConfigs_v1"
    private let masterEnabledStorageKey = "AppsChannelWindowManagement_MasterEnabled"

    private init() {
        if UserDefaults.standard.object(forKey: masterEnabledStorageKey) != nil {
            self.isMasterEnabled = UserDefaults.standard.bool(forKey: masterEnabledStorageKey)
        } else {
            self.isMasterEnabled = true
        }

        loadConfigs()
        checkAccessibility()
        setupAppSwitchObserver()
        rebuildHotKeys()
    }

    // MARK: - Accessibility
    func checkAccessibility() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        isAccessibilityGranted = AXIsProcessTrustedWithOptions(options)
        if !isAccessibilityGranted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Active App Observation
    private func setupAppSwitchObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                Task { @MainActor in
                    self.lastExternalApp = app
                }
            }
        }
    }

    // MARK: - App Discovery & Search Integration
    func allWindowActionApps() -> [DiscoveredApp] {
        guard isMasterEnabled else { return [] }
        return WindowSnappingAction.allCases.compactMap { (action: WindowSnappingAction) -> DiscoveredApp? in
            let conf = self.config(for: action)
            guard conf.isEnabled else { return nil }

            let iconSize = NSSize(width: 128, height: 128)
            let iconImage = NSImage(size: iconSize, flipped: false) { _ in
                let bgPath = NSBezierPath(roundedRect: NSRect(x: 16, y: 16, width: 96, height: 96), xRadius: 22, yRadius: 22)
                NSColor(red: 0.05, green: 0.52, blue: 1.0, alpha: 1.0).setFill()
                bgPath.fill()

                let symbolName: String
                switch action {
                case .maximize, .almostMaximize, .toggleFullscreen: symbolName = "arrow.up.left.and.arrow.down.right"
                case .maximizeHeight: symbolName = "arrow.up.and.down"
                case .maximizeWidth: symbolName = "arrow.left.and.right"
                case .makeLarger: symbolName = "plus"
                case .makeSmaller: symbolName = "minus"
                case .moveLeft: symbolName = "arrow.left"
                case .moveRight: symbolName = "arrow.right"
                case .moveTop: symbolName = "arrow.up"
                case .moveBottom: symbolName = "arrow.down"
                case .moveToNextDisplay: symbolName = "arrow.right.to.line"
                case .moveToPreviousDisplay: symbolName = "arrow.left.to.line"
                case .restore: symbolName = "arrow.counterclockwise"
                case .minimize: symbolName = "arrow.down.to.line"
                default: symbolName = "macwindow.on.rectangle"
                }

                let config = NSImage.SymbolConfiguration(pointSize: 44, weight: .bold)
                if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                    let tinted = symbol.copy() as! NSImage
                    tinted.lockFocus()
                    NSColor.white.set()
                    NSRect(origin: .zero, size: tinted.size).fill(using: .sourceIn)
                    tinted.unlockFocus()
                    let drawRect = NSRect(x: 32, y: 32, width: 64, height: 64)
                    tinted.draw(in: drawRect)
                    return true
                }
                return true
            }

            return DiscoveredApp(
                id: UUID(),
                name: action.title,
                url: URL(string: "window-snap://\(action.rawValue)")!,
                bundleIdentifier: "com.micahcrandell.AppsChannel.windowAction.\(action.rawValue)",
                icon: iconImage,
                category: "Window Management",
                tagBadge: conf.hotkeyLabel ?? "Snap",
                sizeString: "Action",
                accentColor: Color(red: 0.05, green: 0.52, blue: 1.0),
                windowAction: action
            )
        }
    }

    // MARK: - Configuration Persistence
    private func loadConfigs() {
        var loaded: [String: WindowActionConfig] = [:]
        if let data = UserDefaults.standard.data(forKey: configsStorageKey),
           let decoded = try? JSONDecoder().decode([String: WindowActionConfig].self, from: data) {
            loaded = decoded
        }

        // Populate defaults for any action not in storage
        for action in WindowSnappingAction.allCases {
            if loaded[action.rawValue] == nil {
                if let defaultCombo = action.defaultKeyCombo {
                    loaded[action.rawValue] = WindowActionConfig(
                        isEnabled: true,
                        alias: "",
                        keyCode: defaultCombo.keyCode,
                        carbonModifiers: defaultCombo.modifiers.carbonFlags,
                        hotkeyLabel: defaultCombo.label
                    )
                } else {
                    loaded[action.rawValue] = WindowActionConfig(isEnabled: true, alias: "")
                }
            }
        }

        self.configs = loaded
    }

    private func saveConfigs() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: configsStorageKey)
        }
    }

    func config(for action: WindowSnappingAction) -> WindowActionConfig {
        configs[action.rawValue] ?? WindowActionConfig()
    }

    func setEnabled(_ isEnabled: Bool, for action: WindowSnappingAction) {
        var current = config(for: action)
        current.isEnabled = isEnabled
        configs[action.rawValue] = current
        rebuildHotKeys()
    }

    func setAlias(_ alias: String, for action: WindowSnappingAction) {
        var current = config(for: action)
        current.alias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        configs[action.rawValue] = current
    }

    func setHotkey(keyCode: UInt32, carbonModifiers: UInt32, label: String, for action: WindowSnappingAction) {
        var current = config(for: action)
        current.keyCode = keyCode
        current.carbonModifiers = carbonModifiers
        current.hotkeyLabel = label
        configs[action.rawValue] = current
        rebuildHotKeys()
    }

    func clearHotkey(for action: WindowSnappingAction) {
        var current = config(for: action)
        current.keyCode = nil
        current.carbonModifiers = nil
        current.hotkeyLabel = nil
        configs[action.rawValue] = current
        rebuildHotKeys()
    }

    func resetToDefaults() {
        var fresh: [String: WindowActionConfig] = [:]
        for action in WindowSnappingAction.allCases {
            if let defaultCombo = action.defaultKeyCombo {
                fresh[action.rawValue] = WindowActionConfig(
                    isEnabled: true,
                    alias: "",
                    keyCode: defaultCombo.keyCode,
                    carbonModifiers: defaultCombo.modifiers.carbonFlags,
                    hotkeyLabel: defaultCombo.label
                )
            } else {
                fresh[action.rawValue] = WindowActionConfig(isEnabled: true, alias: "")
            }
        }
        self.configs = fresh
        self.isMasterEnabled = true
        rebuildHotKeys()
    }

    // MARK: - Global HotKeys
    func rebuildHotKeys() {
        registeredHotKeys.removeAll()

        guard isMasterEnabled else { return }

        for action in WindowSnappingAction.allCases {
            let conf = config(for: action)
            guard conf.isEnabled,
                  let keyCode = conf.keyCode,
                  let carbonMods = conf.carbonModifiers else {
                continue
            }

            let combo = KeyCombo(carbonKeyCode: keyCode, carbonModifiers: carbonMods)
            let hotKey = HotKey(keyCombo: combo)
            hotKey.keyDownHandler = { [weak self] in
                DispatchQueue.main.async {
                    self?.performAction(action)
                }
            }
            registeredHotKeys[action] = hotKey
        }
    }

    // MARK: - Window Snapping Execution
    func performAction(_ action: WindowSnappingAction) {
        checkAccessibility()
        guard isAccessibilityGranted else {
            requestAccessibilityPermission()
            return
        }

        // Determine target application:
        // If AppsChannel is currently active, dismiss AppsChannel and use lastExternalApp
        let targetApp: NSRunningApplication?
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
            PanelController.shared.hide()
            targetApp = lastExternalApp ?? NSWorkspace.shared.runningApplications.first(where: {
                $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier
            })
        } else {
            targetApp = NSWorkspace.shared.frontmostApplication
        }

        guard let app = targetApp, app.processIdentifier > 0 else { return }

        // Activate target app if needed
        app.activate(options: [.activateIgnoringOtherApps])

        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = getTargetWindow(for: axApp) else { return }

        switch action {
        case .minimize:
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            return

        case .toggleFullscreen:
            var fullScreenValue: CFTypeRef?
            let fullScreenKey = "AXFullScreen" as CFString
            if AXUIElementCopyAttributeValue(window, fullScreenKey, &fullScreenValue) == .success,
               let isFull = fullScreenValue as? Bool {
                let nextVal: CFBoolean = isFull ? kCFBooleanFalse : kCFBooleanTrue
                AXUIElementSetAttributeValue(window, fullScreenKey, nextVal)
            }
            return

        case .restore:
            if var history = windowRestoreHistory[app.processIdentifier], let prevFrame = history.popLast() {
                windowRestoreHistory[app.processIdentifier] = history
                applyFrame(prevFrame, to: window)
            }
            return

        case .moveToNextDisplay:
            moveWindowToDisplay(window: window, pid: app.processIdentifier, next: true)
            return

        case .moveToPreviousDisplay:
            moveWindowToDisplay(window: window, pid: app.processIdentifier, next: false)
            return

        default:
            break
        }

        // Positional or Sizing Action
        guard let currentFrame = getWindowFrame(window) else { return }

        // Save current frame for restore/undo
        var history = windowRestoreHistory[app.processIdentifier] ?? []
        history.append(currentFrame)
        if history.count > 10 { history.removeFirst() }
        windowRestoreHistory[app.processIdentifier] = history

        // Determine screen
        guard let screen = getScreenContaining(frame: currentFrame) else { return }
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height

        let targetFrame = Self.calculateTargetFrame(
            action: action,
            currentFrame: currentFrame,
            screenVisibleFrame: screen.visibleFrame,
            primaryScreenHeight: primaryScreenHeight
        )

        applyFrame(targetFrame, to: window)
    }

    // MARK: - Multi-Display Transfer
    private func moveWindowToDisplay(window: AXUIElement, pid: pid_t, next: Bool) {
        guard NSScreen.screens.count > 1 else { return }
        guard let currentFrame = getWindowFrame(window) else { return }
        guard let currentScreen = getScreenContaining(frame: currentFrame) else { return }

        let screens = NSScreen.screens
        guard let currentIndex = screens.firstIndex(of: currentScreen) else { return }

        let targetIndex: Int
        if next {
            targetIndex = (currentIndex + 1) % screens.count
        } else {
            targetIndex = (currentIndex - 1 + screens.count) % screens.count
        }
        let targetScreen = screens[targetIndex]

        let primaryScreenHeight = screens.first?.frame.height ?? targetScreen.frame.height

        let currentAXScreen = Self.cocoaToAXRect(currentScreen.visibleFrame, primaryScreenHeight: primaryScreenHeight)
        let targetAXScreen = Self.cocoaToAXRect(targetScreen.visibleFrame, primaryScreenHeight: primaryScreenHeight)

        // Calculate relative position and proportion
        let relX = (currentFrame.origin.x - currentAXScreen.origin.x) / max(1.0, currentAXScreen.size.width)
        let relY = (currentFrame.origin.y - currentAXScreen.origin.y) / max(1.0, currentAXScreen.size.height)
        let relW = currentFrame.size.width / max(1.0, currentAXScreen.size.width)
        let relH = currentFrame.size.height / max(1.0, currentAXScreen.size.height)

        let newW = min(targetAXScreen.size.width, max(200.0, relW * targetAXScreen.size.width))
        let newH = min(targetAXScreen.size.height, max(150.0, relH * targetAXScreen.size.height))
        var newX = targetAXScreen.origin.x + (relX * targetAXScreen.size.width)
        var newY = targetAXScreen.origin.y + (relY * targetAXScreen.size.height)

        // Clamp to target screen visible frame
        newX = max(targetAXScreen.origin.x, min(newX, targetAXScreen.maxX - newW))
        newY = max(targetAXScreen.origin.y, min(newY, targetAXScreen.maxY - newH))

        let targetFrame = CGRect(x: newX, y: newY, width: newW, height: newH)

        var history = windowRestoreHistory[pid] ?? []
        history.append(currentFrame)
        windowRestoreHistory[pid] = history

        applyFrame(targetFrame, to: window)
    }

    // MARK: - Frame Calculation (Pure & Testable)
    static func calculateTargetFrame(
        action: WindowSnappingAction,
        currentFrame: CGRect,
        screenVisibleFrame: CGRect,
        primaryScreenHeight: CGFloat
    ) -> CGRect {
        let axScreen = cocoaToAXRect(screenVisibleFrame, primaryScreenHeight: primaryScreenHeight)
        let sx = axScreen.origin.x
        let sy = axScreen.origin.y
        let sw = axScreen.size.width
        let sh = axScreen.size.height

        switch action {
        // MARK: Halves
        case .leftHalf:
            return CGRect(x: sx, y: sy, width: sw / 2, height: sh)
        case .rightHalf:
            return CGRect(x: sx + sw / 2, y: sy, width: sw / 2, height: sh)
        case .topHalf:
            return CGRect(x: sx, y: sy, width: sw, height: sh / 2)
        case .bottomHalf:
            return CGRect(x: sx, y: sy + sh / 2, width: sw, height: sh / 2)
        case .centerHalf:
            let w = sw / 2
            return CGRect(x: sx + (sw - w) / 2, y: sy, width: w, height: sh)

        // MARK: Thirds & Two-Thirds
        case .firstThird:
            return CGRect(x: sx, y: sy, width: sw / 3, height: sh)
        case .centerThird:
            return CGRect(x: sx + sw / 3, y: sy, width: sw / 3, height: sh)
        case .lastThird:
            let thirdW = sw / 3
            return CGRect(x: sx + 2 * thirdW, y: sy, width: sw - 2 * thirdW, height: sh)
        case .firstTwoThirds:
            return CGRect(x: sx, y: sy, width: 2 * (sw / 3), height: sh)
        case .centerTwoThirds:
            let w = 2 * (sw / 3)
            return CGRect(x: sx + (sw - w) / 2, y: sy, width: w, height: sh)
        case .lastTwoThirds:
            let thirdW = sw / 3
            return CGRect(x: sx + thirdW, y: sy, width: sw - thirdW, height: sh)
        case .topThird:
            return CGRect(x: sx, y: sy, width: sw, height: sh / 3)
        case .bottomThird:
            let thirdH = sh / 3
            return CGRect(x: sx, y: sy + 2 * thirdH, width: sw, height: sh - 2 * thirdH)
        case .topTwoThirds:
            return CGRect(x: sx, y: sy, width: sw, height: 2 * (sh / 3))
        case .bottomTwoThirds:
            let thirdH = sh / 3
            return CGRect(x: sx, y: sy + thirdH, width: sw, height: sh - thirdH)

        // MARK: Fourths & Three-Fourths
        case .firstFourth:
            return CGRect(x: sx, y: sy, width: sw / 4, height: sh)
        case .secondFourth:
            return CGRect(x: sx + sw / 4, y: sy, width: sw / 4, height: sh)
        case .thirdFourth:
            return CGRect(x: sx + 2 * (sw / 4), y: sy, width: sw / 4, height: sh)
        case .lastFourth:
            let fourthW = sw / 4
            return CGRect(x: sx + 3 * fourthW, y: sy, width: sw - 3 * fourthW, height: sh)
        case .firstThreeFourths:
            return CGRect(x: sx, y: sy, width: 3 * (sw / 4), height: sh)
        case .centerThreeFourths:
            let w = 3 * (sw / 4)
            return CGRect(x: sx + (sw - w) / 2, y: sy, width: w, height: sh)
        case .lastThreeFourths:
            let fourthW = sw / 4
            return CGRect(x: sx + fourthW, y: sy, width: sw - fourthW, height: sh)
        case .topFirstFourth:
            return CGRect(x: sx, y: sy, width: sw, height: sh / 4)
        case .topThreeFourths:
            return CGRect(x: sx, y: sy, width: sw, height: 3 * (sh / 4))
        case .bottomThreeFourths:
            let fourthH = sh / 4
            return CGRect(x: sx, y: sy + fourthH, width: sw, height: sh - fourthH)

        // MARK: Quarters (Corners)
        case .topLeftQuarter:
            return CGRect(x: sx, y: sy, width: sw / 2, height: sh / 2)
        case .topRightQuarter:
            return CGRect(x: sx + sw / 2, y: sy, width: sw / 2, height: sh / 2)
        case .bottomLeftQuarter:
            return CGRect(x: sx, y: sy + sh / 2, width: sw / 2, height: sh / 2)
        case .bottomRightQuarter:
            return CGRect(x: sx + sw / 2, y: sy + sh / 2, width: sw / 2, height: sh / 2)

        // MARK: Sixths
        case .topLeftSixth:
            return CGRect(x: sx, y: sy, width: sw / 3, height: sh / 2)
        case .topCenterSixth:
            return CGRect(x: sx + sw / 3, y: sy, width: sw / 3, height: sh / 2)
        case .topRightSixth:
            return CGRect(x: sx + 2 * (sw / 3), y: sy, width: sw - 2 * (sw / 3), height: sh / 2)
        case .bottomLeftSixth:
            return CGRect(x: sx, y: sy + sh / 2, width: sw / 3, height: sh / 2)
        case .bottomCenterSixth:
            return CGRect(x: sx + sw / 3, y: sy + sh / 2, width: sw / 3, height: sh / 2)
        case .bottomRightSixth:
            return CGRect(x: sx + 2 * (sw / 3), y: sy + sh / 2, width: sw - 2 * (sw / 3), height: sh / 2)

        // MARK: Maximize & Centering
        case .maximize:
            return CGRect(x: sx, y: sy, width: sw, height: sh)
        case .almostMaximize:
            let padding: CGFloat = 28.0
            return CGRect(x: sx + padding, y: sy + padding, width: max(300, sw - 2 * padding), height: max(200, sh - 2 * padding))
        case .maximizeHeight:
            return CGRect(x: currentFrame.origin.x, y: sy, width: currentFrame.width, height: sh)
        case .maximizeWidth:
            return CGRect(x: sx, y: currentFrame.origin.y, width: sw, height: currentFrame.height)
        case .center:
            let w = min(currentFrame.width, sw)
            let h = min(currentFrame.height, sh)
            return CGRect(x: sx + (sw - w) / 2, y: sy + (sh - h) / 2, width: w, height: h)
        case .reasonableSize:
            let w = sw * 0.72
            let h = sh * 0.80
            return CGRect(x: sx + (sw - w) / 2, y: sy + (sh - h) / 2, width: w, height: h)

        // MARK: Resize & Nudge
        case .makeLarger:
            let delta: CGFloat = 60.0
            let newW = min(sw, currentFrame.width + delta)
            let newH = min(sh, currentFrame.height + delta)
            let newX = max(sx, min(sx + sw - newW, currentFrame.origin.x - delta / 2))
            let newY = max(sy, min(sy + sh - newH, currentFrame.origin.y - delta / 2))
            return CGRect(x: newX, y: newY, width: newW, height: newH)

        case .makeSmaller:
            let delta: CGFloat = 60.0
            let newW = max(240, currentFrame.width - delta)
            let newH = max(180, currentFrame.height - delta)
            let newX = max(sx, min(sx + sw - newW, currentFrame.origin.x + delta / 2))
            let newY = max(sy, min(sy + sh - newH, currentFrame.origin.y + delta / 2))
            return CGRect(x: newX, y: newY, width: newW, height: newH)

        case .moveLeft:
            let step: CGFloat = 60.0
            let newX = max(sx, currentFrame.origin.x - step)
            return CGRect(x: newX, y: currentFrame.origin.y, width: currentFrame.width, height: currentFrame.height)

        case .moveRight:
            let step: CGFloat = 60.0
            let newX = min(sx + sw - currentFrame.width, currentFrame.origin.x + step)
            return CGRect(x: newX, y: currentFrame.origin.y, width: currentFrame.width, height: currentFrame.height)

        case .moveTop:
            let step: CGFloat = 60.0
            let newY = max(sy, currentFrame.origin.y - step)
            return CGRect(x: currentFrame.origin.x, y: newY, width: currentFrame.width, height: currentFrame.height)

        case .moveBottom:
            let step: CGFloat = 60.0
            let newY = min(sy + sh - currentFrame.height, currentFrame.origin.y + step)
            return CGRect(x: currentFrame.origin.x, y: newY, width: currentFrame.width, height: currentFrame.height)

        default:
            return currentFrame
        }
    }

    // MARK: - Coordinate Transformations
    static func cocoaToAXRect(_ cocoaRect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        let axX = cocoaRect.origin.x
        let axY = primaryScreenHeight - (cocoaRect.origin.y + cocoaRect.size.height)
        return CGRect(x: axX, y: axY, width: cocoaRect.size.width, height: cocoaRect.size.height)
    }

    private func getScreenContaining(frame: CGRect) -> NSScreen? {
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 1080.0
        let centerX = frame.midX
        let centerY = primaryScreenHeight - frame.midY
        let cocoaPoint = NSPoint(x: centerX, y: centerY)

        for screen in NSScreen.screens {
            if screen.frame.contains(cocoaPoint) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    // MARK: - AXUIElement Helpers
    private func getTargetWindow(for axApp: AXUIElement) -> AXUIElement? {
        var focusedWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let window = focusedWindow {
            return (window as! AXUIElement)
        }

        var mainWindow: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &mainWindow) == .success,
           let window = mainWindow {
            return (window as! AXUIElement)
        }

        var windowsList: CFTypeRef?
        if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsList) == .success,
           let array = windowsList as? [AXUIElement], let first = array.first {
            return first
        }

        return nil
    }

    private func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        var posVal: CFTypeRef?
        var sizeVal: CFTypeRef?

        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posVal) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeVal) == .success,
              let posValue = posVal, let sizeValue = sizeVal else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero

        AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        return CGRect(origin: point, size: size)
    }

    private func applyFrame(_ frame: CGRect, to window: AXUIElement) {
        var pt = frame.origin
        var sz = frame.size

        if let posVal = AXValueCreate(.cgPoint, &pt) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        }
        if let sizeVal = AXValueCreate(.cgSize, &sz) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
        }
        // Double-pass position in case the app clamped size and shifted
        if let posVal = AXValueCreate(.cgPoint, &pt) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        }
    }
}
