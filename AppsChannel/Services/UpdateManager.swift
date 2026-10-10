import Foundation
import SwiftUI
import Combine
import Sparkle

@MainActor
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()

    private let updaterController: SPUStandardUpdaterController

    @Published var canCheckForUpdates: Bool = false

    private override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
