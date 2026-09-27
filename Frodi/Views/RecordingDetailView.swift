import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct RecordingDetailView: View {
    let recording: Recording
    let onRetry: () async -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.concealment) private var concealment
    @State private var player = AudioPlayer.shared
    @State private var transcription = TranscriptionState.shared
    @State private var transcript: String = ""
    /// What has come out so far while the transcription runs, read from its progress.
    @State private var partial: [TranscriptParagraph] = []
    @State private var showsTranscript = false
    @State private var origin: OriginState = .none
    @State private var showsOrigin = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var exportURLs: [URL] = []
    @State private var exportError: String?
    @State private var copied = false
    /// The question of what to hand over is asked only when there is a text to
    /// hand over with the audio. Without one there is nothing to choose.
    @State private var asksWhatToExport = false
    /// The answer, carried from the choice sheet to the share sheet. The second
    /// sheet can only come up once the first is down, so the export starts
    /// from the choice sheet's `onDismiss`, not from the tap.
    @State private var chosenExport: RecordingExport.Content?

    /// How long a copied transcript stays on the pasteboard.
    static let pasteboardLifetime: TimeInterval = 5 * 60

    private func exportRecording(_ content: RecordingExport.Content) async {
        do {
            exportURLs = try await RecordingExport.prepare(recording, content: content)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func choose(_ content: RecordingExport.Content) {
        chosenExport = content
        asksWhatToExport = false
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

                    originCard
                }
                .padding(Space.s4)
            }
        }
        // The system's own rename: a menu on the title, and the title becomes
        // the field. The navigation bar's title is the system's by the design
        // file's rule, so this is the one place a name can be given without a
        // control of the app's own.
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleMenu { RenameButton() }
        .toolbarBackground(Color.Frodi.background, for: .navigationBar)
        .frodiBackButton()
        .toolbar {
            ToolbarButton(icon: .share, label: "Eksporter opptaket", placement: .topBarTrailing) {
                if recording.hasTranscript {
                    asksWhatToExport = true
                } else {
                    Task { await exportRecording(.audio) }
                }
            }
        }
        .sheet(isPresented: $asksWhatToExport) {
            guard let chosenExport else { return }
            self.chosenExport = nil
            Task { await exportRecording(chosenExport) }
        } content: {
            ChoiceSheet(
                title: "Eksporter",
                message: "Lyd som .m4a, tekst som \(RecordingExport.TextFormat.chosen.label). Tekstformatet velger du i Innstillinger."
            ) {
                Button { choose(.both) } label: { Text("Opptak og tekst").choiceRow() }
                Button { choose(.audio) } label: { Text("Bare opptaket").choiceRow() }
                Button { choose(.text) } label: { Text("Bare teksten").choiceRow() }
            }
        }
        .sheet(isPresented: .constant(!exportURLs.isEmpty)) {
            ShareSheet(urls: exportURLs) {
                RecordingExport.cleanUp(exportURLs)
                exportURLs = []
            }
        }
        .alert("Kunne ikke eksportere", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            Text(verbatim: exportError ?? "").font(.Frodi.body)
        }
        // The key is the ciphertext itself, not the recording. If the transcription
        // finishes while you are here, it changes, and the text is unlocked again.
        // With the recording's id this ran only once, and the field stayed empty.
        .task(id: recording.sealedTranscript) {
            // The text is unlocked only when it is about to be shown.
            transcript = (try? recording.transcript()) ?? ""
        }
        // An hour of interview takes a while. The paragraphs done so far are shown
        // as they arrive, so the wait is not a blank card.
        .task(id: fraction) {
            guard recording.isTranscribing else { partial = []; return }
            partial = TranscriptProgress.load(for: recording.fileName)?.paragraphs ?? []
        }
        .task(id: recording.sealedOrigin) {
            origin = recording.origin()
        }
        .onDisappear {
            // No reason to leave the plaintext in memory afterwards.
            transcript = ""
            partial = []
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

                    paragraphs(Transcript.paragraphs(in: transcript))
                        .hiddenWhileScreenCaptured()
                }
            } else if recording.isTranscribing {
                HStack(spacing: Space.s3) {
                    if let fraction {
                        ProgressView(value: fraction)
                            .tint(Color.Frodi.accentRecord)
                    } else {
                        ProgressView()
                    }
                    Text(verbatim: progressText)
                        .font(.Frodi.body)
                        .foregroundStyle(Color.Frodi.textSecondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.s3)

                if !partial.isEmpty {
                    paragraphs(partial.map { ($0.start, $0.text) })
                        .hiddenWhileScreenCaptured()
                }
            } else if Transcription.awaitsRequest(recording) {
                Text("Opptaket er langt. Trykk på «Lag tekst» når du vil ha teksten. En time med opptak tar noen minutter. Hold appen åpen imens.")
                    .font(.Frodi.body)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Lag tekst") {
                    Task { await onRetry() }
                }
                .font(.Frodi.bodyMedium)
                .foregroundStyle(Color.Frodi.accentRecordOn)
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s2)
                .background(Color.Frodi.accentRecord, in: Capsule())
            } else if recording.transcriptionFailed {
                Text(verbatim: TranscriptionError.explanation(for: recording.failureCode))
                    .font(.Frodi.body)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Prøv på nytt") {
                    Task { await onRetry() }
                }
                .font(.Frodi.bodyMedium)
                .foregroundStyle(Color.Frodi.accentRecordOn)
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s2)
                .background(Color.Frodi.accentRecord, in: Capsule())
            } else {
                // No transcription started yet, and none has failed.
                Text(verbatim: TranscriptionError.explanation(for: nil))
                    .font(.Frodi.body)
                    .foregroundStyle(Color.Frodi.textPrimary)
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
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showsTranscript.toggle() }
        } label: {
            HStack(spacing: Space.s2) {
                Text("Tekst")
                    .font(.Frodi.eyebrow)
                    .eyebrowTracking()
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Frodi.textSecondary)

                Text(verbatim: wordCount)
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

    /// The text as paragraphs, each opened by the time it was said at.
    ///
    /// The mark is a button: it moves the player there, which is what a mark is
    /// for. A reader checking a quote against the audio should not have to scrub
    /// for it. The number is shown, not only spoken, so it serves the sighted
    /// reader too.
    private func paragraphs(_ items: [(mark: TimeInterval?, text: String)]) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: Space.s1) {
                    if let mark = item.mark {
                        Button {
                            player.seek(to: mark)
                            if !player.isPlaying { player.togglePlayback() }
                        } label: {
                            Text(verbatim: Transcript.mark(mark))
                                .font(.Frodi.meta)
                                .monospacedDigit()
                                .foregroundStyle(Color.Frodi.textSecondary)
                                .underline()
                                .frame(minHeight: Disclosure.row / 2)
                        }
                        .buttonStyle(.plain)
                        .disabled(!player.isLoaded)
                        .accessibilityLabel("Spill av fra \(spoken(mark))")
                    }

                    Text(verbatim: item.text)
                        .font(.Frodi.body)
                        .foregroundStyle(Color.Frodi.textPrimary)
                }
            }
        }
    }

    private var fraction: Double? {
        transcription.fraction[recording.persistentModelID]
    }

    /// «Lager tekst, 43 %». The percentage is what says the work is moving.
    private var progressText: String {
        guard let fraction else { return "Lager tekst …" }
        return "Lager tekst, \(fraction.formatted(.percent.precision(.fractionLength(0)).locale(AppLocale.norwegian)))"
    }

    /// «12 minutter, 37 sekunder», the way the player already says it.
    private func spoken(_ seconds: TimeInterval) -> String {
        let units = Duration.UnitsFormatStyle(allowedUnits: [.hours, .minutes, .seconds], width: .wide)
        return Duration.seconds(seconds).formatted(units)
    }

    /// «312 ord». The number is also the answer to whether the whole recording came through.
    private var wordCount: String {
        let words = Transcript.paragraphs(in: transcript)
            .reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
        return "\(words.formatted(.number.locale(AppLocale.norwegian))) ord"
    }

    /// Date, time and length are in the title, so the card itself is just the text.
    private var title: String {
        let stamp = recording.createdAt.recordingStamp
        let length = Duration.seconds(recording.duration).formatted(.time(pattern: .minuteSecond))
        return "\(stamp) | \(length)"
    }

    /// The title, and what renaming writes to. The date stands in until a name is
    /// given, and again while the screen is recorded or photographed for the app
    /// switcher. Leaving the date as it is, or emptying the field, names nothing.
    private var name: Binding<String> {
        Binding(
            get: { concealment == .none ? recording.title() ?? title : title },
            set: { newName in
                try? recording.setTitle(newName == title ? nil : newName)
                try? context.save()
            }
        )
    }

    // MARK: - Origin

    /// What the recording was when it came into the app, as it was locked then.
    /// Collapsed like the text: it is there for the day someone asks, not for
    /// every visit. A recording from before origins were kept has no card.
    @ViewBuilder
    private var originCard: some View {
        switch origin {
        case .none:
            EmptyView()
        case .unverifiable:
            Text("Fróði kan ikke bekrefte opplysningene om dette opptaket. De kan være endret utenfor appen.")
                .font(.Frodi.body)
                .foregroundStyle(Color.Frodi.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.s5)
                .background(Color.Frodi.surface, in: RoundedRectangle(cornerRadius: Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card)
                        .strokeBorder(Color.Frodi.recordingActive, lineWidth: 1)
                )
        case .verified(let origin):
            VStack(alignment: .leading, spacing: Space.s4) {
                originToggle

                if showsOrigin {
                    // Hidden like the text: the original's file name can say as
                    // much as a name does.
                    VStack(alignment: .leading, spacing: Space.s3) {
                        ForEach(Array(facts(of: origin).enumerated()), id: \.offset) { _, fact in
                            VStack(alignment: .leading, spacing: Space.s1) {
                                Text(verbatim: fact.label)
                                    .font(.Frodi.meta)
                                    .foregroundStyle(Color.Frodi.textSecondary)
                                Text(verbatim: fact.value)
                                    .font(fact.label == "SHA-256" ? .Frodi.meta : .Frodi.body)
                                    .monospacedDigit()
                                    .foregroundStyle(Color.Frodi.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .hiddenWhileScreenCaptured()

                    Text(origin.source == .imported
                         ? "Fróði låste disse opplysningene da filen ble importert. Du kan gi opptaket et nytt navn, men ikke endre dem. Med sjekksummen kan du bekrefte at en fil er den samme som ble importert."
                         : "Fróði låste disse opplysningene da opptaket ble lagret. Du kan gi opptaket et nytt navn, men ikke endre dem.")
                        .font(.Frodi.caption)
                        .foregroundStyle(Color.Frodi.textPrimary)
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
    }

    private var originToggle: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { showsOrigin.toggle() }
        } label: {
            HStack(spacing: Space.s2) {
                Text("Om opptaket")
                    .font(.Frodi.eyebrow)
                    .eyebrowTracking()
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Frodi.textSecondary)

                Spacer()

                IconView(showsOrigin ? .chevronUp : .chevronDown, size: IconSize.inline)
                    .foregroundStyle(Color.Frodi.textSecondary)
            }
            .frame(minHeight: Disclosure.row)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Om opptaket")
        .accessibilityHint(showsOrigin ? "Skjuler opplysningene" : "Viser opplysningene")
    }

    private struct Fact {
        let label: String
        let value: String
    }

    /// The origin as label and value, in the order a reader asks: when, what
    /// file, what it was, and the checksum last.
    private func facts(of origin: RecordingOrigin) -> [Fact] {
        let length = Duration.seconds(origin.duration).formatted(.time(pattern: .minuteSecond))
        guard let original = origin.original else {
            return [
                Fact(label: "Tatt opp", value: origin.createdAt.recordingStamp),
                Fact(label: "Lengde", value: length)
            ]
        }
        var facts = [
            Fact(label: "Importert", value: (origin.importedAt ?? origin.createdAt).recordingStamp),
            Fact(label: "Filnavn", value: original.name)
        ]
        if let created = original.createdAt {
            facts.append(Fact(label: "Laget", value: created.recordingStamp))
        }
        facts.append(Fact(label: "Format", value: Self.format(of: original)))
        facts.append(Fact(label: "Størrelse", value: Int64(original.byteCount).formatted(.byteCount(style: .file).locale(AppLocale.norwegian))))
        facts.append(Fact(label: "Lengde", value: length))
        for key in original.tags.keys.sorted() {
            guard let value = original.tags[key] else { continue }
            facts.append(Fact(label: Self.tagLabel(key), value: value))
        }
        facts.append(Fact(label: "SHA-256", value: original.sha256))
        return facts
    }

    /// «MP3, 44,1 kHz, stereo».
    nonisolated static func format(of original: RecordingOrigin.OriginalFile) -> String {
        let rate = (original.sampleRate / 1_000).formatted(.number.precision(.fractionLength(0...1)).locale(AppLocale.norwegian))
        let channels = switch original.channels {
        case 1: "mono"
        case 2: "stereo"
        default: "\(original.channels) kanaler"
        }
        return "\(original.format), \(rate) kHz, \(channels)"
    }

    /// The common metadata keys a recorder or an editor writes, in Norwegian.
    /// Anything else keeps the key the file used.
    private static func tagLabel(_ key: String) -> String {
        switch key {
        case "title": "Tittel i filen"
        case "artist": "Artist"
        case "author": "Forfatter"
        case "creator": "Opphav"
        case "album": "Album"
        case "description": "Beskrivelse"
        case "subject": "Emne"
        case "publisher": "Utgiver"
        case "software": "Programvare"
        case "make": "Produsent"
        case "model": "Modell"
        case "location": "Sted"
        case "copyrights": "Opphavsrett"
        case "language": "Språk"
        default: key
        }
    }
}
