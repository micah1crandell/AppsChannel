import Foundation
import AppKit
import HotKey

// MARK: - Window Snapping Category
enum WindowActionCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case halves = "Halves"
    case thirds = "Thirds"
    case fourths = "Fourths"
    case quarters = "Corners"
    case sixths = "Sixths"
    case maximize = "Maximize & Center"
    case resizeAndMove = "Resize & Nudge"
    case displays = "Displays & Spaces"
    case system = "Window State"

    var id: String { rawValue }
}

// MARK: - Window Snapping Action
enum WindowSnappingAction: String, CaseIterable, Identifiable, Codable, Sendable {
    // Halves
    case leftHalf = "left_half"
    case rightHalf = "right_half"
    case topHalf = "top_half"
    case bottomHalf = "bottom_half"
    case centerHalf = "center_half"

    // Thirds & Two-Thirds
    case firstThird = "first_third"
    case centerThird = "center_third"
    case lastThird = "last_third"
    case firstTwoThirds = "first_two_thirds"
    case centerTwoThirds = "center_two_thirds"
    case lastTwoThirds = "last_two_thirds"
    case topThird = "top_third"
    case bottomThird = "bottom_third"
    case topTwoThirds = "top_two_thirds"
    case bottomTwoThirds = "bottom_two_thirds"

    // Fourths & Three-Fourths
    case firstFourth = "first_fourth"
    case secondFourth = "second_fourth"
    case thirdFourth = "third_fourth"
    case lastFourth = "last_fourth"
    case firstThreeFourths = "first_three_fourths"
    case centerThreeFourths = "center_three_fourths"
    case lastThreeFourths = "last_three_fourths"
    case topFirstFourth = "top_first_fourth"
    case topThreeFourths = "top_three_fourths"
    case bottomThreeFourths = "bottom_three_fourths"

    // Quarters (Corners)
    case topLeftQuarter = "top_left_quarter"
    case topRightQuarter = "top_right_quarter"
    case bottomLeftQuarter = "bottom_left_quarter"
    case bottomRightQuarter = "bottom_right_quarter"

    // Sixths
    case topLeftSixth = "top_left_sixth"
    case topCenterSixth = "top_center_sixth"
    case topRightSixth = "top_right_sixth"
    case bottomLeftSixth = "bottom_left_sixth"
    case bottomCenterSixth = "bottom_center_sixth"
    case bottomRightSixth = "bottom_right_sixth"

    // Maximize & Centering
    case maximize = "maximize"
    case almostMaximize = "almost_maximize"
    case maximizeHeight = "maximize_height"
    case maximizeWidth = "maximize_width"
    case center = "center"
    case reasonableSize = "reasonable_size"

    // Sizing & Nudging
    case makeLarger = "make_larger"
    case makeSmaller = "make_smaller"
    case moveLeft = "move_left"
    case moveRight = "move_right"
    case moveTop = "move_top"
    case moveBottom = "move_bottom"

    // Displays & Spaces
    case moveToNextDisplay = "move_to_next_display"
    case moveToPreviousDisplay = "move_to_previous_display"

    // Window State
    case restore = "restore"
    case minimize = "minimize"
    case toggleFullscreen = "toggle_fullscreen"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .centerHalf: return "Center Half"

        case .firstThird: return "First Third"
        case .centerThird: return "Center Third"
        case .lastThird: return "Last Third"
        case .firstTwoThirds: return "First Two Thirds"
        case .centerTwoThirds: return "Center Two Thirds"
        case .lastTwoThirds: return "Last Two Thirds"
        case .topThird: return "Top Third"
        case .bottomThird: return "Bottom Third"
        case .topTwoThirds: return "Top Two Thirds"
        case .bottomTwoThirds: return "Bottom Two Thirds"

        case .firstFourth: return "First Fourth"
        case .secondFourth: return "Second Fourth"
        case .thirdFourth: return "Third Fourth"
        case .lastFourth: return "Last Fourth"
        case .firstThreeFourths: return "First Three Fourths"
        case .centerThreeFourths: return "Center Three Fourths"
        case .lastThreeFourths: return "Last Three Fourths"
        case .topFirstFourth: return "Top First Fourth"
        case .topThreeFourths: return "Top Three Fourths"
        case .bottomThreeFourths: return "Bottom Three Fourths"

        case .topLeftQuarter: return "Top Left Quarter"
        case .topRightQuarter: return "Top Right Quarter"
        case .bottomLeftQuarter: return "Bottom Left Quarter"
        case .bottomRightQuarter: return "Bottom Right Quarter"

        case .topLeftSixth: return "Top Left Sixth"
        case .topCenterSixth: return "Top Center Sixth"
        case .topRightSixth: return "Top Right Sixth"
        case .bottomLeftSixth: return "Bottom Left Sixth"
        case .bottomCenterSixth: return "Bottom Center Sixth"
        case .bottomRightSixth: return "Bottom Right Sixth"

        case .maximize: return "Maximize"
        case .almostMaximize: return "Almost Maximize"
        case .maximizeHeight: return "Maximize Height"
        case .maximizeWidth: return "Maximize Width"
        case .center: return "Center"
        case .reasonableSize: return "Reasonable Size"

