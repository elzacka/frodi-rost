import SwiftUI
import UIKit

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
                .gesture(HorizontalPan(isEnabled: stage != .asking, onChanged: dragged, onEnded: released))
                .accessibilityHidden(stage == .asking)
                // Last, so the overlay and the gesture move with the row. An
                // overlay added after the offset stays where the row was, over
                // the actions, and takes their taps.
                .offset(x: offset)
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        .animation(reduceMotion ? nil : .spring(duration: 0.3), value: stage)
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

    /// Follows the finger between closed and open.
    private func dragged(_ width: CGFloat) {
        let proposed = restingOffset + width
        // The actions are measured once they are on screen, which is after the
        // first movement; until then the finger sets the pace.
        let farthest = actionsWidth > 0 ? -(actionsWidth + gap) : proposed
        drag = min(max(proposed, farthest), 0) - restingOffset
    }

    /// Settles on the nearer end when the finger lifts.
    private func released(_ width: CGFloat) {
        let landed = restingOffset + width
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
            drag = 0
            onStage(landed < -(actionsWidth + gap) / 2 ? .open : .closed)
        }
    }
}

/// A pan that begins only when the finger moves more sideways than up or down.
///
/// A vertical movement is the list's scroll, and must never be ours. SwiftUI's
/// `DragGesture` cannot decline a touch: attached to a row inside a
/// `ScrollView`, it took every drag that started on a row, and the list did not
/// scroll under a finger on a row at all (measured 2026-09-27). A UIKit pan can
/// decline in `gestureRecognizerShouldBegin`, and the scroll view gets the touch.
///
/// Measured in window space: the row moves under the finger, and a pan
/// measured in the row's own space would move with it.
private struct HorizontalPan: UIGestureRecognizerRepresentable {
    let isEnabled: Bool
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let width = recognizer.translation(in: nil).x
        switch recognizer.state {
        case .changed: onChanged(width)
        case .ended, .cancelled, .failed: onEnded(width)
        default: break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y)
        }
    }
}
