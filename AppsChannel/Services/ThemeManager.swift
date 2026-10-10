import SwiftUI
import Combine

enum AppVisualTheme: String, CaseIterable, Identifiable {
    case liquidGlass = "Liquid Glass"
    case matteWhite = "Matte White"
    case indigoPurple = "Indigo Purple"
    case cyberpunkDark = "Cyberpunk Dark"

    // Backward compatibility aliases
    static let wiiMatteWhite = AppVisualTheme.matteWhite
    static let gameCubeIndigo = AppVisualTheme.indigoPurple

    var id: String { rawValue }

    var description: String {
        switch self {
        case .liquidGlass:
            return "Modern translucent frosted glass with dynamic monochrome reflections."
        case .matteWhite:
            return "Glossy minimalist channel aesthetic with clean cyan borders."
        case .indigoPurple:
            return "Deep indigo purple shell with vibrant accent lighting."
        case .cyberpunkDark:
            return "High-contrast slate black with vivid neon cyan and magenta edge glow."
        }
    }

    init?(rawValue: String) {
        switch rawValue {
        case "Liquid Glass", "liquidGlass":
            self = .liquidGlass
        case "Matte White", "matteWhite", "Wii Matte White", "wiiMatteWhite":
            self = .matteWhite
        case "Indigo Purple", "indigoPurple", "GameCube Indigo", "gameCubeIndigo":
            self = .indigoPurple
        case "Cyberpunk Dark", "cyberpunkDark":
            self = .cyberpunkDark
        default:
            return nil
        }
    }

    static func from(string: String) -> AppVisualTheme? {
        let cleaned = string.lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        for theme in AppVisualTheme.allCases {
            if theme.rawValue.lowercased() == cleaned { return theme }
        }
        if cleaned.contains("liquid") || cleaned.contains("glass") { return .liquidGlass }
        if cleaned.contains("white") || cleaned.contains("matte") || cleaned.contains("wii") { return .matteWhite }
        if cleaned.contains("indigo") || cleaned.contains("purple") || cleaned.contains("gamecube") { return .indigoPurple }
        if cleaned.contains("cyberpunk") || cleaned.contains("neon") { return .cyberpunkDark }
        return nil
    }

    // Card background fill gradient
    var cardBackgroundGradient: LinearGradient {
        switch self {
        case .liquidGlass:
            return LinearGradient(
                colors: [Color(white: 0.10).opacity(0.96), Color(white: 0.04).opacity(0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .matteWhite:
            return LinearGradient(
                colors: [Color(white: 0.98), Color(white: 0.90)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .indigoPurple:
            return LinearGradient(
                colors: [Color(red: 0.20, green: 0.16, blue: 0.38), Color(red: 0.12, green: 0.10, blue: 0.26)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cyberpunkDark:
            return LinearGradient(
                colors: [Color(red: 0.05, green: 0.06, blue: 0.09), Color(red: 0.01, green: 0.02, blue: 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // Card border stroke gradient
    func cardBorderGradient(isSelected: Bool) -> LinearGradient {
        switch self {
        case .liquidGlass:
            if isSelected {
                return LinearGradient(
                    colors: [Color.white, Color.white.opacity(0.65), Color.white.opacity(0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [Color.white.opacity(0.28), Color.white.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .matteWhite:
            if isSelected {
                return LinearGradient(
                    colors: [Color(red: 0.15, green: 0.70, blue: 0.95), Color(red: 0.0, green: 0.85, blue: 0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [Color(white: 0.75), Color(white: 0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .indigoPurple:
            if isSelected {
                return LinearGradient(
                    colors: [Color(red: 1.0, green: 0.55, blue: 0.0), Color(red: 1.0, green: 0.80, blue: 0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [Color(red: 0.38, green: 0.32, blue: 0.60), Color(red: 0.25, green: 0.20, blue: 0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .cyberpunkDark:
            if isSelected {
                return LinearGradient(
                    colors: [Color(red: 0.0, green: 0.95, blue: 1.0), Color(red: 1.0, green: 0.0, blue: 0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [Color(red: 0.0, green: 0.6, blue: 0.8).opacity(0.5), Color(red: 0.6, green: 0.0, blue: 0.4).opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    // Inner Canvas Background Fill
    var canvasBackgroundGradient: LinearGradient {
        switch self {
        case .liquidGlass:
            return LinearGradient(
                colors: [Color.black.opacity(0.65), Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .matteWhite:
            return LinearGradient(
                colors: [Color(white: 0.88), Color(white: 0.80)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .indigoPurple:
            return LinearGradient(
                colors: [Color(red: 0.12, green: 0.09, blue: 0.22), Color(red: 0.07, green: 0.05, blue: 0.14)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .cyberpunkDark:
            return LinearGradient(
                colors: [Color(red: 0.02, green: 0.03, blue: 0.05), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // Inner Canvas Border
    var canvasBorderGradient: LinearGradient {
        switch self {
        case .liquidGlass:
            return LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .matteWhite:
            return LinearGradient(colors: [Color(white: 0.70), Color(white: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .indigoPurple:
            return LinearGradient(colors: [Color(red: 0.45, green: 0.38, blue: 0.75), Color(red: 0.2, green: 0.15, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .cyberpunkDark:
            return LinearGradient(colors: [Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.4), Color(red: 1.0, green: 0.0, blue: 0.55).opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // Text & Header Colors
    var headerTextColor: Color {
        switch self {
        case .matteWhite: return Color(white: 0.25)
        default: return Color.white.opacity(0.9)
        }
    }

    var titleTextColor: Color {
        switch self {
        case .matteWhite: return Color(white: 0.12)
        default: return .white
        }
    }

    var footerTextColor: Color {
        switch self {
        case .matteWhite: return Color(white: 0.35)
        default: return Color.white.opacity(0.7)
        }
    }

    var selectionGlowColor: Color {
        switch self {
        case .liquidGlass: return Color.white.opacity(0.28)
        case .matteWhite: return Color(red: 0.0, green: 0.75, blue: 0.95).opacity(0.45)
        case .indigoPurple: return Color(red: 1.0, green: 0.60, blue: 0.0).opacity(0.55)
        case .cyberpunkDark: return Color(red: 0.0, green: 0.95, blue: 1.0).opacity(0.5)
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("visualTheme") var themeRaw: String = AppVisualTheme.liquidGlass.rawValue

    var currentTheme: AppVisualTheme {
        AppVisualTheme(rawValue: themeRaw) ?? .liquidGlass
    }

    func setTheme(_ theme: AppVisualTheme) {
        themeRaw = theme.rawValue
        objectWillChange.send()
    }
}