        case .makeLarger: return "Make Larger"
        case .makeSmaller: return "Make Smaller"
        case .moveLeft: return "Move Left"
        case .moveRight: return "Move Right"
        case .moveTop: return "Move Top"
        case .moveBottom: return "Move Bottom"

        case .moveToNextDisplay: return "Move to Next Display"
        case .moveToPreviousDisplay: return "Move to Previous Display"

        case .restore: return "Restore"
        case .minimize: return "Minimize"
        case .toggleFullscreen: return "Toggle Fullscreen"
        }
    }

    var category: WindowActionCategory {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf, .centerHalf:
            return .halves
        case .firstThird, .centerThird, .lastThird, .firstTwoThirds, .centerTwoThirds,
             .lastTwoThirds, .topThird, .bottomThird, .topTwoThirds, .bottomTwoThirds:
            return .thirds
        case .firstFourth, .secondFourth, .thirdFourth, .lastFourth, .firstThreeFourths,
             .centerThreeFourths, .lastThreeFourths, .topFirstFourth, .topThreeFourths, .bottomThreeFourths:
            return .fourths
        case .topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter:
            return .quarters
        case .topLeftSixth, .topCenterSixth, .topRightSixth, .bottomLeftSixth,
             .bottomCenterSixth, .bottomRightSixth:
            return .sixths
        case .maximize, .almostMaximize, .maximizeHeight, .maximizeWidth, .center, .reasonableSize:
            return .maximize
        case .makeLarger, .makeSmaller, .moveLeft, .moveRight, .moveTop, .moveBottom:
            return .resizeAndMove
        case .moveToNextDisplay, .moveToPreviousDisplay:
            return .displays
        case .restore, .minimize, .toggleFullscreen:
            return .system
        }
    }

    var keywords: [String] {
        var words = [title.lowercased(), "window", "snap", "tile"]
        switch self {
        case .leftHalf: words.append(contentsOf: ["left", "lh", "split left", "west"])
        case .rightHalf: words.append(contentsOf: ["right", "rh", "split right", "east"])
        case .topHalf: words.append(contentsOf: ["top", "up", "north"])
        case .bottomHalf: words.append(contentsOf: ["bottom", "down", "south"])
        case .center, .centerHalf: words.append(contentsOf: ["middle", "center"])
        case .maximize: words.append(contentsOf: ["full", "fullscreen", "max", "fill"])
        case .almostMaximize: words.append(contentsOf: ["margin", "padding", "near full"])
        case .restore: words.append(contentsOf: ["undo", "revert", "previous"])
        case .makeLarger: words.append(contentsOf: ["grow", "enlarge", "expand", "bigger"])
        case .makeSmaller: words.append(contentsOf: ["shrink", "reduce", "smaller"])
        case .moveToNextDisplay: words.append(contentsOf: ["monitor", "screen", "next screen"])
        case .moveToPreviousDisplay: words.append(contentsOf: ["monitor", "screen", "prev screen"])
        default: break
        }
        return words
    }

    /// Default hotkey combo out of the box (e.g. ⌥[ for Left Half, ⌥] for Right Half, ⌥= for Maximize, ⌥\ for Center)
    var defaultKeyCombo: (keyCode: UInt32, modifiers: NSEvent.ModifierFlags, label: String)? {
        switch self {
        case .leftHalf:
            // ⌥ [ (carbon key code 33 is '[')
            return (33, [.option], "⌥ [")
        case .rightHalf:
            // ⌥ ] (carbon key code 30 is ']')
            return (30, [.option], "⌥ ]")
        case .maximize:
            // ⌥ = (carbon key code 24 is '=')
            return (24, [.option], "⌥ =")
        case .center:
            // ⌥ \ (carbon key code 42 is '\')
            return (42, [.option], "⌥ \\")
        case .topHalf:
            // ⌥ ↑ (carbon key code 126 is Up Arrow)
            return (126, [.option], "⌥ ↑")
        case .bottomHalf:
            // ⌥ ↓ (carbon key code 125 is Down Arrow)
            return (125, [.option], "⌥ ↓")
        case .restore:
            // ⌥ ⌫ (carbon key code 51 is Backspace/Delete)
            return (51, [.option], "⌥ ⌫")
        case .makeLarger:
            // ⌥ ⇧ + (carbon key code 24 is '=')
            return (24, [.option, .shift], "⌥ ⇧ +")
        case .makeSmaller:
            // ⌥ ⇧ - (carbon key code 27 is '-')
            return (27, [.option, .shift], "⌥ ⇧ -")
        case .moveToNextDisplay:
            // ⌃ ⌥ → (carbon key code 124 is Right Arrow)
            return (124, [.control, .option], "⌃ ⌥ →")
        case .moveToPreviousDisplay:
            // ⌃ ⌥ ← (carbon key code 123 is Left Arrow)
            return (123, [.control, .option], "⌃ ⌥ ←")
        default:
            return nil
        }
    }
}
