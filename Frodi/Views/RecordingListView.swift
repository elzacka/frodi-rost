import SwiftData
import SwiftUI

struct RecordingListView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    @State private var controller = RecordingController.shared
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var path: [Recording] = []
    /// The one row that is swiped open or asking, if any. One at a time: a
    /// swipe on another row closes this one.
    @State private var swipe: Swipe?

    private struct Swipe {
        let recording: Recording
        var stage: SwipeStage
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
            .alert("Noe gikk galt", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(verbatim: errorMessage ?? "").font(.Frodi.body)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
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
            // An overlay, not a row: the wordmark should sit in the middle of the screen,
            // not in the middle of the space left beside the info button.
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

            // The second half of the app name, not a subtitle. Inter, not Skranji: the
            // display face is hard to read at small sizes, and the eyebrow style is made
            // for this. Together the header reads «fróði røst», which is the name of the
            // app.
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

    /// The database could not be opened, so the app runs on memory.
    ///
    /// Without this message the recordings would vanish on restart with nothing to
    /// say why. A silent failure is worse than a visible one.
    private var storageWarning: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Opptakene lagres ikke")
                .font(.Frodi.bodyMedium)
                .foregroundStyle(Color.Frodi.textPrimary)

            Text("Fróði får ikke åpnet databasen på enheten. Du kan ta opp og eksportere som vanlig, men alt forsvinner når du lukker appen. Installer appen på nytt.")
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

            Text("Trykk på opptaksknappen, eller hold inne handlingsknappen på venstre side. Brukerveiledningen ligger under Innstillinger.")
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

    /// One recording, with what can be done to it behind a swipe to the left:
    /// the text action that applies, and «Slett». Deleting asks first, in the
    /// row: one tap is one tap too few for something that cannot be undone,
    /// and the recording and its text go together.
    ///
    /// VoiceOver has no swipe, so the same actions hang on the row as custom
    /// actions.
    ///
    /// The row opens the recording from a tap gesture, not from a
    /// `NavigationLink`: a button counts a drag that ends inside it as a tap,
    /// so the swipe would open the recording instead of the actions.
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
                    Button("Slett") { setStage(.asking, of: recording) }
                }
        } actions: {
            if let action = textAction(for: recording) {
                Button { action.run() } label: {
                    Text(verbatim: action.label).choiceRow(inline: true)
                }
            }
            Button { setStage(.asking, of: recording) } label: {
                Text("Slett").choiceRow(destructive: true, inline: true)
            }
        } question: {
            Text("Sikker på at du vil slette?")
                .font(.Frodi.bodyMedium)
                .foregroundStyle(Color.Frodi.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                // Where the row's title stood.
                .padding(.leading, Space.s3)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Space.s2)

            // «Slett» stands where the text action stood and «Behold» where
            // «Slett» did, so a second tap in the same place keeps the recording.
            Button { delete(recording) } label: {
                answer("Slett").choiceRow(destructive: true, inline: true)
            }
            Button { setStage(.closed, of: recording) } label: {
                answer("Behold").choiceRow(inline: true)
            }
        }
    }

    /// «Slett» and «Behold» in one size: each is laid out over both words, so
    /// the wider one sets the width of both at every text size.
    private func answer(_ word: String) -> some View {
        ZStack {
            Text("Slett").hidden()
            Text("Behold").hidden()
            Text(verbatim: word)
        }
    }

    private func stage(of recording: Recording) -> SwipeStage {
        guard let swipe, swipe.recording === recording else { return .closed }
        return swipe.stage
    }

    private func setStage(_ stage: SwipeStage, of recording: Recording) {
        swipe = stage == .closed ? nil : Swipe(recording: recording, stage: stage)
    }

    /// The one text action a recording can take, or none while it transcribes:
    /// «Lag tekst» for a long recording that waits to be asked, «Prøv på nytt»
    /// after a failure, and «Lag ny tekst» for a word list written after the
    /// interview. The audio is the same, so nothing is lost that the new run
    /// does not remake.
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
            setStage(.closed, of: recording)
            if recording.hasTranscript {
                recording.sealedTranscript = nil
                try? context.save()
            }
            Task { await transcribe(recording) }
        })
    }

    /// Transcribes everything that is waiting. Called at launch, so a recording
    /// whose transcription was cut short goes on from where it was.
    private func transcribePending() async {
        await Transcription.runPending(context: context)
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
