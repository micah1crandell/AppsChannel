import AppKit
import AudioToolbox

final class SoundEffectsManager {
    static let shared = SoundEffectsManager()

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEffects") as? Bool ?? true
    }

    private var navigationSound: NSSound?
    private var launchSound: NSSound?
    private var actionSound: NSSound?

    private init() {
        // macOS built-in system sounds in /System/Library/Sounds
        navigationSound = NSSound(named: "Tink")
        launchSound = NSSound(named: "Pop")
        actionSound = NSSound(named: "Glass")
    }

    func playNavigation() {
        guard isEnabled else { return }
        navigationSound?.stop()
        navigationSound?.play()
    }

    func playLaunch() {
        guard isEnabled else { return }
        launchSound?.stop()
        launchSound?.play()
    }

    func playAction() {
        guard isEnabled else { return }
        actionSound?.stop()
        actionSound?.play()
    }
}
