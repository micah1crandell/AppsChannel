import Foundation

enum LauncherMode: String, CaseIterable, Identifiable {
    case quickLauncher
    case fullScreen

    var id: String { rawValue }
}

enum MainLayoutViewMode: String, CaseIterable, Identifiable {
    case coverFlow = "CoverFlow"
    case gridWall = "Wall Grid"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .coverFlow: return "rectangle.portrait.on.rectangle.portrait.fill"
        case .gridWall: return "square.grid.3x3.fill"
        }
    }
}
