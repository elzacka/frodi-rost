import SwiftUI

struct RecorderBar: View {
    let controller: RecordingController

    private var recorder: AudioRecorder { controller.recorder }

    var body: some View {
        VStack(spacing: Space.s4) {
            // Timeren holder plassen sin også i hvile, ellers hopper knappen
            // nedover i det opptaket starter.
            Text(recorder.isRecording ? elapsed : " ")
                .font(.Frodi.timer)
                .monospacedDigit()
                .foregroundStyle(Color.Frodi.textPrimary)
                .contentTransition(.numericText())
                .accessibilityHidden(!recorder.isRecording)

            Button(action: toggle) {
                ZStack {
                    Circle()
                        .strokeBorder(ringColor, lineWidth: RecordButton.ring)
                        .frame(width: RecordButton.diameter, height: RecordButton.diameter)

                    Circle()
                        .fill(innerColor)
                        .frame(width: RecordButton.inner, height: RecordButton.inner)

                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(iconColor)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recorder.isRecording ? "Stopp opptak" : "Start opptak")
            .accessibilityAddTraits(.isButton)

            if case .denied = recorder.state {
                Text("Fróði trenger tilgang til mikrofonen. Du kan gi den i Innstillinger.")
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.s6)
            }
        }
        .padding(.vertical, Space.s5)
        .frame(maxWidth: .infinity)
        .background(Color.Frodi.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.Frodi.border)
                .frame(height: 1)
        }
    }

    private var elapsed: String {
        Duration.seconds(recorder.duration).formatted(.time(pattern: .minuteSecond))
    }

    private var ringColor: Color {
        recorder.state == .denied ? Color.Frodi.border : Color.Frodi.accentRecord
    }

    private var innerColor: Color {
        switch recorder.state {
        case .recording: Color.Frodi.recordingActive
        case .denied: Color.Frodi.border
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
