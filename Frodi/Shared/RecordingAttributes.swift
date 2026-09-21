import ActivityKit
import Foundation

/// What the Live Activity knows about the running recording. Compiled into the
/// app, which starts and ends the activity, and into the widget extension,
/// which draws it.
struct RecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the timer counts from: the start, moved forward by the time the
        /// recording has been paused, so the timer shows recorded time.
        var startedAt: Date
        /// The recorded time so far when the state was written. What the timer
        /// shows while the recording is paused, since it does not count then.
        var elapsed: TimeInterval
        /// A call, Siri or another app holds the microphone.
        var isInterrupted: Bool
    }
}
