import SwiftUI
import AppKit

/// Backwards-compatible forwarder to the polymorphic AppContextSubDeckView
struct RecentDocumentsSubDeckView: View {
    let app: DiscoveredApp
    let onClose: () -> Void

    var body: some View {
        AppContextSubDeckView(app: app, onClose: onClose)
    }
}
