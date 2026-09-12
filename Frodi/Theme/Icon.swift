import SwiftUI

/// The icons in the app, taken from Heroicons.
///
/// Heroicons is drawn by Tailwind Labs and MIT licensed. The files live in the
/// asset catalogue as SVG with vector data preserved, so they are sharp at every
/// size. `template` makes the colour come from `foregroundStyle`, so an icon
/// follows the design system's text colours instead of having its own.
///
/// Why not SF Symbols: they are Apple's, and the app should look like itself.
/// The price is that the icons no longer follow the text size automatically, but
/// they did not before either, since every call already set a fixed size.
///
/// Two variants are in use. Outline for everything that is frame and navigation,
/// solid for the buttons that sit on a coloured surface, where an outline would
/// vanish. That is how Heroicons itself is meant to be used.
enum Icon: String, CaseIterable {
    case information = "information-circle"
    case close = "x-mark"
    case chevronRight = "chevron-right"
    case chevronUp = "chevron-up"
    case chevronDown = "chevron-down"
    case hidden = "eye-slash"
    case share = "arrow-up-tray"
    case skipBack = "arrow-uturn-left"
    case skipForward = "arrow-uturn-right"

    case microphone = "microphone-solid"
    case stop = "stop-solid"
    case play = "play-solid"
    case pause = "pause-solid"
}

/// An icon at a given size, coloured like the text around it.
///
/// The size is given in points and comes from the measures in `Theme`, never as a
/// number at the call site. The icon is square: Heroicons are drawn on a 24 × 24
/// grid, and a square frame keeps them aligned with each other.
struct IconView: View {
    private let icon: Icon
    private let size: CGFloat

    init(_ icon: Icon, size: CGFloat) {
        self.icon = icon
        self.size = size
    }

    var body: some View {
        Image(icon.rawValue)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}
