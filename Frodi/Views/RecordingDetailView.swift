import SwiftUI

struct RecordingDetailView: View {
    let recording: Recording

    var body: some View {
        ZStack {
            Color.Frodi.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.s4) {
                    Text("OPPTAK")
                        .font(.Frodi.eyebrow)
                        .eyebrowTracking()
                        .foregroundStyle(Color.Frodi.textSecondary)

                    Text(Duration.seconds(recording.duration).formatted(.time(pattern: .minuteSecond)))
                        .font(.Frodi.caption)
                        .monospacedDigit()
                        .foregroundStyle(Color.Frodi.textSecondary)

                    if recording.hasTranscript {
                        Text(recording.transcript ?? "")
                            .font(.Frodi.body)
                            .foregroundStyle(Color.Frodi.textPrimary)
                            .textSelection(.enabled)
                    } else {
                        Text(recording.transcriptionFailed
                             ? "Fant ingen tekst i dette opptaket."
                             : "Venter på transkribering.")
                            .font(.Frodi.body)
                            .foregroundStyle(Color.Frodi.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.s5)
                .background(Color.Frodi.surface, in: RoundedRectangle(cornerRadius: Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card)
                        .strokeBorder(Color.Frodi.border, lineWidth: 1)
                )
                .padding(Space.s4)
            }
        }
        .navigationTitle(recording.createdAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.Frodi.background, for: .navigationBar)
    }
}
