import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct RecordingListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    @State private var controller = RecordingController.shared
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var showImporter = false
    /// True while picked files are converted. The row appears when a file is
    /// done; until then the button is what shows that something is happening.
    @State private var isImporting = false
    @State private var path: [Recording] = []
    /// The one row that is swiped open or asking, if any. One at a time: a
    /// swipe on another row closes this one.
    @State private var swipe: Swipe?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private struct Swipe {
        let recording: Recording
        var stage: SwipeStage
        var question: Question = .delete
        let shown = Date()
    }

    /// What a row asks before acting: deleting, or a new text that would drop the names the user gave.
    private enum Question {
        case delete
        case remake
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                header

                if controller.storageFailed {
                    storageWarning
                        .padding(.horizontal, Space.s4)
                        .padding(.bottom, recordings.isEmpty ? 0 : Space.s4)
                }

                if recordings.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    list
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.Frodi.background.ignoresSafeArea())
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                RecorderBar(controller: controller)
            }
            .alert(errorMessage ?? "", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls) where !urls.isEmpty:
                    Task { await importAudio(urls) }
                case .success:
                    break
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            .navigationDestination(for: Recording.self) { recording in
                RecordingDetailView(recording: recording, onRetry: { await transcribe(recording) })
            }
        }
        .task {
            await transcribePending()
        }
    }

    private var header: some View {
        wordmark
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s3)
            // Overlays, not a row: the wordmark should sit in the middle of the screen,
            // not in the middle of the space left beside the buttons.
            .overlay(alignment: .leading) {
                importButton
                    .padding(.leading, Space.s1)
            }
            .overlay(alignment: .trailing) {
                settingsButton
                    .padding(.trailing, Space.s1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.Frodi.border)
                    .frame(height: 1)
            }
    }

    private var wordmark: some View {
        VStack(spacing: Space.s1) {
            Text("fróði")
                .font(.Frodi.display)
                .foregroundStyle(Color.Frodi.textPrimary)

            // The second half of the app name, «fróði røst», not a subtitle. Inter, not Skranji: the display
            // face is hard to read at small sizes, and the eyebrow style is made for this.
            Text("røst")
                .font(.Frodi.eyebrow)
                .eyebrowTracking()
                .foregroundStyle(Color.Frodi.textSecondary)
        }
        .accessibilityElement(children: .combine)
        // The name as spoken, not the wordmark. Lowercase is a graphic form, not
        // how the name is said.
        .accessibilityLabel("Fróði røst")
        .accessibilityAddTraits(.isHeader)
    }

    private var settingsButton: some View {
        IconButton(icon: .settings, size: HeaderButton.icon, label: "Innstillinger") {
            showSettings = true
        }
    }

    /// Brings in audio recorded elsewhere, to have it made into text. Across
    /// from Innstillinger, so the wordmark stays in the middle.
    @ViewBuilder
    private var importButton: some View {
        if isImporting {
            ProgressView()
                .frame(width: HeaderButton.touch, height: HeaderButton.touch)
                .accessibilityLabel("Importerer lydfil")
        } else {
            IconButton(icon: .importAudio, badge: .add, size: HeaderButton.icon, label: "Importer lydfil") {
                showImporter = true
            }
        }
    }

    /// The database could not be opened, so the app runs on memory. The audio stays on disk and
    /// `reconcile` lists it again at launch; names, texts and origins do not survive a restart.
    private var storageWarning: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Navn og tekst blir ikke lagret")
                .font(.Frodi.bodyMedium)
                .foregroundStyle(Color.Frodi.textPrimary)

            Text("Fróði får ikke åpnet databasen. Du kan ta opp og eksportere som vanlig, og lyden blir liggende på enheten. Navn, tekst og «Om opptaket» forsvinner når du lukker appen. Ikke slett appen: Da forsvinner opptakene også. Skriv til hei@tazk.no.")
                .font(.Frodi.caption)
                .foregroundStyle(Color.Frodi.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(
            RoundedRectangle(cornerRadius: Radius.card)
                .fill(Color.Frodi.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card)
                        .strokeBorder(Color.Frodi.recordingActive, lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: Space.s3) {
            Text("Ingen opptak ennå")
                .font(.Frodi.title)
                .foregroundStyle(Color.Frodi.textPrimary)

            Text("Trykk på opptaksknappen nederst. Brukerveiledningen under Innstillinger viser hvordan du tar opp med handlingsknappen.")
                .font(.Frodi.caption)
                .foregroundStyle(Color.Frodi.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(Space.s8)
        .frame(maxWidth: 360)
        .background(
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.Frodi.border, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
        .padding(Space.s6)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: Space.s3) {
                ForEach(recordings) { recording in
                    row(recording)
                }
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s3)
        }
        .scrollContentBackground(.hidden)
    }

    /// One recording; the text action that applies and «Slett» sit behind a swipe left. Delete asks first, in the row (no undo, text goes too).
    /// VoiceOver has no swipe, so they are custom actions too. Opens from a tap gesture, not a `NavigationLink`:
    /// a button counts a drag ending inside it as a tap, so the swipe would open the recording.
    private func row(_ recording: Recording) -> some View {
        SwipeRow(stage: stage(of: recording), onStage: { setStage($0, of: recording) }) {
            RecordingRow(recording: recording)
                .contentShape(Rectangle())
                .onTapGesture { path.append(recording) }
                .accessibilityAddTraits(.isButton)
                .accessibilityActions {
                    if let action = textAction(for: recording) {
                        Button(action.label) { action.run() }
                    }
                    Button("Slett") { ask(.delete, of: recording) }
                }
        } actions: {
            if let action = textAction(for: recording) {
                Button { action.run() } label: {
                    Text(verbatim: action.label).choiceRow(inline: true)
                }
            }
            Button { ask(.delete, of: recording) } label: {
                Text("Slett").choiceRow(destructive: true, inline: true)
            }
        } question: {
            if swipe?.question == .remake {
                // The question has a line of its own; the two answers are too wide beside it.
                VStack(alignment: .trailing, spacing: Space.s2) {
                    questionText("Vil du lage ny tekst? Navnene du har gitt, forsvinner.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: Space.s2) {
                        Button { if settled() { makeText(recording) } } label: {
                            answer("Lag ny tekst", among: ["Lag ny tekst", "Behold"]).choiceRow(inline: true)
                        }
                        Button { if settled() { setStage(.closed, of: recording) } } label: {
                            answer("Behold", among: ["Lag ny tekst", "Behold"]).choiceRow(inline: true)
                        }
                    }
                }
            } else {
                questionText("Vil du slette opptaket?")

                Spacer(minLength: Space.s2)

                // «Slett» stands where the text action stood and «Behold» where
                // «Slett» did, so a second tap in the same place keeps the recording.
                Button { if settled() { delete(recording) } } label: {
                    answer("Slett", among: ["Slett", "Behold"]).choiceRow(destructive: true, inline: true)
                }
                Button { if settled() { setStage(.closed, of: recording) } } label: {
                    answer("Behold", among: ["Slett", "Behold"]).choiceRow(inline: true)
                }
            }
        }
    }

    private func questionText(_ question: LocalizedStringKey) -> some View {
        Text(question)
            .font(.Frodi.bodyMedium)
            .foregroundStyle(Color.Frodi.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            // Where the row's title stood.
            .padding(.leading, Space.s3)
            .accessibilityAddTraits(.isHeader)
    }

    /// The two answers in one size: each is laid out over both words, so
    /// the wider one sets the width of both at every text size.
    private func answer(_ word: String, among words: [String]) -> some View {
        ZStack {
            ForEach(words, id: \.self) { Text(verbatim: $0).hidden() }
            Text(verbatim: word)
        }
        // One line each, so both keep one size; at the accessibility sizes they wrap rather than leave the screen.
        .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: false)
    }

    private func stage(of recording: Recording) -> SwipeStage {
        guard let swipe, swipe.recording === recording else { return .closed }
        return swipe.stage
    }

    private func setStage(_ stage: SwipeStage, of recording: Recording) {
        swipe = stage == .closed ? nil : Swipe(recording: recording, stage: stage)
    }

    private func ask(_ question: Question, of recording: Recording) {
        swipe = Swipe(recording: recording, stage: .asking, question: question)
    }

    /// Answers count half a second after the question appears, so a double tap on the action that asked confirms
    /// nothing, wherever the answers land.
    private func settled() -> Bool {
        swipe.map { Date().timeIntervalSince($0.shown) > 0.5 } ?? true
    }

    /// The one text action a recording can take, or none while it transcribes: «Lag tekst» for a long recording waiting
    /// to be asked, «Prøv på nytt» after a failure, «Lag ny tekst» for a word list written after the interview.
    private func textAction(for recording: Recording) -> (label: String, run: () -> Void)? {
        guard !recording.isTranscribing else { return nil }
        let label = if recording.hasTranscript {
            "Lag ny tekst"
        } else if Transcription.awaitsRequest(recording) {
            "Lag tekst"
        } else {
            "Prøv på nytt"
        }
        return (label, {
            if let text = try? recording.transcript(), Transcript.hasGivenNames(in: text) {
                ask(.remake, of: recording)
            } else {
                makeText(recording)
            }
        })
    }

    private func makeText(_ recording: Recording) {
        setStage(.closed, of: recording)
        if recording.hasTranscript {
            recording.sealedTranscript = nil
            try? context.save()
        }
        Task { await transcribe(recording) }
    }

    /// Transcribes everything that is waiting. Called at launch, so a recording
    /// whose transcription was cut short goes on from where it was.
    private func transcribePending() async {
        await Transcription.runPending(context: context)
    }

    /// Failed files are counted, not named: the message can show in the app switcher's picture, and a file name can say
    /// who was interviewed. Imported ones are listed under their own names. A file that is not readable audio gets the
    /// reason; anything else gets another try.
    private func importAudio(_ urls: [URL]) async {
        isImporting = true
        let failed = await controller.importAudio(urls)
        isImporting = false
        guard !failed.isEmpty else { return }
        let unreadable = failed.allSatisfy { $0 == .unreadable }
        errorMessage = switch (urls.count == 1, unreadable) {
        case (true, true):
            String(localized: "Fróði får ikke lest filen. Den kan være skadet eller i et format Fróði ikke kan lese.")
        case (true, false):
            String(localized: "Fróði fikk ikke importert filen. Prøv på nytt.")
        case (false, true):
            String(localized: "Fróði får ikke lest \(failed.count) av \(urls.count) filer. De kan være skadet eller i et format Fróði ikke kan lese.")
        case (false, false):
            String(localized: "Fróði fikk ikke importert \(failed.count) av \(urls.count) filer. Prøv på nytt.")
        }
    }

    private func transcribe(_ recording: Recording) async {
        await Transcription.run(for: recording, context: context, requested: true)
        if recording.transcriptionFailed {
            errorMessage = TranscriptionError.explanation(for: recording.failureCode)
        }
    }

    private func delete(_ recording: Recording) {
        // The row goes first: it is drawn from this recording, and must not be
        // redrawn from an object that is gone.
        swipe = nil
        AudioStorage.delete(fileName: recording.fileName)
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
            context.delete(recording)
        }
        try? context.save()
    }
}
