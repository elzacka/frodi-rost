import SwiftUI

struct RecordingRow: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recording.createdAt, format: .dateTime.day().month().hour().minute())
                .font(.headline)

            Text(preview)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(Duration.seconds(recording.duration).formatted(.time(pattern: .minuteSecond)))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var preview: String {
        if recording.hasTranscript { return recording.transcript ?? "" }
        return recording.transcriptionFailed
            ? String(localized: "Ingen tekst")
            : String(localized: "Gjør om til tekst …")
    }
}
