import Foundation
import SwiftData

/// Ett sted som gjør opptak om til tekst, slik at både grensesnittet og
/// handlingsknappen behandler feil likt.
enum Transcription {
    @MainActor
    static func run(for recording: Recording, context: ModelContext) async {
        let model = SpeechModel()
        await model.refresh()

        guard model.isReady else {
            recording.transcriptionFailed = true
            recording.failureCode = model.state == .unsupported ? "localeUnsupported" : "modelMissing"
            try? context.save()
            return
        }

        recording.transcriptionFailed = false
        recording.failureCode = nil
        do {
            recording.transcript = try await SystemTranscriber(locale: model.locale)
                .transcribe(fileURL: recording.fileURL)
        } catch let error as TranscriptionError {
            recording.transcriptionFailed = true
            recording.failureCode = error.code
        } catch {
            recording.transcriptionFailed = true
            recording.failureCode = "other"
        }
        try? context.save()
    }
}
