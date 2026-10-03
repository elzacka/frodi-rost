import Foundation
import SwiftData
import UIKit

/// One place that turns recordings into text, so the interface and the Action Button handle errors the same way.
/// The engine is bundled nb-whisper via WhisperKit, all inside the app's container; there is no other engine.
enum Transcription {
    /// Kept alive between recordings. The model takes several seconds to load.
    @MainActor
    private static let whisper = WhisperTranscriber()

    /// Up to this length a recording is transcribed when stopped; a longer one waits until the user asks (an hour of
    /// interview is minutes at full load, and the next interview needs that battery). `TranscriptProgress.begin` remembers the asking.
    static let immediateLimit: TimeInterval = 10 * 60

    /// The same number as BRUKERVEILEDNING.md states it; `DocumentTests` holds
    /// the two together.
    static var immediateMinutes: Int { Int(immediateLimit / 60) }

    /// Recordings being worked on right now. Launch, unlock and the list each start a pass; whichever reaches a
    /// recording first does it, the others skip. The flag on the recording cannot serve: it is saved to disk, stale after a crash.
    @MainActor
    private static var inFlight: Set<PersistentIdentifier> = []

    /// One transcription at a time: passes at launch, unlock and activation can overlap, and two runs would each load the model
    /// (about 1 GB apiece) and clear each other's word list. The turn is taken before the plaintext copy is written,
    /// so a waiting run holds no copy it may be unable to reopen once the device locks.
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

    /// Seals the recording, and transcribes it if short, asked for, or `requested`.
    /// Writes progress after each piece so an interrupted run resumes; stops itself when a recording starts (mic vs model).
    /// Locked device: plaintext `.completeUnlessOpen`, audio `.complete`, key `WhenUnlocked`, so work waits for unlock and nothing is marked failed.
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
                let sealed = try await AudioStorage.seal(fileName: recording.fileName)
                recording.fileName = sealed.name
                // A recording made here gets its origin at the seal. An import is
                // sealed before it has a row and never passes here.
                if let audioSHA256 = sealed.audioSHA256 {
                    try? recording.recordOrigin(RecordingOrigin(
                        recordingID: RecordingOrigin.recordingID(for: recording.fileName),
                        source: .recorded,
                        createdAt: recording.createdAt,
                        duration: recording.duration,
                        audioSHA256: audioSHA256,
                        importedAt: nil,
                        original: nil
                    ))
                }
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
                let speakers = progress.speakers == true
                // The speaker model loads while the text is made, so the pass after the last piece does not wait for it.
                let loading = speakers ? Task { try? await Speakers.load() } : nil
                try await transcriber().transcribe(fileURL: url, from: progress.position, words: speakers) { paragraphs, position in
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
                let done = progress.position >= duration - 0.5
                await loading?.value
                // Who said what. A failure leaves the text without labels, never without text.
                if done, speakers, let turns = try? await Speakers.turns(in: url) {
                    progress.paragraphs = Speakers.label(progress.paragraphs, turns: turns) {
                        WordList.correct($0, entries: entries)
                    }
                }
                return done
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

    /// Everything waiting: plaintext to seal, short recordings without text, long ones the user asked for.
    /// Called at launch, on unlock, after a recording stops. Skips a recording the model found no speech in: same audio, same
    /// answer, and a run per silent one at every launch adds up. «Prøv på nytt» still works.
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
/// The screen is kept awake while one runs, so a device left on the table
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
