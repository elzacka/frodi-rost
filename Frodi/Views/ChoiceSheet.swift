import SwiftUI

/// A question with a few answers, as a sheet from the bottom.
///
/// The system's confirmation dialog is what this replaces. On iPhone it comes
/// up as a popover with an arrow pointing at the row it was asked from, in the
/// system's own face and colours, wherever the row happens to be. Nothing in
/// it is ours. This is the same question in the app's tokens: a title, a
/// sentence, the answers as rows, and «Avbryt» under them. It sizes itself to
/// what it holds, so a two-answer question does not get a half-screen sheet.
///
/// The answers stand under each other, never side by side. That is the design
/// system's rule for a message card, and it holds here for the same reason:
/// two buttons in one line are read as one control with two halves.
struct ChoiceSheet<Answers: View>: View {
    let title: String
    let message: String
    @ViewBuilder let answers: () -> Answers

    @Environment(\.dismiss) private var dismiss
    @State private var height: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s4) {
                Text(title)
                    .font(.Frodi.title)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Text(message)
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
    /// One answer in a `ChoiceSheet`: a full-width row in the shape of a list row,
    /// applied to the label of the button.
    ///
    /// The destructive one is outlined and written in `recordingActive`, the
    /// red the design system reserves for where something is lost. Outlined,
    /// not filled: there is no `-on` colour for red, and an outline says
    /// «careful» without shouting. 5,48:1 on Surface, so the word is readable.
    func choiceRow(destructive: Bool = false) -> some View {
        font(.Frodi.bodyMedium)
            .foregroundStyle(destructive ? Color.Frodi.recordingActive : Color.Frodi.textPrimary)
            .frame(maxWidth: .infinity, minHeight: ChoiceRow.height)
            .padding(.horizontal, Space.s4)
            .background(Color.Frodi.surface, in: RoundedRectangle(cornerRadius: Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.control)
                    .strokeBorder(destructive ? Color.Frodi.recordingActive : Color.Frodi.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.control))
    }
}
