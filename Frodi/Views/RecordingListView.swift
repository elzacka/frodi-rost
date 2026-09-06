import SwiftData
import SwiftUI

struct RecordingListView: View {
    @Environment(\.modelContext) private var context
    @Environment(LaunchRequest.self) private var launchRequest
    @Query(sort: \Recording.createdAt, order: .reverse) private var recordings: [Recording]

    @State private var recorder = AudioRecorder()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Frodi.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

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
        .task(id: launchRequest.shouldStartRecording) {
            guard launchRequest.shouldStartRecording else { return }
            launchRequest.shouldStartRecording = false
            startedWithActionButton = true
            await recorder.start()
        }
    }

    /// Husker at dette opptaket kom fra handlingsknappen, slik at raden kan si det.
    @State private var startedWithActionButton = false

    /// Logohodet. Navnet settes i Fraunces, ikke i systemfonten, fordi det er
    /// appens eneste merkevareelement.
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
                        RecordingDetailView(recording: recording)
                    } label: {
                        RecordingRow(recording: recording)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Slett", role: .destructive) { delete(recording) }
                    }
                }
            }
            .padding(.horizontal, Space.s4)
            .padding(.top, Space.s4)
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

    private func transcribe(_ recording: Recording) async {
        do {
            let text = try await AppleTranscriber().transcribe(fileURL: recording.fileURL)
            recording.transcript = text
            recording.transcriptionFailed = false
        } catch {
            recording.transcriptionFailed = true
            errorMessage = error.localizedDescription
        }
        try? context.save()
    }

    private func delete(_ recording: Recording) {
        AudioStorage.delete(fileName: recording.fileName)
        context.delete(recording)
        try? context.save()
    }
}
