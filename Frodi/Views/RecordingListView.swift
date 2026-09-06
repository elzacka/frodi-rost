import SwiftData
import SwiftUI

struct RecordingListView: View {
    @Environment(\.modelContext) private var context
    @Environment(LaunchRequest.self) private var launchRequest
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    @State private var recorder = AudioRecorder()
    @State private var speechModel = SpeechModel()
    @State private var errorMessage: String?

    /// Husker at neste opptak kom fra handlingsknappen, slik at raden kan si det.
    @State private var startedWithActionButton = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Frodi.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    SpeechModelBanner(model: speechModel)
                        .padding(.horizontal, Space.s4)
                        .padding(.bottom, recordings.isEmpty ? 0 : Space.s4)

                    if recordings.isEmpty {
                        Spacer()
                        emptyState
                        Spacer()
                    } else {
                        list
                    }
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                RecorderBar(recorder: recorder, onStop: save)
            }
            .alert("Noe gikk galt", isPresented: .constant(errorMessage != nil)) {
                Button("Greit") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "").font(.Frodi.body)
            }
        }
        .task {
            await speechModel.refresh()
            // Opptak som ventet på modellen får teksten sin nå.
            await transcribePending()
        }
        .task(id: launchRequest.shouldStartRecording) {
            guard launchRequest.shouldStartRecording else { return }
            launchRequest.shouldStartRecording = false
            startedWithActionButton = true
            await recorder.start()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.s1) {
            Text("DIKTAFON")
                .font(.Frodi.eyebrow)
                .eyebrowTracking()
                .foregroundStyle(Color.Frodi.textSecondary)

            Text("Fróði")
                .font(.Frodi.display)
                .foregroundStyle(Color.Frodi.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.s5)
        .padding(.top, Space.s3)
        .padding(.bottom, Space.s5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fróði, diktafon")
        .accessibilityAddTraits(.isHeader)
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
        }
        .scrollContentBackground(.hidden)
    }

    private func save(fileName: String, duration: TimeInterval) {
        let recording = Recording(duration: duration, fileName: fileName)
        recording.startedWithActionButton = startedWithActionButton
        startedWithActionButton = false
        context.insert(recording)
        try? context.save()

        Task { await transcribe(recording) }
    }

    /// Transkriberer alt som mangler tekst. Kalles ved oppstart, slik at opptak
    /// tatt før språkmodellen var på plass ikke blir stående uten tekst.
    private func transcribePending() async {
        guard speechModel.isReady else { return }
        for recording in recordings where !recording.hasTranscript {
            await transcribe(recording, surfaceErrors: false)
        }
    }

    private func transcribe(_ recording: Recording, surfaceErrors: Bool = true) async {
        // Uten modell er det ingen vits i å prøve. Banneret sier allerede fra.
        guard speechModel.isReady else {
            recording.transcriptionFailed = true
            try? context.save()
            return
        }

        recording.transcriptionFailed = false
        do {
            let text = try await SystemTranscriber(locale: speechModel.locale)
                .transcribe(fileURL: recording.fileURL)
            recording.transcript = text
        } catch {
            recording.transcriptionFailed = true
            if surfaceErrors { errorMessage = error.localizedDescription }
        }
        try? context.save()
    }

    private func delete(_ recording: Recording) {
        AudioStorage.delete(fileName: recording.fileName)
        context.delete(recording)
        try? context.save()
    }
}
