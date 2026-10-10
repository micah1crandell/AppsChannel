import Foundation
import ServiceManagement
import Combine

@MainActor
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published var isEnabled: Bool = false

    private init() {
        refreshStatus()
    }

    func refreshStatus() {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            self.isEnabled = (status == .enabled)
        } else {
            self.isEnabled = UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "launchAtLogin")

        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("[AppsChannel] SMAppService error: \(error.localizedDescription)")
                // Re-sync state with actual system status
                refreshStatus()
            }
        }
    }
}
