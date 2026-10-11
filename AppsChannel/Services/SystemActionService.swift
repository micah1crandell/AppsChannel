import AppKit
import SwiftUI
import Combine
import IOKit.pwr_mgt

// MARK: - System Action Type Enumeration
enum SystemActionType: String, CaseIterable, Codable, Sendable {
    case lockScreen = "lock_screen"
    case sleep = "sleep"
    case restart = "restart"
    case shutDown = "shut_down"
    case emptyTrash = "empty_trash"
    case toggleDarkMode = "toggle_dark_mode"
    case toggleMute = "toggle_mute"
    case toggleWifi = "toggle_wifi"
    case bluetoothSettings = "bluetooth_settings"

    var title: String {
        switch self {
        case .lockScreen: return "Lock Screen"
        case .sleep: return "Sleep"
        case .restart: return "Restart"
        case .shutDown: return "Shut Down"
        case .emptyTrash: return "Empty Trash"
        case .toggleDarkMode: return "Toggle Dark / Light Mode"
        case .toggleMute: return "Toggle Mute"
        case .toggleWifi: return "Toggle Wi-Fi"
        case .bluetoothSettings: return "Bluetooth Settings"
        }
    }

    var subtitle: String {
        switch self {
        case .lockScreen: return "Lock macOS screen immediately"
        case .sleep: return "Put your Mac to sleep"
        case .restart: return "Restart your computer"
        case .shutDown: return "Power off your computer"
        case .emptyTrash: return "Empty the system trash bin"
        case .toggleDarkMode: return "Switch between Light and Dark mode"
        case .toggleMute: return "Mute or unmute system audio"
        case .toggleWifi: return "Turn Wi-Fi power on or off"
        case .bluetoothSettings: return "Open macOS Bluetooth preferences"
        }
    }

    var iconSymbolName: String {
        switch self {
        case .lockScreen: return "lock.fill"
        case .sleep: return "moon.fill"
        case .restart: return "arrow.clockwise.circle.fill"
        case .shutDown: return "power.circle.fill"
        case .emptyTrash: return "trash.fill"
        case .toggleDarkMode: return "circle.righthalf.filled"
        case .toggleMute: return "speaker.slash.fill"
        case .toggleWifi: return "wifi"
        case .bluetoothSettings: return "antenna.radiowaves.left.and.right"
        }
    }

    var accentColor: Color {
        switch self {
        case .lockScreen: return .indigo
        case .sleep: return .purple
        case .restart: return .orange
        case .shutDown: return .red
        case .emptyTrash: return .gray
        case .toggleDarkMode: return .yellow
        case .toggleMute: return .cyan
        case .toggleWifi: return .blue
        case .bluetoothSettings: return .blue
        }
    }

    var isDestructive: Bool {
        switch self {
        case .restart, .shutDown: return true
        default: return false
        }
    }

    var keywords: [String] {
        switch self {
        case .lockScreen: return ["lock", "lockscreen", "screen", "display", "sleep display"]
        case .sleep: return ["sleep", "suspend", "hibernate"]
        case .restart: return ["restart", "reboot"]
        case .shutDown: return ["shutdown", "shut down", "power", "power off", "turn off"]
        case .emptyTrash: return ["trash", "empty", "bin", "recycle"]
        case .toggleDarkMode: return ["dark", "light", "appearance", "dark mode", "light mode", "theme"]
        case .toggleMute: return ["mute", "unmute", "volume", "sound", "audio", "speaker"]
        case .toggleWifi: return ["wifi", "wi-fi", "wireless", "airport", "network", "internet"]
        case .bluetoothSettings: return ["bluetooth", "bt", "devices", "pair"]
        }
    }

    var fixedId: UUID {
        switch self {
        case .lockScreen: return UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        case .sleep: return UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        case .restart: return UUID(uuidString: "10000000-0000-0000-0000-000000000003")!
        case .shutDown: return UUID(uuidString: "10000000-0000-0000-0000-000000000004")!
        case .emptyTrash: return UUID(uuidString: "10000000-0000-0000-0000-000000000005")!
        case .toggleDarkMode: return UUID(uuidString: "10000000-0000-0000-0000-000000000006")!
        case .toggleMute: return UUID(uuidString: "10000000-0000-0000-0000-000000000007")!
        case .toggleWifi: return UUID(uuidString: "10000000-0000-0000-0000-000000000008")!
        case .bluetoothSettings: return UUID(uuidString: "10000000-0000-0000-0000-000000000009")!
        }
    }

    func toDiscoveredApp() -> DiscoveredApp {
        let size = NSSize(width: 128, height: 128)
        let symbol = self.iconSymbolName
        let img = NSImage(size: size, flipped: false) { rect in
            let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .bold)
            if let sfImage = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                let tinted = sfImage.copy() as! NSImage
                let drawRect = NSRect(x: 16, y: 16, width: 96, height: 96)
                tinted.draw(in: drawRect)
                return true
            }
            return false
        }

        return DiscoveredApp(
            id: self.fixedId,
            name: self.title,
            url: URL(string: "systemaction://\(self.rawValue)")!,
            bundleIdentifier: "com.apple.systemaction.\(self.rawValue)",
            icon: img,
            category: "SYSTEM",
            tagBadge: "ACTION",
            sizeString: "⚡️",
            accentColor: self.accentColor,
            isHiddenApp: false,
            isSeparator: false,
            channelType: nil,
            customChannelId: nil,
            systemAction: self
        )
    }
}

