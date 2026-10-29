import Foundation

enum LauncherMode: String, CaseIterable, Identifiable {
    case classicLauncher = "classicLauncher"
    case quickLauncher = "quickLauncher"
    case fullScreen = "fullScreen"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classicLauncher: return "Classic Launcher"
        case .quickLauncher: return "Quick HUD"
        case .fullScreen: return "Channel Window"
        }
    }

    var subtitle: String {
        switch self {
        case .classicLauncher: return "Raycast-style vertical command list with smart sections & actions"
        case .quickLauncher: return "Spotlight-style floating 3D Cover Flow & Wall Grid HUD"
        case .fullScreen: return "Full macOS console window with interactive channels"
        }
    }

    var iconName: String {
        switch self {
        case .classicLauncher: return "list.bullet.rectangle.portrait"
        case .quickLauncher: return "rectangle.inset.filled.and.cursorarrow"
        case .fullScreen: return "macwindow"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "classicLauncher", "classic", "raycast", "list":
            self = .classicLauncher
        case "quickLauncher", "quick", "hud":
            self = .quickLauncher
        case "fullScreen", "fullscreen", "main", "mainApp":
            self = .fullScreen
        default:
            return nil
        }
    }
}

enum MainLayoutViewMode: String, CaseIterable, Identifiable {
    case coverFlow = "CoverFlow"
    case gridWall = "Wall Grid"
    case flatGrid = "Flat Grid"
    case wiiChannels = "Wii Channels"

    // Backward compatibility aliases
    static let threeDSGrid = MainLayoutViewMode.flatGrid
    static let consoleGrid = MainLayoutViewMode.wiiChannels

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coverFlow: return "Cover Flow"
        case .gridWall: return "Curved Wall Grid"
        case .flatGrid: return "Flat Grid"
        case .wiiChannels: return "Wii Channels"
        }
    }

    var iconName: String {
        switch self {
        case .coverFlow: return "rectangle.portrait.on.rectangle.portrait.fill"
        case .gridWall: return "square.grid.3x3.fill"
        case .flatGrid: return "square.grid.3x2.fill"
        case .wiiChannels: return "tv.fill"
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "CoverFlow", "Cards Flow", "coverFlow", "IconFlow", "iconFlow":
            self = .coverFlow
        case "Wall Grid", "gridWall", "wallGrid":
            self = .gridWall
        case "Flat Grid", "flatGrid", "3DS Grid", "threeDSGrid", "3ds", "threeDS", "3DS Flat Grid":
            self = .flatGrid
        case "Wii Channels", "wiiChannels", "wiiGrid", "consoleGrid", "pagedConsoleGrid":
            self = .wiiChannels
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
        case .channelCard: return "Classic macOS Channel cards with categories and tags"
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
