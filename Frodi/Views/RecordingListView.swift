import SwiftData
import SwiftUI

struct RecordingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    @State private var controller = RecordingController.shared
    @State private var speechModel = SpeechModel()
    @State private var errorMessage: String?
    @State private var showInfo = false
    @State private var pendingDeletion: Recording?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                if controller.storageFailed {
                    storageWarning
                        .padding(.horizontal, Space.s4)
                        .padding(.bottom, recordings.isEmpty ? 0 : Space.s4)
                }

                if !Transcription.usesBundledModel {
                    SpeechModelBanner(model: speechModel)
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
                Button("Greit") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "").font(.Frodi.body)
            }
            .sheet(isPresented: $showInfo) {
                InfoView()
            }
        }
        .task {
            // With nb-whisper in the build there is no system model to wait for.
            if !Transcription.usesBundledModel { await speechModel.refresh() }
            // Recordings that were waiting for the model get their text now.
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
                aboutButton
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

    private var aboutButton: some View {
        Button {
            showInfo = true
        } label: {
            IconView(.information, size: HeaderButton.icon)
                .foregroundStyle(Color.Frodi.textSecondary)
                .frame(width: HeaderButton.touch, height: HeaderButton.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Info om appen")
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

            Text("Fróði får ikke åpnet databasen på enheten. Du kan ta opp og hente ut som vanlig, men alt forsvinner når du lukker appen. Installer appen på nytt for å rette feilen.")
                .font(.Frodi.caption)
                .foregroundStyle(Color.Frodi.textSecondary)
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

            Text("Trykk på opptaksknappen, eller hold inne handlingsknappen på venstre side. Trykk på Info-knappen for veiledning.")
                .font(.Frodi.caption)
                .foregroundStyle(Color.Frodi.textSecondary)
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
                    NavigationLink {
                        RecordingDetailView(recording: recording, onRetry: { await transcribe(recording) })
                    } label: {
                        RecordingRow(recording: recording)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if !recording.hasTranscript, !recording.isTranscribing {
                            Button(Transcription.awaitsRequest(recording) ? "Lag tekst" : "Prøv teksten på nytt") {
                                Task { await transcribe(recording) }
                            }
                        }
                        // For a word list written after the interview. The audio is
                        // the same, so nothing is lost that the new run does not remake.
                        if recording.hasTranscript, !recording.isTranscribing {
                            Button("Lag teksten på nytt") {
                                recording.sealedTranscript = nil
                                try? context.save()
                                Task { await transcribe(recording) }
                            }
                        }
                        Button("Slett", role: .destructive) { pendingDeletion = recording }
                    }
                }
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s3)
        }
        .scrollContentBackground(.hidden)
        // One tap in a context menu is one tap too few for something that cannot be
        // undone. The recording and its text go together, and nothing brings them back.
        .confirmationDialog(
            "Slett opptaket?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { recording in
            Button("Slett", role: .destructive) { delete(recording) }
            Button("Avbryt", role: .cancel) {}
        } message: { _ in
            Text("Opptaket og teksten blir borte fra enheten. Du kan ikke angre.")
        }
    }

    /// Transcribes everything that is waiting. Called at launch, so recordings made
    /// before the speech model was in place are not left without text. Without a
    /// model there is nothing to run, and running would only mark them failed.
    private func transcribePending() async {
        guard Transcription.usesBundledModel || speechModel.isReady else { return }
        await Transcription.runPending(context: context)
    }

    private func transcribe(_ recording: Recording) async {
        await Transcription.run(for: recording, context: context, requested: true)
        if recording.transcriptionFailed {
            errorMessage = TranscriptionError.explanation(for: recording.failureCode)
        }
    }

    private func delete(_ recording: Recording) {
        AudioStorage.delete(fileName: recording.fileName)
        context.delete(recording)
        try? context.save()
    }
}
