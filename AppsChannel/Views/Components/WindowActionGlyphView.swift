import SwiftUI

struct WindowActionGlyphView: View {
    let action: WindowSnappingAction
    var size: CGFloat = 22

    init(action: WindowSnappingAction, size: CGFloat = 22) {
        self.action = action
        self.size = size
    }

    var body: some View {
        ZStack {
            // Blue Container
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color(red: 0.05, green: 0.52, blue: 1.0))
                .frame(width: size, height: size)

            // Inner Shape / Glyph
            innerContent
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var innerContent: some View {
        let pad = size * 0.16
        let innerW = size - (pad * 2)
        let innerH = size - (pad * 2)
        let r: CGFloat = 1.5

        switch action {
        // MARK: - Halves
        case .leftHalf:
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.5, height: innerH)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .rightHalf:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.5, height: innerH)
            }
            .padding(pad)

        case .topHalf:
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW, height: innerH * 0.5)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .bottomHalf:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW, height: innerH * 0.5)
            }
            .padding(pad)

        case .centerHalf:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.5, height: innerH)
                Spacer(minLength: 0)
            }
            .padding(pad)

        // MARK: - Thirds & Two-Thirds
        case .firstThird:
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.33, height: innerH)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .centerThird:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.33, height: innerH)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .lastThird:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.33, height: innerH)
            }
            .padding(pad)

        case .firstTwoThirds:
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.67, height: innerH)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .centerTwoThirds:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.67, height: innerH)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .lastTwoThirds:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.67, height: innerH)
            }
            .padding(pad)

        case .topThird:
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW, height: innerH * 0.33)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .bottomThird:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW, height: innerH * 0.33)
            }
            .padding(pad)

        case .topTwoThirds:
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW, height: innerH * 0.67)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .bottomTwoThirds:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW, height: innerH * 0.67)
            }
            .padding(pad)

        // MARK: - Fourths & Three-Fourths
        case .firstFourth:
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.25, height: innerH)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .secondFourth:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                    .frame(width: innerW * 0.25)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.25, height: innerH)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .thirdFourth:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.25, height: innerH)
                Spacer(minLength: 0)
                    .frame(width: innerW * 0.25)
            }
            .padding(pad)

        case .lastFourth:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.25, height: innerH)
            }
            .padding(pad)

        case .firstThreeFourths:
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.75, height: innerH)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .centerThreeFourths:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.75, height: innerH)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .lastThreeFourths:
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW * 0.75, height: innerH)
            }
            .padding(pad)

        case .topFirstFourth:
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW, height: innerH * 0.25)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .topThreeFourths:
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW, height: innerH * 0.75)
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .bottomThreeFourths:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: r)
                    .fill(Color.white)
                    .frame(width: innerW, height: innerH * 0.75)
            }
            .padding(pad)

        // MARK: - Quarters (Corners)
        case .topLeftQuarter:
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.white)
                        .frame(width: innerW * 0.5, height: innerH * 0.5)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .topRightQuarter:
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.white)
                        .frame(width: innerW * 0.5, height: innerH * 0.5)
                }
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .bottomLeftQuarter:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.white)
                        .frame(width: innerW * 0.5, height: innerH * 0.5)
                    Spacer(minLength: 0)
                }
            }
            .padding(pad)

        case .bottomRightQuarter:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.white)
                        .frame(width: innerW * 0.5, height: innerH * 0.5)
                }
            }
            .padding(pad)

        // MARK: - Sixths
        case .topLeftSixth:
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.white)
                        .frame(width: innerW * 0.33, height: innerH * 0.5)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .topCenterSixth:
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.white)
                        .frame(width: innerW * 0.33, height: innerH * 0.5)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .topRightSixth:
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.white)
                        .frame(width: innerW * 0.33, height: innerH * 0.5)
                }
                Spacer(minLength: 0)
            }
            .padding(pad)

        case .bottomLeftSixth:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.white)
                        .frame(width: innerW * 0.33, height: innerH * 0.5)
                    Spacer(minLength: 0)
                }
            }
            .padding(pad)

        case .bottomCenterSixth:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.white)
                        .frame(width: innerW * 0.33, height: innerH * 0.5)
                    Spacer(minLength: 0)
                }
            }
            .padding(pad)

        case .bottomRightSixth:
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: r)
                        .fill(Color.white)
                        .frame(width: innerW * 0.33, height: innerH * 0.5)
                }
            }
            .padding(pad)

        // MARK: - Maximize & Centering
        case .maximize:
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(.white)

        case .almostMaximize:
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(.white)

        case .maximizeHeight:
            Image(systemName: "arrow.up.and.down")
                .font(.system(size: size * 0.50, weight: .bold))
                .foregroundStyle(.white)

        case .maximizeWidth:
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: size * 0.50, weight: .bold))
                .foregroundStyle(.white)

        case .center:
            RoundedRectangle(cornerRadius: r)
                .fill(Color.white)
                .frame(width: innerW * 0.48, height: innerH * 0.48)

        case .reasonableSize:
            RoundedRectangle(cornerRadius: r)
                .fill(Color.white)
                .frame(width: innerW * 0.72, height: innerH * 0.72)

        // MARK: - Resize & Nudge
        case .makeLarger:
            Image(systemName: "plus")
                .font(.system(size: size * 0.52, weight: .bold))
                .foregroundStyle(.white)

        case .makeSmaller:
            Image(systemName: "minus")
                .font(.system(size: size * 0.52, weight: .bold))
                .foregroundStyle(.white)

        case .moveLeft:
            Image(systemName: "arrow.left")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(.white)

        case .moveRight:
            Image(systemName: "arrow.right")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(.white)

        case .moveTop:
            Image(systemName: "arrow.up")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(.white)

        case .moveBottom:
            Image(systemName: "arrow.down")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(.white)

        // MARK: - Displays
        case .moveToNextDisplay:
            HStack(spacing: 1) {
                Image(systemName: "display")
                    .font(.system(size: size * 0.36, weight: .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: size * 0.28, weight: .bold))
            }
            .foregroundStyle(.white)

        case .moveToPreviousDisplay:
            HStack(spacing: 1) {
                Image(systemName: "arrow.left")
                    .font(.system(size: size * 0.28, weight: .bold))
                Image(systemName: "display")
                    .font(.system(size: size * 0.36, weight: .bold))
            }
            .foregroundStyle(.white)

        // MARK: - State
        case .restore:
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(.white)

        case .minimize:
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(.white)

        case .toggleFullscreen:
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: size * 0.48, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
