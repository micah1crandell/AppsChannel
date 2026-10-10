import SwiftUI

// MARK: - Accessibility Motion Helper
extension Animation {
    /// Returns either a snappy spring animation or a subtle easeInOut animation depending on the user's Reduce Motion setting.
    static func responsive(
        reduceMotion: Bool,
        spring: Animation = .spring(response: 0.32, dampingFraction: 0.82)
    ) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : spring
    }
}
