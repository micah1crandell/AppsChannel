import Foundation
import SwiftUI
import Combine
#if !APP_STORE
import Sparkle
#endif

@MainActor
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    #if !APP_STORE
    private let updaterController: SPUStandardUpdaterController
    #endif

    @Published var canCheckForUpdates: Bool = false

    private override init() {
        #if !APP_STORE
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        #else
        super.init()
        #endif
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            #if !APP_STORE
            return updaterController.updater.automaticallyChecksForUpdates
            #else
            return false
            #endif
        }
        set {
            #if !APP_STORE
            updaterController.updater.automaticallyChecksForUpdates = newValue
            #endif
        }
    }

    func checkForUpdates() {
        #if !APP_STORE
        updaterController.checkForUpdates(nil)
        #endif
    }
}
