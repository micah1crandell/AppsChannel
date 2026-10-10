import AppKit
import AudioToolbox

enum SoundTheme: String, CaseIterable, Identifiable {
    case subtle = "Subtle Classic"
    case playful = "Playful Pop"
    case mechanical = "Mechanical Click"

    var id: String { rawValue }

    var navigationSoundName: String {
        switch self {
        case .subtle: return "Tink"
        case .playful: return "Bottle"
        case .mechanical: return "Hero"
        }
    }

    var launchSoundName: String {
        switch self {
        case .subtle: return "Pop"
        case .playful: return "Morse"
        case .mechanical: return "Ping"
        }
    }

    var actionSoundName: String {
        switch self {
        case .subtle: return "Glass"
        case .playful: return "Blow"
        case .mechanical: return "Submarine"
        }
    }
}

@MainActor
final class SoundEffectsManager {
    static let shared = SoundEffectsManager()

    private var soundCache: [String: NSSound] = [:]

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundEffects") as? Bool ?? true
    }

    var isHapticEnabled: Bool {
        UserDefaults.standard.object(forKey: "hapticFeedback") as? Bool ?? true
    }

    var currentTheme: SoundTheme {
        if let raw = UserDefaults.standard.string(forKey: "soundTheme"),
           let theme = SoundTheme(rawValue: raw) {
            return theme
        }
        return .subtle
    }

    private init() {}

    private func sound(named name: String) -> NSSound? {
        if let cached = soundCache[name] {
            return cached
        }
        if let snd = NSSound(named: NSSound.Name(name)) {
            soundCache[name] = snd
            return snd
        }
        return nil
    }

    func playNavigation() {
        if isHapticEnabled {
            performHaptic()
        }
        guard isEnabled else { return }
        let snd = sound(named: currentTheme.navigationSoundName)
        snd?.stop()
        snd?.play()
    }

    func playPreview(for theme: SoundTheme) {
        if isHapticEnabled {
            performHaptic()
        }
        guard isEnabled else { return }
        let snd = sound(named: theme.navigationSoundName)
        snd?.stop()
        snd?.play()
    }

    func playLaunch() {
        if isHapticEnabled {
            performHaptic(pattern: .generic)
        }
        guard isEnabled else { return }
        let snd = sound(named: currentTheme.launchSoundName)
        snd?.stop()
        snd?.play()
    }

    func playAction() {
        if isHapticEnabled {
            performHaptic()
        }
        guard isEnabled else { return }
        let snd = sound(named: currentTheme.actionSoundName)
        snd?.stop()
        snd?.play()
    }

    func performHaptic(pattern: NSHapticFeedbackManager.FeedbackPattern = .alignment) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
