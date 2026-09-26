import Foundation
import SwiftData
import UIKit

/// One place that turns recordings into text, so the interface and the Action
/// Button handle errors the same way.
///
/// The engine is nb-whisper, bundled and run by WhisperKit, so everything
/// happens inside the app's own container. There is no other engine.
enum Transcription {
    /// Kept alive between recordings. The model takes several seconds to load.
    @MainActor
    private static let whisper = WhisperTranscriber()

    /// Up to this length a recording is transcribed as soon as it is stopped. A
    /// longer one waits until the user asks: an hour of interview is minutes at
    /// full load, and the next interview needs that battery. The app decides by
    /// length; the user decides when. `TranscriptProgress.begin` is how the asking
    /// is remembered.
    static let immediateLimit: TimeInterval = 10 * 60

    /// The same number as BRUKERVEILEDNING.md states it; `DocumentTests` holds
    /// the two together.
    static var immediateMinutes: Int { Int(immediateLimit / 60) }

    /// Recordings being worked on right now.
    ///
    /// Launch and unlock each start a pass over the pending recordings, and the
    /// list starts its own at launch. Whichever reaches a recording first does the
    /// work; the others skip it. The flag on the recording cannot serve here: it is
    /// saved to disk and would be stale after a crash.
    @MainActor
    private static var inFlight: Set<PersistentIdentifier> = []

    /// One transcription at a time. The passes at launch, unlock and activation
    /// can reach different recordings at once; two runs would each find no model
    /// and load it, about a gigabyte apiece, and clear each other's word list.
    /// The turn is taken before the plaintext copy is written, so a run that
    /// waits holds no copy it may be unable to reopen once the device locks.
    @MainActor
    private static var running = false
    @MainActor
    private static var waiting: [CheckedContinuation<Void, Never>] = []

    @MainActor
    private static func takeTurn() async {
        guard running else { running = true; return }
        await withCheckedContinuation { waiting.append($0) }
    }

    @MainActor
    private static func endTurn() {
        if waiting.isEmpty { running = false } else { waiting.removeFirst().resume() }
    }

