import SwiftUI

/// A question with a few answers, as a bottom sheet in the app's tokens: title, sentence, answers as rows, «Avbryt» under them.
/// Replaces the system confirmation dialog (a popover with an arrow, system face and colours). Sizes to content.
/// Answers stand under each other, never side by side (message-card rule): two buttons in a line read as one control.
struct ChoiceSheet<Answers: View>: View {
    let title: String
    let message: String
    @ViewBuilder let answers: () -> Answers

    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s4) {
                Text(verbatim: title)
                    .font(.Frodi.title)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(verbatim: message)
                    .font(.Frodi.body)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: Space.s2) {
                    answers()
                }
                // Plain, so the row drawn by `choiceRow` is the button, and the
                // whole of it is the target.
                .buttonStyle(.plain)
                .padding(.top, Space.s2)

                Button { dismiss() } label: {
                    Text("Avbryt")
                        .font(.Frodi.bodyMedium)
                        .foregroundStyle(Color.Frodi.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: ChoiceRow.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.s5)
            // Room for the drag indicator above, and the home indicator below.
            .padding(.top, Space.s6)
            .padding(.bottom, Space.s3)
            // The sheet is as tall as its content, and no taller. The ScrollView
            // only matters at the largest text sizes, where the content can
            // outgrow the screen.
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        // The body runs once before the content is measured. Zero is not a
        // detent SwiftUI accepts, and it said so in the log at every opening;
        // one point is, and the measurement replaces it.
        .presentationDetents([.height(max(height, 1))])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.Frodi.background)
    }
}

extension View {
    /// A `ChoiceSheet` answer (full width) or a `SwipeRow` action (`inline`: fits its word, one-line row tall whatever the row holds).
    /// Destructive: outlined in `recordingActive`, not filled; red has no `-on` colour, and an outline says «careful». 5,48:1 on Surface.
    func choiceRow(destructive: Bool = false, inline: Bool = false) -> some View {
        font(.Frodi.bodyMedium)
            .foregroundStyle(destructive ? Color.Frodi.recordingActive : Color.Frodi.textPrimary)
            .padding(.vertical, inline ? Space.s3 : 0)
            .frame(maxWidth: inline ? nil : .infinity, minHeight: ChoiceRow.height)
            .padding(.horizontal, Space.s4)
            .background(Color.Frodi.surface, in: RoundedRectangle(cornerRadius: Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control)
                    .strokeBorder(destructive ? Color.Frodi.recordingActive : Color.Frodi.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.control))
    }
}
