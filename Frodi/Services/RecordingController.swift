import Foundation
import Observation
import SwiftData

/// Owns the recording, and is what both the interface and the Action Button talk to.
///
/// It has to be shared because an App Intent runs without access to SwiftUI. Had
/// the recorder lived in a view, the Action Button could not stop a recording
/// already in progress.
@MainActor
@Observable
final class RecordingController {
    static let shared = RecordingController()

    private(set) var recorder = AudioRecorder()

    /// Set when the database could not be opened. Recordings are then kept in memory only.
    private(set) var storageFailed = false

    private var container: ModelContainer?

    private init() {
        // The recorder keeps its own count and reports when the limit is reached.
        // Saving is the same as when you press stop.
        recorder.onLimitReached = { [weak self] in self?.stopAndSave() }
    }

    var isRecording: Bool { recorder.isRecording }

    func attach(container: ModelContainer, storageFailed: Bool) {
        self.container = container
        self.storageFailed = storageFailed
    }

    /// Starts if idle, stops if running. This is what the Action Button calls.
    /// Returns true if a recording is now in progress.
    @discardableResult
    func toggle() async -> Bool {
        if recorder.isRecording {
            stopAndSave()
            return false
        }
        AudioPlayer.shared.stop()
        return await recorder.start()
    }

    /// Starts recording. Returns false if the microphone could not be taken into use.
    /// The Action Button uses the answer to decide whether it has to open the app.
    @discardableResult
    func start() async -> Bool {
        guard !recorder.isRecording else { return true }
        // Playback and recording share the audio session. If we are playing when the
        // recording starts, the microphone picks up the speaker.
        AudioPlayer.shared.stop()
        return await recorder.start()
    }

    func stopAndSave() {
        guard let result = recorder.stop() else { return }

        let recording = Recording(duration: result.duration, fileName: result.fileName)

        guard let context = container?.mainContext else { return }
        context.insert(recording)
        try? context.save()

        // The text is made afterwards. If that fails, the reason is stored on the recording.
        Task { await Transcription.run(for: recording, context: context) }
    }
}
