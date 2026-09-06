import SwiftUI

struct RecorderBar: View {
    let recorder: AudioRecorder
    let onStop: (String, TimeInterval) -> Void

    var body: some View {
        VStack(spacing: 12) {
            if recorder.isRecording {
                Text(Duration.seconds(recorder.duration).formatted(.time(pattern: .minuteSecond)))
                    .font(.system(.title2, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Button(action: toggle) {
                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.title)
                    .frame(width: 72, height: 72)
                    .background(recorder.isRecording ? Color.red : Color.accentColor, in: .circle)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recorder.isRecording ? "Stopp opptak" : "Start opptak")

            if case .denied = recorder.state {
                Text("Fróði trenger tilgang til mikrofonen. Du kan gi den i Innstillinger.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func toggle() {
        if recorder.isRecording {
            if let result = recorder.stop() {
                onStop(result.fileName, result.duration)
            }
        } else {
            Task { await recorder.start() }
        }
    }
}
