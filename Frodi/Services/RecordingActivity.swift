import ActivityKit
import Foundation

/// The Live Activity for a running recording on the Lock Screen and in the Dynamic Island; the widget extension draws
/// it, this starts, updates and ends it. Required: `AudioRecordingIntent` demands one for as long as the app records,
/// and iOS stops a recording that has none. It also shows on a locked device that recording runs, with a stop button.
@MainActor
enum RecordingActivity {
    static func start() {
        // Ended after the new one is requested, by id: the end runs in a task,
        // and a task that reads the list then would end the new one too.
        let stale = Activity<RecordingAttributes>.activities.map(\.id)
        defer { end(ids: stale) }
        let state = RecordingAttributes.ContentState(startedAt: .now, elapsed: 0, isInterrupted: false)
        do {
            _ = try Activity.request(attributes: RecordingAttributes(), content: .init(state: state, staleDate: nil))
        } catch {
            // Live Activities can be switched off per app in Innstillinger. The
            // recording goes on in front; from the control iOS will stop it.
            AudioRecorder.log.error("Live Activity did not start: \(error, privacy: .public)")
        }
    }

    /// A pause or a resume. The timer counts from `startedAt`, so a resume moves
    /// it forward by the time the pause took.
    static func update(elapsed: TimeInterval, isInterrupted: Bool) {
        let state = RecordingAttributes.ContentState(
            startedAt: .now.addingTimeInterval(-elapsed),
            elapsed: elapsed,
            isInterrupted: isInterrupted
        )
        Task {
            for activity in Activity<RecordingAttributes>.activities {
                await activity.update(.init(state: state, staleDate: nil))
            }
        }
    }

    /// Ends every activity of the app's, also one a crash left behind.
    static func end() {
        end(ids: Activity<RecordingAttributes>.activities.map(\.id))
    }

    private static func end(ids: [String]) {
        Task {
            for activity in Activity<RecordingAttributes>.activities where ids.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
