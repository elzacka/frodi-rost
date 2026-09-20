import SwiftUI

struct RecorderBar: View {
    let controller: RecordingController

    @Environment(\.openURL) private var openURL

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

                // Empty, and the same width as the timer, so the button stays centred.
                // A countdown sat here while recordings had a limit; they no longer do.
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: 1)
            }

            if recorder.isInterrupted {
                Text("Opptaket er satt på pause og fortsetter når mikrofonen er ledig igjen.")
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.s4)
            }

            if case .denied = recorder.state {
                Text("Fróði trenger tilgang til mikrofonen. Du gir tilgang i Innstillinger på enheten.")
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.s4)

                // The one place a shortcut to the system's Innstillinger belongs:
                // where the user who cannot record is looking.
                Button("Åpne Innstillinger") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.Frodi.bodyMedium)
                .foregroundStyle(Color.Frodi.accentRecordOn)
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s2)
                .background(Color.Frodi.accentRecord, in: Capsule())
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
            .accessibilityLabel("Opptakstid")
            .accessibilityValue(spoken(recorder.duration))
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
