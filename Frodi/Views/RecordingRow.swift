import SwiftUI

struct RecordingRow: View {
    let recording: Recording

    var body: some View {
        HStack(alignment: .center, spacing: Space.s3) {
            VStack(alignment: .leading, spacing: Space.s1) {
                Text(title)
                    .font(.Frodi.bodyMedium)
                    .monospacedDigit()
                    .foregroundStyle(Color.Frodi.textPrimary)

                if let status {
                    HStack(spacing: Space.s1) {
                        if recording.isTranscribing {
                            ProgressView()
                        }

                        Text(status)
                            .font(.Frodi.meta)
                            .foregroundStyle(Color.Frodi.textSecondary)
                    }
                }
            }

            Spacer(minLength: Space.s2)

            IconView(.chevronRight, size: IconSize.inline)
                .foregroundStyle(Color.Frodi.textSecondary)
        }
        .padding(Space.s3)
        .background(Color.Frodi.surface, in: RoundedRectangle(cornerRadius: Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.control)
                .strokeBorder(Color.Frodi.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenLabel)
    }

    /// Dato, tidspunkt og lengde på én linje, delt med en loddrett strek.
    private var title: String {
        "\(stamp) | \(length)"
    }

    /// Bare det som ikke står i tittelen: hvorfor teksten mangler.
    private var status: String? {
        if recording.hasTranscript { return nil }
        if recording.isTranscribing { return "transkriberer" }
        return recording.transcriptionFailed
            ? TranscriptionError.shortText(for: recording.failureCode)
            : "venter på transkribering"
    }

    /// VoiceOver leser ikke en loddrett strek som en pause, så den får en egen setning.
    private var spokenLabel: String {
        let spoken = "\(stamp), \(length)"
        guard let status else { return spoken }
        return "\(spoken), \(status)"
    }

    private var stamp: String {
        recording.createdAt.recordingStamp
    }

    private var length: String {
        Duration.seconds(recording.duration).formatted(.time(pattern: .minuteSecond))
    }
}
