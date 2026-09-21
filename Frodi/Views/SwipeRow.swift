import SwiftUI

/// Where a swiped row is: closed, showing its actions, or asking a question.
enum SwipeStage: Equatable {
    case closed
    case open
    case asking
}

/// A list row that slides left to show what can be done with it, where it is.
///
/// The actions stand behind the row at its trailing edge, and the swipe
/// uncovers them: the row's own shape moves and nothing is laid over the list.
/// An action that has to ask first asks in the same place. The row slides all
/// the way out, and the question with its answers takes the width behind it.
/// One mechanism for the reveal and for the question, so the way from the
/// swipe to the answer is one component in one design.
///
/// The stage belongs to the list, not the row, so that one row is open at a
/// time and a deleted row takes its stage with it.
struct SwipeRow<Content: View, Actions: View, Question: View>: View {
    let stage: SwipeStage
    let onStage: (SwipeStage) -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let actions: () -> Actions
    @ViewBuilder let question: () -> Question

    @State private var actionsWidth: CGFloat = 0
    @State private var rowWidth: CGFloat = 0
    @State private var drag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The gap between the row and the first action, the same as between rows.
    private let gap = Space.s3

    var body: some View {
        ZStack(alignment: .trailing) {
            // Only while there is something to see: a closed row has nothing
            // behind it, so VoiceOver finds no buttons under the rows.
            if stage != .closed || drag != 0 {
                behind
            }

            content()
                .overlay {
                    // Tapping the row while it shows its actions closes it
                    // rather than opening the recording.
                    if stage == .open {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { onStage(.closed) }
                    }
                }
                .gesture(swipe, isEnabled: stage != .asking)
                .accessibilityHidden(stage == .asking)
                // Last, so the overlay and the gesture move with the row. An
                // overlay added after the offset stays where the row was, over
                // the actions, and takes their taps.
                .offset(x: offset)
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        .animation(.spring(duration: 0.3), value: stage)
    }

    /// What the row uncovers: its actions when open, the question when asking.
    @ViewBuilder
    private var behind: some View {
        switch stage {
        case .asking:
            HStack(spacing: Space.s2) {
                question()
            }
            .buttonStyle(.plain)
        default:
            HStack(spacing: Space.s2) {
                actions()
            }
            .buttonStyle(.plain)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { actionsWidth = $0 }
        }
    }

    private var restingOffset: CGFloat {
        switch stage {
        case .closed: 0
        case .open: -(actionsWidth + gap)
        case .asking: -(rowWidth + gap)
        }
    }

    private var offset: CGFloat {
        restingOffset + drag
    }

    /// Follows the finger between closed and open, and settles on the nearer
    /// end when it lifts. A vertical movement is the list's scroll, not ours.
    ///
    /// Measured in global space: the row moves under the finger, and a drag
    /// measured in the row's own space would move with it.
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let proposed = restingOffset + value.translation.width
                // The actions are measured once they are on screen, which is
                // after the first movement; until then the finger sets the pace.
                let farthest = actionsWidth > 0 ? -(actionsWidth + gap) : proposed
                drag = min(max(proposed, farthest), 0) - restingOffset
            }
            .onEnded { value in
                let landed = restingOffset + value.translation.width
                withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
                    drag = 0
                    onStage(landed < -(actionsWidth + gap) / 2 ? .open : .closed)
                }
            }
    }
}
