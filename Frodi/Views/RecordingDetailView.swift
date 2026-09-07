import SwiftUI

struct RecordingDetailView: View {
    let recording: Recording
    let onRetry: () async -> Void

    @State private var exportURLs: [URL] = []
    @State private var exportError: String?

    private func exportRecording() async {
        do {
            exportURLs = try await RecordingExport.prepare(recording)
        } catch {
            exportError = error.localizedDescription
        }
    }

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
                        Text(TranscriptionError.explanation(for: recording.failureCode))
                            .font(.Frodi.body)
                            .foregroundStyle(Color.Frodi.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // Et nytt forsøk hjelper ikke når iOS mangler språket.
                        if recording.failureCode != "localeUnsupported" {
                            Button("Prøv på nytt") {
                                Task { await onRetry() }
                            }
                            .font(.Frodi.bodyMedium)
                            .foregroundStyle(Color.Frodi.accentRecordOn)
                            .padding(.horizontal, Space.s4)
                            .padding(.vertical, Space.s2)
                            .background(Color.Frodi.accentRecord, in: Capsule())
                        }
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await exportRecording() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Hent ut opptaket")
            }
        }
        .sheet(isPresented: .constant(!exportURLs.isEmpty)) {
            ShareSheet(urls: exportURLs) {
                RecordingExport.cleanUp(exportURLs)
                exportURLs = []
            }
        }
        .alert("Kunne ikke hente ut", isPresented: .constant(exportError != nil)) {
            Button("Greit") { exportError = nil }
        } message: {
            Text(exportError ?? "").font(.Frodi.body)
        }
    }
}
