import SwiftUI

/// The icons in the app, taken from Material Symbols.
///
/// Material Symbols is drawn by Google and Apache 2.0 licensed. The files live in
/// the asset catalogue as SVG with vector data preserved, so they are sharp at
/// every size. `template` makes the colour come from `foregroundStyle`, so an
/// icon follows the design system's text colours instead of having its own.
///
/// Why not SF Symbols: they are Apple's, and the app should look like itself.
/// The price is that the icons no longer follow the text size automatically, but
/// they did not before either, since every call already set a fixed size.
///
/// One style, Outlined, at weight 400 and optical size 24. Two fills are in use:
/// unfilled for everything that is frame and navigation, filled for the buttons
/// that sit on a coloured surface, where an outline would vanish. The raw value
/// is Google's own name for the symbol, with `_fill` where the filled variant is
/// the one bundled.
enum Icon: String, CaseIterable {
    case settings = "instant_mix"
    case importAudio = "graphic_eq"
    /// Google's file name, not the symbol name: an asset called `add` collides
    /// with `UIImage.add` in the Swift symbols Xcode generates for the catalogue.
    case add = "add_24px"
    case close = "close"
    case back = "arrow_back_ios_new"
    case chevronRight = "chevron_right"
    case chevronUp = "expand_less"
    case chevronDown = "expand_more"
    case hidden = "visibility_off"
    case share = "ios_share"
    case skipBack = "replay_10"
    case skipForward = "forward_10"
    case resize = "drag_handle"
    case external = "open_in_new"

    case microphone = "mic_fill"
    case stop = "stop_fill"
    case play = "play_arrow_fill"
    case pause = "pause_fill"
}

/// An icon with a small disc knocked out of its lower trailing corner, carrying
/// a second icon: the waveform with its «add». The two are drawn apart and
/// joined here rather than baked into one image, so each takes its colour from
/// the design system's tokens; a template image can only take one.
struct BadgedIconView: View {
    private let icon: Icon
    private let badge: Icon
    private let size: CGFloat

    init(_ icon: Icon, badge: Icon, size: CGFloat) {
        self.icon = icon
        self.badge = badge
        self.size = size
    }

    var body: some View {
        let disc = size * IconBadge.diameter
        let cut = disc + 2 * IconBadge.gap
        ZStack(alignment: .topLeading) {
            // The gap is cut out of the icon, not painted over it in the
            // background colour, so it holds on any surface.
            IconView(icon, size: size)
                .foregroundStyle(Color.Frodi.textSecondary)
                .overlay(alignment: .topLeading) {
                    Circle()
                        .frame(width: cut, height: cut)
                        .offset(x: size * IconBadge.center.x - cut / 2, y: size * IconBadge.center.y - cut / 2)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()

            Circle()
                .fill(Color.Frodi.accentRecord)
                .overlay {
                    IconView(badge, size: disc)
                        .foregroundStyle(Color.Frodi.accentRecordOn)
                }
                .frame(width: disc, height: disc)
                .offset(x: size * IconBadge.center.x - disc / 2, y: size * IconBadge.center.y - disc / 2)
        }
        .frame(width: size, height: size, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// An icon at a given size, coloured like the text around it.
///
/// The size is given in points and comes from the measures in `Theme`, never as a
/// number at the call site. The icon is square: Material Symbols are drawn on a
/// 24 × 24 grid, and a square frame keeps them aligned with each other.
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
