import SwiftUI

struct RecordingDetailView: View {
    let recording: Recording
    let onRetry: () async -> Void

    @State private var player = AudioPlayer.shared
    @State private var transcript: String = ""
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
                VStack(spacing: Space.s4) {
                    // Lyden står øverst. Teksten er en avskrift av den, og
                    // avskriften er ikke alltid riktig — da vil du høre originalen.
                    PlaybackControls(recording: recording, player: player)

                    transcriptCard
                }
                .padding(Space.s4)
            }
        }
        .navigationTitle(title)
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
        // Nøkkelen er selve chifferteksten, ikke opptaket. Blir transkriberingen
        // ferdig mens du står her, endrer den seg, og teksten låses opp på nytt.
        // Med opptakets id kjørte dette bare én gang, og feltet ble stående tomt.
        .task(id: recording.sealedTranscript) {
            // Teksten låses opp først når den skal vises.
            transcript = (try? recording.transcript()) ?? ""
        }
        .onDisappear {
            // Ingen grunn til å la klarteksten ligge i minnet etterpå.
            transcript = ""
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            if recording.hasTranscript, transcript.isEmpty {
                // Teksten finnes, men er ikke låst opp ennå. Uten dette
                // blinker kortet tomt i det transkriberingen blir ferdig.
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.s5)
            } else if recording.hasTranscript {
                Text(transcript)
                    .font(.Frodi.body)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .textSelection(.enabled)
                    .hiddenWhileScreenCaptured()
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
    }

    /// Dato, tidspunkt og lengde står i tittelen, så selve kortet er bare teksten.
    private var title: String {
        let stamp = recording.createdAt.recordingStamp
        let length = Duration.seconds(recording.duration).formatted(.time(pattern: .minuteSecond))
        return "\(stamp) | \(length)"
    }
}
