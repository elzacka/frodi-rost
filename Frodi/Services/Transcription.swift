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

    @MainActor
    static func run(for recording: Recording, context: ModelContext) async {
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