// MARK: - System Action Service
@MainActor
final class SystemActionService: ObservableObject {
    static let shared = SystemActionService()

    private(set) var allActionApps: [DiscoveredApp] = []

    private init() {
        self.allActionApps = SystemActionType.allCases.map { $0.toDiscoveredApp() }
    }

    func execute(_ action: SystemActionType, bypassConfirmation: Bool = false) {
        SoundEffectsManager.shared.playAction()

        switch action {
        case .lockScreen:
            lockScreen()

        case .sleep:
            sleepSystem()

        case .restart:
            restartSystem(bypassConfirmation: bypassConfirmation)

        case .shutDown:
            shutDownSystem(bypassConfirmation: bypassConfirmation)

        case .emptyTrash:
            emptyTrash()

        case .toggleDarkMode:
            toggleDarkMode()

        case .toggleMute:
            toggleMute()

        case .toggleWifi:
            toggleWifi()

        case .bluetoothSettings:
            openBluetoothSettings()
        }
    }

    // MARK: - Action Implementations

    func lockScreen() {
        if let libHandle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY) {
            if let sym = dlsym(libHandle, "SACLockScreenImmediate") {
                let funcType = unsafeBitCast(sym, to: (@convention(c) () -> Void).self)
                funcType()
                dlclose(libHandle)
                return
            }
            dlclose(libHandle)
        }

        // Secondary fallback via CGSession
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession")
        process.arguments = ["-suspend"]
        try? process.run()
    }

    func sleepSystem() {
        // Method 1: Direct IOKit power management (Native C API, no automation permissions required)
        let port = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
        if port != 0 {
            let status = IOPMSleepSystem(port)
            IOServiceClose(port)
            if status == kIOReturnSuccess {
                return
            }
        }

        // Method 2: System binary fallback via pmset
        let pmProcess = Process()
        pmProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        pmProcess.arguments = ["sleepnow"]
        if (try? pmProcess.run()) != nil {
            return
        }

        // Method 3: AppleScript fallback to Finder
        let script = "tell application \"Finder\" to sleep"
        executeAppleScript(script)
    }

    func restartSystem(bypassConfirmation: Bool = false) {
        let confirm = UserDefaults.standard.object(forKey: "confirmDestructiveActions") as? Bool ?? true
        if confirm && !bypassConfirmation {
            let alert = NSAlert()
            alert.messageText = "Restart Mac?"
            alert.informativeText = "Are you sure you want to restart your computer now?"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Restart")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() != .alertFirstButtonReturn {
                return
            }
        }
        let script = "tell application \"Finder\" to restart"
        executeAppleScript(script)
    }

    func shutDownSystem(bypassConfirmation: Bool = false) {
        let confirm = UserDefaults.standard.object(forKey: "confirmDestructiveActions") as? Bool ?? true
        if confirm && !bypassConfirmation {
            let alert = NSAlert()
            alert.messageText = "Shut Down Mac?"
            alert.informativeText = "Are you sure you want to shut down your computer now?"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Shut Down")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() != .alertFirstButtonReturn {
                return
            }
        }
        let script = "tell application \"Finder\" to shut down"
        executeAppleScript(script)
    }

    func emptyTrash() {
        let script = """
        tell application "Finder"
            try
                set warns before emptying of trash to false
                empty trash
                set warns before emptying of trash to true
            on error
                empty trash
            end try
        end tell
        """
        executeAppleScript(script)
    }

    func toggleDarkMode() {
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to not dark mode
            end tell
        end tell
        """
        executeAppleScript(script)
    }

    func toggleMute() {
        let script = """
        set curMute to output muted of (get volume settings)
        set volume output muted (not curMute)
        """
        executeAppleScript(script)
    }

    func toggleWifi() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Find Wi-Fi hardware device port (defaults to en0)
            let device = Self.detectWifiDevice()
            let getProcess = Process()
            getProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            getProcess.arguments = ["-getairportpower", device]
            let pipe = Pipe()
            getProcess.standardOutput = pipe
            try? getProcess.run()
            getProcess.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let newState = output.localizedCaseInsensitiveContains("off") ? "on" : "off"

            let setProcess = Process()
            setProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
            setProcess.arguments = ["-setairportpower", device, newState]
            try? setProcess.run()
        }
    }

    func openBluetoothSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func detectWifiDevice() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        process.arguments = ["-listallhardwareports"]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        let lines = output.components(separatedBy: .newlines)
        var isWifi = false
        for line in lines {
            if line.contains("Hardware Port: Wi-Fi") {
                isWifi = true
            } else if isWifi && line.hasPrefix("Device: ") {
                let device = line.replacingOccurrences(of: "Device: ", with: "").trimmingCharacters(in: .whitespaces)
                if !device.isEmpty {
                    return device
                }
            } else if line.hasPrefix("Hardware Port:") {
                isWifi = false
            }
        }
        return "en0"
    }

    private func executeAppleScript(_ scriptSource: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: scriptSource) {
                appleScript.executeAndReturnError(&error)
                if error == nil {
                    return
                }
            }

            // Fallback via /usr/bin/osascript CLI process
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", scriptSource]
            try? process.run()
        }
    }
}
