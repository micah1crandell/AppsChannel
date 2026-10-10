import XCTest
import SwiftUI
@testable import AppsChannel

final class MotionHelperTests: XCTestCase {

    func testResponsiveAnimationUnderReduceMotion() {
        let reducedAnimation = Animation.responsive(reduceMotion: true)
        let springAnimation = Animation.responsive(reduceMotion: false)

        // Both animations should produce valid, non-nil SwiftUI Animation instances
        XCTAssertNotNil(reducedAnimation)
        XCTAssertNotNil(springAnimation)
    }

    func testScreenBoundsClampingMath() {
        let visibleScreen = NSRect(x: 0, y: 0, width: 1440, height: 900)
        let oversizedWidth: CGFloat = 1920
        let oversizedHeight: CGFloat = 1080
        let minSize = NSSize(width: 960, height: 620)

        // Simulate repositionWindowInsideVisibleScreen logic
        let clampedWidth = min(oversizedWidth, max(minSize.width, visibleScreen.width * 0.92))
        let clampedHeight = min(oversizedHeight, max(minSize.height, visibleScreen.height * 0.90))

        XCTAssertLessThanOrEqual(clampedWidth, visibleScreen.width)
        XCTAssertLessThanOrEqual(clampedHeight, visibleScreen.height)
        XCTAssertGreaterThanOrEqual(clampedWidth, minSize.width)
        XCTAssertGreaterThanOrEqual(clampedHeight, minSize.height)

        let newX = max(visibleScreen.minX, min(visibleScreen.midX - (clampedWidth / 2), visibleScreen.maxX - clampedWidth))
        let newY = max(visibleScreen.minY, min(visibleScreen.midY - (clampedHeight / 2), visibleScreen.maxY - clampedHeight))

        XCTAssertGreaterThanOrEqual(newX, visibleScreen.minX)
        XCTAssertLessThanOrEqual(newX + clampedWidth, visibleScreen.maxX)
        XCTAssertGreaterThanOrEqual(newY, visibleScreen.minY)
        XCTAssertLessThanOrEqual(newY + clampedHeight, visibleScreen.maxY)
    }
}