    /// Seals the recording, and transcribes it if it is short, was asked for, or
    /// `requested` says so now.
    ///
    /// The transcription goes piece by piece and writes its progress after each,
    /// so a run cut short by a suspension, a crash or a new recording goes on from
    /// where it was. It stops by itself when a recording starts: the microphone
    /// must not compete with the model for the device.
    ///
    /// Nothing here can succeed on a locked device: the plaintext to seal is
    /// closed `.completeUnlessOpen`, the sealed audio is `.complete`, and the key
    /// is `WhenUnlocked`. A stop from the Action Button on a locked device reaches
    /// this through `stopAndSave`; the work waits for the unlock pass, and nothing
    /// is marked failed, because nothing has.
    @MainActor
    static func run(for recording: Recording, context: ModelContext, requested: Bool = false) async {
        guard UIApplication.shared.isProtectedDataAvailable else { return }
        let id = recording.persistentModelID
        guard inFlight.insert(id).inserted else { return }
        defer { inFlight.remove(id) }

        // Sealing comes first. If it fails, the recording waits for the next unlock
        // or launch, and nothing is marked failed. See `AudioStorage.seal`.
        if !AudioStorage.isSealed(recording.fileName) {
            do {
                recording.fileName = try await AudioStorage.seal(fileName: recording.fileName)
                try? context.save()
            } catch {
                // Whether the device was locked is what tells the expected deferral
                // from a failure that needs looking into.
                let unlocked = UIApplication.shared.isProtectedDataAvailable
                AudioRecorder.log.notice("Seal of \(recording.fileName, privacy: .public) deferred, protected data available: \(unlocked, privacy: .public): \(error, privacy: .public)")
                return
            }
        }

        let fileName = recording.fileName
        var progress = TranscriptProgress.load(for: fileName)
        if progress == nil, requested {
            TranscriptProgress.begin(for: fileName)
            progress = TranscriptProgress()
        }
        guard var progress = progress ?? (recording.duration <= immediateLimit ? TranscriptProgress() : nil) else {
            return
        }

        await takeTurn()
        defer { endTurn() }
        // The wait can be long. The device may have locked, or a recording
        // started, meanwhile; either way the run waits for the next pass, and
        // nothing is marked failed.
        guard UIApplication.shared.isProtectedDataAvailable,
              !RecordingController.shared.isRecording else { return }

        recording.isTranscribing = true
        try? context.save()
        TranscriptionState.shared.began(id, fraction: fraction(progress.position, of: recording.duration))
        defer { TranscriptionState.shared.ended(id) }

        do {
            let finished = try await AudioStorage.withDecrypted(fileName: fileName) { url in
                // A row made by `reconcile` for a sealed orphan does not know its length
                // until the file is open.
                if recording.duration == 0, let duration = try? WhisperTranscriber.duration(of: url) {
                    recording.duration = duration
                }
                let duration = recording.duration

                let entries = WordList.entries(in: WordList.load())
                try await transcriber().transcribe(fileURL: url, from: progress.position) { paragraphs, position in
                    // The listed names, spelled as listed, where the model nearly did.
                    progress.paragraphs.append(contentsOf: paragraphs.map { paragraph in
                        var corrected = paragraph
                        corrected.text = WordList.correct(paragraph.text, entries: entries)
                        return corrected
                    })
                    progress.position = position
                    progress.save(for: fileName)
                    TranscriptionState.shared.update(id, fraction: fraction(position, of: duration))
                    return !RecordingController.shared.isRecording
                }
                return progress.position >= duration - 0.5
            }

            if finished {
                let text = Transcript.compose(progress.paragraphs)
                guard !text.isEmpty else { throw TranscriptionError.empty }
                try recording.setTranscript(text)
                recording.transcriptionFailed = false
                recording.failureCode = nil
                TranscriptProgress.clear(for: fileName)
            }
        } catch let error as TranscriptionError {
            recording.transcriptionFailed = true
            recording.failureCode = error.code
            if error.code == "empty" { TranscriptProgress.clear(for: fileName) }
        } catch {
            recording.transcriptionFailed = true
            recording.failureCode = "other"
        }
        recording.isTranscribing = false
        try? context.save()
    }

    /// Everything that is waiting: plaintext to seal, short recordings without
    /// text, and long ones the user has asked for. Called at launch, on unlock,
    /// and after a recording stops, which is when a paused transcription can go on.
    ///
    /// A recording the model already found no speech in is left alone. The same
    /// audio gives the same answer, and a whisper run per silent recording at
    /// every launch adds up. «Prøv på nytt» behind the row still works.
    @MainActor
    static func runPending(context: ModelContext) async {
        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        for recording in recordings where !recording.hasTranscript && recording.failureCode != "empty" {
            await run(for: recording, context: context)
        }
    }

    /// Whether a recording is waiting for the user to ask for its text.
    static func awaitsRequest(_ recording: Recording) -> Bool {
        !recording.hasTranscript
            && !recording.transcriptionFailed
            && recording.duration > immediateLimit
            && !TranscriptProgress.exists(for: recording.fileName)
    }

    private static func fraction(_ position: TimeInterval, of duration: TimeInterval) -> Double {
        duration > 0 ? min(position / duration, 1) : 0
    }

    @MainActor
    private static func transcriber() -> any Transcriber { whisper }
}

/// What the interface can see of a transcription in progress.
///
/// While one runs, the screen is kept awake, so a device left on the table
/// keeps working: about four minutes for an hour of interview.
@MainActor
@Observable
final class TranscriptionState {
    static let shared = TranscriptionState()

    /// How far each running transcription has got, 0 to 1.
    private(set) var fraction: [PersistentIdentifier: Double] = [:]

    fileprivate func began(_ id: PersistentIdentifier, fraction: Double) {
        self.fraction[id] = fraction
        UIApplication.shared.isIdleTimerDisabled = true
    }

    fileprivate func update(_ id: PersistentIdentifier, fraction: Double) {
        self.fraction[id] = fraction
    }

    fileprivate func ended(_ id: PersistentIdentifier) {
        fraction[id] = nil
        if fraction.isEmpty { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
