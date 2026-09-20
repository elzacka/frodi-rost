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
        // An interruption the recording could not come back from. Same save path:
        // whatever reached the disk is the recording.
        recorder.onInterruptionEnded = { [weak self] in self?.stopAndSave() }
    }

    var isRecording: Bool { recorder.isRecording }

    /// The main context, for an intent that transcribes without the interface.
    var mainContext: ModelContext? { container?.mainContext }

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
        await AudioPlayer.shared.stop()
        return await recorder.start()
    }

    /// Starts recording. Returns false if the microphone could not be taken into use.
    /// The Action Button uses the answer to decide whether it has to open the app.
    @discardableResult
    func start() async -> Bool {
        guard !recorder.isRecording else { return true }
        // Playback and recording share the audio session. If we are playing when the
        // recording starts, the microphone picks up the speaker. Waited for: the
        // player gives the session up, and the recorder must not take it before.
        await AudioPlayer.shared.stop()
        return await recorder.start()
    }

    func stopAndSave() {
        guard let result = recorder.stop() else { return }

        let recording = Recording(duration: result.duration, fileName: result.fileName)

        guard let container else {
            AudioRecorder.log.error("No container to save \(result.fileName, privacy: .public); reconcile picks it up at launch")
            return
        }
        let context = container.mainContext
        context.insert(recording)
        try? context.save()

        // The first save creates the database's -wal and -shm files. At launch they
        // did not exist yet, so the backup flag set then landed on nothing.
        AudioStorage.excludeFromBackup(store: container)

        // Sealed and turned into text afterwards. If that fails, the reason is
        // stored on the recording. Then whatever was paused while the microphone
        // was open: a transcription stops itself when a recording starts.
        Task {
            await Transcription.run(for: recording, context: context)
            await Transcription.runPending(context: context)
        }
    }

    /// Seals, and then transcribes, everything that is waiting.
    ///
    /// `Transcription.run` does the sealing, so a recording sealed here gets its
    /// text in the same pass, and the list's own pass at launch cannot collide
    /// with this one. The check on protected data is what makes the launch case
    /// safe: an App Intent can launch the app in the background with the device
    /// locked, and the attempt would fail anyway.
    func sealPending() async {
        guard UIApplication.shared.isProtectedDataAvailable,
              let context = container?.mainContext else { return }

        reconcile(context)
        await Transcription.runPending(context: context)
    }

    /// Makes the list agree with the disk.
    ///
    /// The file is the recording; the row is what the list knows about it. The
    /// two come apart when the app dies between writing one and the other: killed
    /// while recording, before `stopAndSave` ran; a database that fell back to
    /// memory, so the rows vanished at the next launch; a crash inside the seal,
    /// after the plaintext was removed and before the new name was saved. In every
    /// case the audio is intact and nothing was looking for it.
    ///
    /// Two repairs. A sealed file whose row still carries the plaintext name gets
    /// the row pointed at it. A file no row knows gets a row, dated from the file.
    /// The duration of a sealed orphan is unknown until it is opened, and that is
    /// left to the transcription, which opens it anyway.
    ///
    /// The file being recorded right now has no row yet by design, and is skipped:
    /// the unlock pass runs while the car recording is still going.
    ///
    /// A plaintext file that opens and holds no frames is not a recording, the
    /// same rule `AudioRecorder.stop` applies. The recorder creates the file
    /// before `record()` can refuse, and a crash in between leaves it. It gets
    /// no row, and a row it already has goes with it: the seal cannot encode an
    /// empty file, so the row would say «venter på transkribering» for good and
    /// the seal would fail at every launch. Measured on 2026-09-19: an empty
    /// CAF is what gives the export session's -11800 with -12780 underneath.
    func reconcile(_ context: ModelContext) {
        var onDisk = Set(AudioStorage.storedFileNames())
        if let current = recorder.currentFileName { onDisk.remove(current) }

        for fileName in onDisk where !AudioStorage.isSealed(fileName) && AudioStorage.duration(fileName: fileName) == 0 {
            AudioRecorder.log.notice("Empty recording file removed: \(fileName, privacy: .public)")
            AudioStorage.delete(fileName: fileName)
            onDisk.remove(fileName)
            let stale = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
            for recording in stale where recording.fileName == fileName { context.delete(recording) }
        }

        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        var referenced = Set(recordings.map(\.fileName))

        for recording in recordings where !onDisk.contains(recording.fileName) {
            let sealed = AudioStorage.sealedName(for: recording.fileName)
            if onDisk.contains(sealed) {
                recording.fileName = sealed
                referenced.insert(sealed)
            }
        }

        for fileName in onDisk.subtracting(referenced) {
            let recording = Recording(
                createdAt: AudioStorage.creationDate(fileName: fileName) ?? .now,
                duration: AudioStorage.duration(fileName: fileName) ?? 0,
                fileName: fileName
            )
            context.insert(recording)
        }

        try? context.save()
    }
}
