import Foundation
import Observation
import SwiftData
import UIKit

/// Owns the recording; the interface and the Action Button both talk to it.
///
/// Shared because an App Intent runs without SwiftUI: with the recorder in a view, the Action Button could not stop a recording.
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
        // The Live Activity's timer stops while the microphone is held elsewhere.
        recorder.onInterruptionChanged = { [weak self] paused in
            guard let self else { return }
            RecordingActivity.update(elapsed: recorder.duration, isInterrupted: paused)
        }
    }

    var isRecording: Bool { recorder.isRecording }

    func attach(container: ModelContainer, storageFailed: Bool) {
        self.container = container
        self.storageFailed = storageFailed

        // Plaintext a crash left in the temporary folder. Nothing is running at
        // launch, so all of it is leftovers.
        AudioStorage.clearScratch()

        // A Live Activity a crash left behind would say a recording is running.
        RecordingActivity.end()

        // A recording stopped while the device was locked is still plaintext. It is
        // sealed at the unlock if the app is running then, when the app next comes
        // to the front, and at launch.
        NotificationCenter.default.addObserver(
            forName: UIApplication.protectedDataDidBecomeAvailableNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.sealPending() }
        }
        // iOS does not queue the unlock notification for a suspended app («Processing queued notifications» omits protected data)
        // and a stop on the locked device ends in suspension: the recording waits for next launch. Foreground catches up on all
        // waiting except failures: `sealPending` retries every failed transcription, not worth a model run per foreground.
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.catchUp() }
        }
        Task { await sealPending() }
    }

    /// Seals what is still plaintext, then continues every recording with no text that has not failed (one the device locked on, or
    /// one stopped for a recording). Failed ones wait for launch and «Prøv på nytt». `Transcription.run` returns at once for a long
    /// recording nobody asked about.
    private func catchUp() async {
        guard UIApplication.shared.isProtectedDataAvailable,
              let context = container?.mainContext else { return }

        if hasPlaintextWaiting { reconcile(context) }
        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        for recording in recordings
        where !AudioStorage.isSealed(recording.fileName) || (!recording.hasTranscript && !recording.transcriptionFailed) {
            await Transcription.run(for: recording, context: context)
        }
    }

    /// A finished recording not yet sealed, which is what a stop on the locked
    /// device leaves behind. The file being recorded is not finished.
    private var hasPlaintextWaiting: Bool {
        AudioStorage.storedFileNames().contains { !AudioStorage.isSealed($0) && $0 != recorder.currentFileName }
    }

    /// Starts if idle, stops if running. This is what the record button calls.
    /// Returns true if a recording is now in progress.
    @discardableResult
    func toggle() async -> Bool {
        if recorder.isRecording {
            stopAndSave()
            return false
        }
        return await start()
    }

    /// Starts recording. Returns false if the microphone could not be taken into use.
    @discardableResult
    func start() async -> Bool {
        guard !recorder.isRecording else { return true }
        // Playback and recording share the audio session. If we are playing when the
        // recording starts, the microphone picks up the speaker. Waited for: the
        // player gives the session up, and the recorder must not take it before.
        await AudioPlayer.shared.stop()
        guard await recorder.start() else { return false }
        // Required by `ToggleRecordingIntent` for as long as the recording runs,
        // and the sign on the Lock Screen that it does.
        RecordingActivity.start()
        return true
    }

    func stopAndSave() {
        guard let result = recorder.stop() else { return }
        RecordingActivity.end()

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

    /// Why an import did not happen: the file is not audio Core Audio can read,
    /// or something else went wrong on the way, such as iOS not handing over a
    /// file it holds only in iCloud Drive while the device is offline.
    enum ImportFailure {
        case unreadable, other
    }

    /// Brings audio files in as recordings, one by one; returns why each failure failed.
    /// Converted and sealed in scratch, then moved in with its row in one main-actor step, no suspension: `reconcile` would add a second row.
    /// Never unsealed, never origin-tagged as recorded here. Text as for a stopped recording; over the length limit: «Lag tekst».
    func importAudio(_ urls: [URL]) async -> [ImportFailure] {
        guard let container else { return urls.map { _ in .other } }
        let context = container.mainContext

        var imported: [Recording] = []
        var failed: [ImportFailure] = []
        for url in urls {
            do {
                let converted = try await AudioImport.convert(url)
                // Plaintext and ciphertext in the scratch folder: gone at once if
                // the import stops here, not at the next launch.
                defer { try? FileManager.default.removeItem(at: converted.url) }
                let sealed = try await AudioStorage.sealImport(converted.url)
                defer { try? FileManager.default.removeItem(at: sealed.url) }

                let fileName = sealed.url.lastPathComponent
                let now = Date.now
                let recording = Recording(
                    createdAt: AudioImport.plausibleDate(converted.original.createdAt, now: now) ?? now,
                    duration: converted.duration,
                    fileName: fileName
                )
                // Named after the file, which is how it was known before it came in.
                try recording.setTitle((converted.original.name as NSString).deletingPathExtension)
                try recording.recordOrigin(RecordingOrigin(
                    recordingID: RecordingOrigin.recordingID(for: fileName),
                    source: .imported,
                    createdAt: recording.createdAt,
                    duration: converted.duration,
                    audioSHA256: sealed.audioSHA256,
                    importedAt: now,
                    original: converted.original
                ))
                let target = AudioStorage.directory.appendingPathComponent(fileName)
                try FileManager.default.moveItem(at: sealed.url, to: target)
                AudioStorage.protectFinished(target)
                context.insert(recording)
                try? context.save()
                imported.append(recording)
            } catch {
                // The error, never the file name: a name can say who was interviewed.
                let code = (error as NSError).code
                AudioRecorder.log.error("Import failed: \(String(describing: type(of: error)), privacy: .public) \(code, privacy: .public)")
                failed.append(error is AudioImport.Failure ? .unreadable : .other)
            }
        }
        guard !imported.isEmpty else { return failed }

        AudioStorage.excludeFromBackup(store: container)
        Task {
            for recording in imported {
                await Transcription.run(for: recording, context: context)
            }
        }
        return failed
    }

    /// Seals, then transcribes, everything waiting. `Transcription.run` does the sealing, so one pass sees the text and the launch pass
    /// cannot collide with it. Its protected-data check keeps launch safe: an App Intent can launch the app in the background with the
    /// device locked, where the attempt would fail anyway.
    func sealPending() async {
        guard UIApplication.shared.isProtectedDataAvailable,
              let context = container?.mainContext else { return }

        reconcile(context)
        await Transcription.runPending(context: context)
    }

    /// Reconciles list and disk: repoints a row still named plaintext at its sealed file; a row-less file gets one, dated from the file.
    /// Skips the file being recorded now (no row by design). A plaintext file with no frames (as in `AudioRecorder.stop`) gets no row
    /// and loses its row: the seal cannot encode it (-11800/-12780) and would fail every launch.
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
        // A row's sealed name counts as known too: a seal in another pass writes the sealed file before removing the plaintext and
        // renaming the row, and the sealed file would look like an orphan and get a second row.
        var referenced = Set(recordings.flatMap { [$0.fileName, AudioStorage.sealedName(for: $0.fileName)] })

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
