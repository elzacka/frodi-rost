import SwiftUI
import UniformTypeIdentifiers

struct RecordingDetailView: View {
    let recording: Recording
    let onRetry: () async -> Void

    @State private var player = AudioPlayer.shared
    @State private var transcript: String = ""
    @State private var showsTranscript = false
    @State private var exportURLs: [URL] = []
    @State private var exportError: String?
    @State private var copied = false

    /// How long a copied transcript stays on the pasteboard.
    static let pasteboardLifetime: TimeInterval = 5 * 60

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
                    // The audio comes first. The text is a transcript of it, and the transcript
                    // is not always right; then you want to hear the original.
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
                    IconView(.share, size: IconSize.toolbar)
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
        // The key is the ciphertext itself, not the recording. If the transcription
        // finishes while you are here, it changes, and the text is unlocked again.
        // With the recording's id this ran only once, and the field stayed empty.
        .task(id: recording.sealedTranscript) {
            // The text is unlocked only when it is about to be shown.
            transcript = (try? recording.transcript()) ?? ""
        }
        .onDisappear {
            // No reason to leave the plaintext in memory afterwards.
            transcript = ""
        }
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: Space.s4) {
            if recording.hasTranscript, transcript.isEmpty {
                // The text exists but is not unlocked yet. Without this the card flashes
                // empty the moment the transcription finishes.
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.s5)
            } else if recording.hasTranscript {
                transcriptToggle

                if showsTranscript {
                    copyButton

                    Text(transcript)
                        .font(.Frodi.body)
                        .foregroundStyle(Color.Frodi.textPrimary)
                        .hiddenWhileScreenCaptured()
                }
            } else if recording.isTranscribing {
                HStack(spacing: Space.s3) {
                    ProgressView()
                    Text("Transkriberer …")
                        .font(.Frodi.body)
                        .foregroundStyle(Color.Frodi.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s5)
            } else if recording.transcriptionFailed {
                Text(TranscriptionError.explanation(for: recording.failureCode))
                    .font(.Frodi.body)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // A retry does not help when iOS lacks the language.
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
            } else {
                // No transcription started yet, and none has failed.
                Text(TranscriptionError.explanation(for: nil))
                    .font(.Frodi.body)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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

    /// The text is collapsed when you enter the page.
    ///
    /// A ten-minute recording is several screens of text, and then you scroll a
    /// long way to get back to the player. The word count is in the row, so you
    /// can see the whole recording came through without opening the text.
    ///
    /// Export takes the text from the recording itself and does not care whether
    /// the row is open or closed.
    private var transcriptToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { showsTranscript.toggle() }
        } label: {
            HStack(spacing: Space.s2) {
                Text("Tekst")
                    .font(.Frodi.eyebrow)
                    .eyebrowTracking()
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Frodi.textSecondary)

                Text(wordCount)
                    .font(.Frodi.meta)
                    .foregroundStyle(Color.Frodi.textSecondary)

                Spacer()

                IconView(showsTranscript ? .chevronUp : .chevronDown, size: IconSize.inline)
                    .foregroundStyle(Color.Frodi.textSecondary)
            }
            .frame(minHeight: Disclosure.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tekst, \(wordCount)")
        .accessibilityHint(showsTranscript ? "Skjuler teksten" : "Viser teksten")
    }

    /// Copies the whole text, and only to this device.
    ///
    /// The text used to be selectable, which gave the system copy menu. That menu
    /// writes to the general pasteboard with Universal Clipboard on, so a
    /// transcript would travel to every Mac and iPad on the same Apple account,
    /// in an app whose premise is that nothing leaves the device. A button of our
    /// own can say `localOnly`, and give the text a lifetime so it does not sit on
    /// the pasteboard for the next app to read an hour later.
    private var copyButton: some View {
        Button(copied ? "Kopiert" : "Kopier") {
            UIPasteboard.general.setItems(
                [[UTType.utf8PlainText.identifier: transcript]],
                options: [.localOnly: true, .expirationDate: Date.now.addingTimeInterval(Self.pasteboardLifetime)]
            )
            AccessibilityNotification.Announcement("Kopiert").post()
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        }
        .font(.Frodi.bodyMedium)
        .foregroundStyle(Color.Frodi.accentRecordOn)
        .padding(.horizontal, Space.s4)
        .padding(.vertical, Space.s2)
        .background(Color.Frodi.accentRecord, in: Capsule())
        .accessibilityHint("Kopierer hele teksten. Den blir bare på denne enheten.")
    }

    /// «312 ord». The number is also the answer to whether the whole recording came through.
    private var wordCount: String {
        let words = transcript.split(whereSeparator: \.isWhitespace).count
        return "\(words.formatted(.number.locale(AppLocale.norwegian))) ord"
    }

    /// Date, time and length are in the title, so the card itself is just the text.
    private var title: String {
        let stamp = recording.createdAt.recordingStamp
        let length = Duration.seconds(recording.duration).formatted(.time(pattern: .minuteSecond))
        return "\(stamp) | \(length)"
    }
}
