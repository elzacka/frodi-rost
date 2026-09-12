import Foundation
import SwiftData

/// One place that turns recordings into text, so the interface and the Action
/// Button handle errors the same way.
///
/// The engine is chosen here. If nb-whisper is in the build it is used, and
/// everything then happens inside the app's own container. If it is missing we
/// fall back to Apple's model, which also runs on the device, but in a system
/// process outside the app.
enum Transcription {
    /// Kept alive between recordings. The model takes several seconds to load.
    private static let whisper = WhisperTranscriber()

    static var usesBundledModel: Bool { WhisperTranscriber.isBundled }

    /// Recordings being worked on right now.
    ///
    /// Launch and unlock each start a pass over the pending recordings, and the
    /// list starts its own at launch. Whichever reaches a recording first does the
    /// work; the others skip it. The flag on the recording cannot serve here: it is
    /// saved to disk and would be stale after a crash.
    @MainActor
    private static var inFlight: Set<PersistentIdentifier> = []

    @MainActor
    static func run(for recording: Recording, context: ModelContext) async {
        let id = recording.persistentModelID
        guard inFlight.insert(id).inserted else { return }
        defer { inFlight.remove(id) }

        // Sealing comes first. It fails while the device is locked; the recording
        // then waits for the next unlock or launch, and nothing is marked failed,
        // because nothing has. See `AudioStorage.seal`.
        if !AudioStorage.isSealed(recording.fileName) {
            guard let sealed = try? await AudioStorage.seal(fileName: recording.fileName) else { return }
            recording.fileName = sealed
            try? context.save()
        }

        recording.isTranscribing = true
        do {
            let text = try await AudioStorage.withDecrypted(fileName: recording.fileName) { url in
                try await transcriber(for: url)
            }
            try recording.setTranscript(text)
            recording.transcriptionFailed = false
            recording.failureCode = nil
        } catch let error as TranscriptionError {
            recording.transcriptionFailed = true
            recording.failureCode = error.code
        } catch {
            recording.transcriptionFailed = true
            recording.failureCode = "other"
        }
        recording.isTranscribing = false
        try? context.save()
    }

    @MainActor
    private static func transcriber(for url: URL) async throws -> String {
        if usesBundledModel {
            return try await whisper.transcribe(fileURL: url)
        }

        let model = SpeechModel()
        await model.refresh()
        guard model.isReady else {
            throw model.state == .unsupported
                ? TranscriptionError.localeUnsupported
                : TranscriptionError.modelMissing
        }
        return try await SystemTranscriber(locale: AppLocale.norwegian).transcribe(fileURL: url)
    }
}
