import SwiftUI

/// A button that is an icon and nothing else: no fill, no frame, the tone of every other icon, on the 44 pt target the design system asks for.
/// Used by the header settings button and navigation bars; the record button alone has a fill. VoiceOver needs the name the icon does not write.
struct IconButton: View {
    let icon: Icon
    /// A second icon on a disc in the corner, which says what the button adds
    /// to the first; see `BadgedIconView`.
    var badge: Icon?
    let size: CGFloat
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let badge {
                    BadgedIconView(icon, badge: badge, size: size)
                } else {
                    IconView(icon, size: size)
                        .foregroundStyle(Color.Frodi.textSecondary)
                }
            }
            .frame(width: HeaderButton.touch, height: HeaderButton.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
