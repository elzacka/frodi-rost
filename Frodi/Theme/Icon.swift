import SwiftUI

/// The icons, from Material Symbols (Apache 2.0), bundled as vector SVG; `template` takes the colour from
/// `foregroundStyle`. Not SF Symbols, so the app looks like itself. Outlined, weight 400, optical size 24; filled only
/// on coloured surfaces. The raw value is Google's symbol name, `_fill` where the filled variant is bundled.
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
    case edit = "edit"

    case microphone = "mic_fill"
    case stop = "stop_fill"
    case play = "play_arrow_fill"
    case pause = "pause_fill"
}

/// An icon with a small disc knocked out of its lower trailing corner, carrying a second icon (the waveform with its
/// «add»). Drawn apart and joined here so each takes its colour from the design tokens; a template image takes only
/// one.
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

/// An icon at a given size, coloured like the surrounding text. The size comes from the measures in `Theme`, never a
/// number at the call site; the frame is square because Material Symbols sit on a 24 × 24 grid.
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
