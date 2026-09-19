import SwiftUI

/// A button that is an icon and nothing else: no fill, no frame, in the tone
/// of every other icon, on the 44 pt target the design system asks for.
///
/// The settings button in the logo header and the buttons in the navigation
/// bars are all this. The record button is the one button with a fill of its
/// own. VoiceOver needs the name the icon does not write.
struct IconButton: View {
    let icon: Icon
    let size: CGFloat
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IconView(icon, size: size)
                .foregroundStyle(Color.Frodi.textSecondary)
                .frame(width: HeaderButton.touch, height: HeaderButton.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
