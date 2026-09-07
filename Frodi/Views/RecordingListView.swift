import SwiftData
import SwiftUI

struct RecordingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    @State private var controller = RecordingController.shared
    @State private var speechModel = SpeechModel()
    @State private var errorMessage: String?

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
        }
        .task {
            // Med nb-whisper i bygget finnes ingen systemmodell å vente på.
            if !Transcription.usesBundledModel { await speechModel.refresh() }
            // Opptak som ventet på modellen får teksten sin nå.
            await transcribePending()
        }
    }

    private var header: some View {
        VStack(spacing: Space.s1) {
            Text("fróði")
                .font(.Frodi.display)
                .foregroundStyle(Color.Frodi.textPrimary)

            // TTT for tale til tekst. Inter, ikke Skranji: pyntefonten er tung
            // å lese i småformat, og eyebrow-stilen er laget for nettopp dette.
            Text("TTT")
                .font(.Frodi.eyebrow)
                .eyebrowTracking()
                .foregroundStyle(Color.Frodi.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.s4)
        .padding(.top, Space.s2)
        .padding(.bottom, Space.s3)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.Frodi.border)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fróði, tale til tekst")
        .accessibilityAddTraits(.isHeader)
    }

    /// Databasen lot seg ikke åpne, så appen kjører på minnet.
    ///
    /// Uten denne beskjeden ville opptakene forsvunnet ved omstart uten at noe
    /// tydet på hvorfor. En stille feil er verre enn en synlig.
    private var storageWarning: some View {
        VStack(alignment: .leading, spacing: Space.s2) {
            Text("Opptakene lagres ikke")
                .font(.Frodi.bodyMedium)
                .foregroundStyle(Color.Frodi.textPrimary)

            Text("Fróði får ikke åpnet databasen på telefonen. Du kan ta opp og hente ut som vanlig, men alt forsvinner når du lukker appen. Installer appen på nytt for å rette det.")
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

            Text("Trykk på mikrofonen, eller bruk handlingsknappen når du er på farten.")
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
                        if !recording.hasTranscript {
                            Button("Prøv teksten på nytt") {
                                Task { await transcribe(recording) }
                            }
                        }
                        Button("Slett", role: .destructive) { delete(recording) }
                    }
                }
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s2)
            .padding(.bottom, Space.s3)
        }
        .scrollContentBackground(.hidden)
    }

    /// Transkriberer alt som mangler tekst. Kalles ved oppstart, slik at opptak
    /// tatt før språkmodellen var på plass ikke blir stående uten tekst.
    private func transcribePending() async {
        guard Transcription.usesBundledModel || speechModel.isReady else { return }
        for recording in recordings where !recording.hasTranscript {
            await transcribe(recording, surfaceErrors: false)
        }
    }

    private func transcribe(_ recording: Recording, surfaceErrors: Bool = true) async {
        await Transcription.run(for: recording, context: context)
        if surfaceErrors, recording.transcriptionFailed {
            errorMessage = TranscriptionError.explanation(for: recording.failureCode)
        }
    }

    private func delete(_ recording: Recording) {
        AudioStorage.delete(fileName: recording.fileName)
        context.delete(recording)
        try? context.save()
    }
}
