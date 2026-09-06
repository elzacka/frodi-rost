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
            Group {
                if recordings.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Fróði")
            .safeAreaInset(edge: .bottom) {
                RecorderBar(recorder: recorder, onStop: save)
            }
            .alert("Noe gikk galt", isPresented: .constant(errorMessage != nil)) {
                Button("Greit") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task(id: launchRequest.shouldStartRecording) {
            guard launchRequest.shouldStartRecording else { return }
            launchRequest.shouldStartRecording = false
            await recorder.start()
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Ingen opptak ennå", systemImage: "waveform")
        } description: {
            Text("Trykk på knappen under for å ta opp. Du kan også legge Fróði på handlingsknappen.")
        }
    }

    private var list: some View {
        List {
            ForEach(recordings) { recording in
                NavigationLink {
                    RecordingDetailView(recording: recording)
                } label: {
                    RecordingRow(recording: recording)
                }
            }
            .onDelete(perform: delete)
        }
        .listStyle(.plain)
    }

    private func save(fileName: String, duration: TimeInterval) {
        let recording = Recording(duration: duration, fileName: fileName)
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

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let recording = recordings[index]
            AudioStorage.delete(fileName: recording.fileName)
            context.delete(recording)
        }
        try? context.save()
    }
}
