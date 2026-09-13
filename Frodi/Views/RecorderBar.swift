import SwiftUI

struct RecorderBar: View {
    let controller: RecordingController

    private var recorder: AudioRecorder { controller.recorder }

    var body: some View {
        VStack(spacing: Space.s3) {
            // The numbers sit beside the button, not above it. Above the button the bar
            // grew so tall that the list of recordings disappeared behind it.
            //
            // Both sides take the same space, so the button stays centred no matter how
            // wide the numbers are.
            HStack(spacing: Space.s4) {
                timer
                    .frame(maxWidth: .infinity, alignment: .leading)

                recordButton

                remaining
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if recorder.isInterrupted {
                Text("Opptaket er satt på pause og fortsetter etterpå.")
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.s4)
            }

            if case .denied = recorder.state {
                Text("Fróði trenger tilgang til mikrofonen. Du gir tilgang i Innstillinger.")
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.s4)
            }
        }
        .padding(.horizontal, Space.s5)
        .padding(.vertical, Space.s4)
        .frame(maxWidth: .infinity)
        .background(Color.Frodi.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.Frodi.border)
                .frame(height: 1)
        }
    }

    /// Holds its space while idle too, or the button moves the moment recording starts.
    private var timer: some View {
        Text(recorder.isRecording ? elapsed : " ")
            .font(.Frodi.timer)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(Color.Frodi.textPrimary)
            .contentTransition(.numericText())
            .accessibilityLabel("Tid gått")
            .accessibilityValue(spoken(recorder.duration))
            .accessibilityHidden(!recorder.isRecording)
    }

    /// What is left of the limit while recording runs.
    ///
    /// It sits to the right of the button, where the mirrored timer used to be.
    /// The space was already reserved, and two numbers on either side of the button
    /// read as what they are: what has passed, and what remains.
    ///
    /// The minus sign is the one the player uses for remaining time, and is what
    /// tells the two numbers apart without a label.
    ///
    /// When idle the field is empty. The limit belongs with the information about
    /// the app, not above the record button: someone who has not started talking
    /// does not need the ceiling yet, and a number there would just be noise beside
    /// the button. Like the timer, the field still holds its space, or the button
    /// moves the moment recording starts.
    private var remaining: some View {
        Text(recorder.isRecording ? "−" + clock(recorder.remaining) : " ")
            .font(.Frodi.bodyMedium)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(Color.Frodi.textSecondary)
            .contentTransition(.numericText())
            .accessibilityLabel("Tid igjen av opptaket")
            .accessibilityValue(spoken(recorder.remaining))
            .accessibilityHidden(!recorder.isRecording)
    }

    private var recordButton: some View {
        Button(action: toggle) {
            ZStack {
                Circle()
                    .strokeBorder(ringColor, lineWidth: RecordButton.ring)
                    .frame(width: RecordButton.diameter, height: RecordButton.diameter)

                Circle()
                    .fill(innerColor)
                    .frame(width: RecordButton.inner, height: RecordButton.inner)

                IconView(recorder.isRecording ? .stop : .microphone, size: RecordButton.icon)
                    .foregroundStyle(iconColor)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recorder.isRecording ? "Stopp opptak" : "Start opptak")
        .accessibilityAddTraits(.isButton)
    }

    private var elapsed: String {
        clock(recorder.duration)
    }

    private func clock(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }

    /// «2 minutter, 5 sekunder»: the number spelled out, the way the player does it.
    private func spoken(_ seconds: TimeInterval) -> String {
        let units = Duration.UnitsFormatStyle(allowedUnits: [.minutes, .seconds], width: .wide)
        return Duration.seconds(seconds).formatted(units)
    }

    private var ringColor: Color {
        recorder.state == .denied ? Color.Frodi.border : Color.Frodi.accentRecord
    }

    /// Denied access gives an outlined button, not a filled grey one.
    ///
    /// The fill was the border colour. Once border became dark enough to be a
    /// visible edge, the filled button was darker than the live one and read as
    /// switched on. An outline says «nothing here» without shouting.
    private var innerColor: Color {
        switch recorder.state {
        case .recording: Color.Frodi.recordingActive
        case .denied: Color.Frodi.surface
        default: Color.Frodi.accentRecord
        }
    }

    private var iconColor: Color {
        switch recorder.state {
        case .recording: Color.Frodi.surface
        case .denied: Color.Frodi.textSecondary
        default: Color.Frodi.accentRecordOn
        }
    }

    private func toggle() {
        Task { await controller.toggle() }
    }
}
