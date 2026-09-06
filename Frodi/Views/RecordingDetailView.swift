import SwiftUI

struct RecordingDetailView: View {
    let recording: Recording

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Duration.seconds(recording.duration).formatted(.time(pattern: .minuteSecond)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                if recording.hasTranscript {
                    Text(recording.transcript ?? "")
                        .textSelection(.enabled)
                } else {
                    Text("Ingen tekst for dette opptaket.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(recording.createdAt.formatted(.dateTime.day().month().hour().minute()))
        .navigationBarTitleDisplayMode(.inline)
    }
}
