import SwiftUI

struct RecordingRow: View {
    let recording: Recording

    var body: some View {
        HStack(alignment: .center, spacing: Space.s3) {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text(title)
                    .font(.Frodi.bodyMedium)
                    .foregroundStyle(Color.Frodi.textPrimary)

                Text(meta)
                    .font(.Frodi.meta)
                    .foregroundStyle(Color.Frodi.textSecondary)

                if recording.startedWithActionButton {
                    ActionButtonChip()
                        .padding(.top, Space.s1)
                }
            }

            Spacer(minLength: Space.s2)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.Frodi.textSecondary)
        }
        .padding(Space.s3)
        .background(Color.Frodi.surface, in: RoundedRectangle(cornerRadius: Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.control)
                .strokeBorder(Color.Frodi.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        recording.createdAt.formatted(.dateTime.day().month(.abbreviated).hour().minute())
    }

    private var meta: String {
        let length = Duration.seconds(recording.duration).formatted(.time(pattern: .minuteSecond))
        if recording.hasTranscript { return length }
        return recording.transcriptionFailed
            ? "\(length) · \(TranscriptionError.shortText(for: recording.failureCode))"
            : "\(length) · venter på transkribering"
    }
}

/// Liten pille som forteller at opptaket ble startet med handlingsknappen.
struct ActionButtonChip: View {
    var body: some View {
        HStack(spacing: Space.s1 + 2) {
            Circle()
                .fill(Color.Frodi.accentRecord)
                .frame(width: 6, height: 6)

            Text("Startet med handlingsknappen")
                .font(.Frodi.meta)
                .foregroundStyle(Color.Frodi.textSecondary)
        }
        .padding(.leading, Space.s2 + 2)
        .padding(.trailing, Space.s3 + 2)
        .padding(.vertical, Space.s1 + 2)
        .background(Color.Frodi.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.Frodi.border, lineWidth: 1))
    }
}
