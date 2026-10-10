import Foundation

enum LauncherMode: String, CaseIterable, Identifiable {
    case quickLauncher
    case fullScreen

    var id: String { rawValue }
}

enum MainLayoutViewMode: String, CaseIterable, Identifiable {
    case coverFlow = "CoverFlow"
    case gridWall = "Wall Grid"
    case threeDSGrid = "3DS Grid"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coverFlow: return "Cover Flow"
        case .gridWall: return "Curved Wall Grid"
        case .threeDSGrid: return "3DS Flat Grid"
        }
    }

    var iconName: String {
        switch self {
        case .coverFlow: return "rectangle.portrait.on.rectangle.portrait.fill"
        case .gridWall: return "square.grid.3x3.fill"
        case .threeDSGrid: return "square.grid.3x2.fill"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "CoverFlow", "Cards Flow", "coverFlow", "IconFlow", "iconFlow":
            self = .coverFlow
        case "Wall Grid", "gridWall", "wallGrid":
            self = .gridWall
        case "3DS Grid", "threeDSGrid", "3ds", "threeDS", "3DS Flat Grid":
            self = .threeDSGrid
        default:
            return nil
        }
    }
}

enum AppDisplayStyle: String, CaseIterable, Identifiable {
    case iconOnly = "App Icon Only"
    case channelCard = "Channel Cards"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconOnly: return "App Icon Only"
        case .channelCard: return "Channel Cards"
        }
    }

    var desc: String {
        switch self {
        case .iconOnly: return "Minimalist native app icons with ambient lighting & reflections"
        case .channelCard: return "Classic Nintendo Wii & macOS Channel cards with categories and tags"
        }
    }

    var iconName: String {
        switch self {
        case .iconOnly: return "app.fill"
        case .channelCard: return "rectangle.portrait.on.rectangle.portrait.fill"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "App Icon Only", "iconOnly", "Icon Only", "icons":
            self = .iconOnly
        case "Channel Cards", "channelCard", "cards":
            self = .channelCard
        default:
            return nil
        }
    }
}
