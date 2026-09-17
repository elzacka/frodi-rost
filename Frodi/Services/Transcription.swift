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
    private static let whisper = WhisperTranscriber()

    /// Up to this length a recording is transcribed as soon as it is stopped. A
    /// longer one waits until the user asks: an hour of interview takes the device
    /// a long time at full load, and the next interview needs that battery. The
    /// app decides by length; the user decides when. `TranscriptProgress.begin` is
    /// how the asking is remembered.
    static let immediateLimit: TimeInterval = 10 * 60

    /// The same number as the Info page states it. One line to change, and the
    /// sentence follows.
    static var immediateMinutes: Int { Int(immediateLimit / 60) }

    /// Recordings being worked on right now.
    ///
    /// Launch and unlock each start a pass over the pending recordings, and the
    /// list starts its own at launch. Whichever reaches a recording first does the
    /// work; the others skip it. The flag on the recording cannot serve here: it is
    /// saved to disk and would be stale after a crash.
    @MainActor
    private static var inFlight: Set<PersistentIdentifier> = []

    /// Set when iOS ends a background run. The run stops at the next piece; what
    /// is done is saved, and the rest waits. Cleared when a pass starts.
    @MainActor
    private static var stopRequested = false

    @MainActor
    static func stop() { stopRequested = true }

    /// Seals the recording, and transcribes it if it is short, was asked for, or
    /// `requested` says so now.
    ///
    /// The transcription goes piece by piece and writes its progress after each,
    /// so a run cut short by a suspension, a crash or a new recording goes on from
    /// where it was. It stops by itself when a recording starts: the microphone
    /// must not compete with the model for the device.
    @MainActor
    static func run(for recording: Recording, context: ModelContext, requested: Bool = false) async {
        let id = recording.persistentModelID
        guard inFlight.insert(id).inserted else { return }
        defer { inFlight.remove(id) }

        // Sealing comes first. It fails while the device is locked; the recording
        // then waits for the next unlock or launch, and nothing is marked failed,
        // because nothing has. See `AudioStorage.seal`.
        if !AudioStorage.isSealed(recording.fileName) {
            do {
                recording.fileName = try await AudioStorage.seal(fileName: recording.fileName)
                try? context.save()
            } catch {
                AudioRecorder.log.notice("Seal of \(recording.fileName, privacy: .public) deferred: \(error, privacy: .public)")
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
                    return !RecordingController.shared.isRecording && !stopRequested
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
    /// every launch adds up. «Prøv teksten på nytt» in the row still works.
    ///
    /// `requested` is what the «Lag tekst» shortcut passes: the long recordings
    /// that would otherwise wait for a tap are taken too, because running the
    /// shortcut is the asking.
    @MainActor
    static func runPending(context: ModelContext, requested: Bool = false) async {
        stopRequested = false
        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        for recording in recordings where !recording.hasTranscript && recording.failureCode != "empty" {
            guard !stopRequested else { return }
            await run(for: recording, context: context, requested: requested)
        }
    }

    /// For the «Lag tekst» shortcut: everything, the long recordings included, on
    /// the controller's own context. The shortcut runs off the main actor and
    /// has no context of its own.
    @MainActor
    static func runAllPending() async {
        guard let context = RecordingController.shared.mainContext else { return }
        await runPending(context: context, requested: true)
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
/// While one runs in the foreground, the screen is kept awake, so a device left
/// on the table keeps working. On the charger it runs without the screen; see
/// `BackgroundTranscription`.
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
