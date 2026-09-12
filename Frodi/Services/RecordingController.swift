import Foundation
import Observation
import SwiftData
import UIKit

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

        // Plaintext a crash left in the temporary folder. Nothing is running at
        // launch, so all of it is leftovers.
        AudioStorage.clearScratch()

        // A recording stopped while the device was locked is still plaintext. It is
        // sealed as soon as the device is unlocked, and at launch if it already is.
        NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.sealPending() }
        }
        Task { await sealPending() }
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

        guard let container else { return }
        let context = container.mainContext
        context.insert(recording)
        try? context.save()

        // The first save creates the database's -wal and -shm files. At launch they
        // did not exist yet, so the backup flag set then landed on nothing.
        AudioStorage.excludeFromBackup(store: container)

        // Sealed and turned into text afterwards. If that fails, the reason is
        // stored on the recording.
        Task { await Transcription.run(for: recording, context: context) }
    }

    /// Seals, and then transcribes, every recording that is still plaintext.
    ///
    /// `Transcription.run` does the sealing, so a recording sealed here gets its
    /// text in the same pass, and the list's own pass at launch cannot collide
    /// with this one. The check on protected data is what makes the launch case
    /// safe: an App Intent can launch the app in the background with the device
    /// locked, and the attempt would fail anyway.
    func sealPending() async {
        guard UIApplication.shared.isProtectedDataAvailable,
              let context = container?.mainContext else { return }

        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        for recording in recordings where !AudioStorage.isSealed(recording.fileName) {
            await Transcription.run(for: recording, context: context)
        }
    }
}
