import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// A running recording on the Lock Screen and in the Dynamic Island.
///
/// Designed for the car: the device lies on the pad and is read at a glance,
/// so the banner is the recorder bar's recording state and nothing else. The
/// eyebrow says what is happening, the timer how long, and the one button
/// stops. The stop button runs the same intent as the control, in the app.
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            RecordingBanner(state: context.state)
                .activityBackgroundTint(Color.Frodi.surface)
                .activitySystemActionForegroundColor(Color.Frodi.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    RecordingStatus(state: context.state)
                        .foregroundStyle(.primary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    StopButton()
                }
            } compactLeading: {
                IconView(.microphone, size: LiveActivity.compactIcon)
                    .foregroundStyle(Color.Frodi.recordingActive)
            } compactTrailing: {
                RecordingClock(state: context.state)
                    .font(.Frodi.meta)
                    .foregroundStyle(.primary)
            } minimal: {
                IconView(.microphone, size: LiveActivity.compactIcon)
                    .foregroundStyle(Color.Frodi.recordingActive)
            }
        }
    }
}

/// The Lock Screen banner: status and timer to the left, stop to the right.
private struct RecordingBanner: View {
    let state: RecordingAttributes.ContentState

    var body: some View {
        HStack(spacing: Space.s4) {
            RecordingStatus(state: state)
                .foregroundStyle(Color.Frodi.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            StopButton()
        }
        .padding(Space.s4)
    }
}

/// The eyebrow and the timer, stacked like the recorder bar's timer column.
private struct RecordingStatus: View {
    let state: RecordingAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text(state.isInterrupted ? "På pause" : "Tar opp")
                .font(.Frodi.eyebrow)
                .eyebrowTracking()
                .textCase(.uppercase)
                .foregroundStyle(Color.Frodi.textSecondary)
            RecordingClock(state: state)
                .font(.Frodi.timer)
                .accessibilityLabel("Opptakstid")
        }
    }
}

/// The recorded time. Counts by itself while recording, which is what keeps
/// the banner alive without the app touching it; stands still while paused.
private struct RecordingClock: View {
    let state: RecordingAttributes.ContentState

    var body: some View {
        if state.isInterrupted {
            Text(Duration.seconds(state.elapsed).formatted(.time(pattern: .minuteSecond)))
                .monospacedDigit()
        } else {
            Text(timerInterval: state.startedAt...Date.distantFuture, countsDown: false, showsHours: false)
                .monospacedDigit()
        }
    }
}

/// The record button in its recording state: red, with the stop mark.
private struct StopButton: View {
    var body: some View {
        Button(intent: ToggleRecordingIntent()) {
            ZStack {
                Circle()
                    .fill(Color.Frodi.recordingActive)
                    .frame(width: LiveActivity.stop, height: LiveActivity.stop)
                IconView(.stop, size: LiveActivity.stopIcon)
                    .foregroundStyle(Color.Frodi.surface)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stopp opptak")
    }
}
