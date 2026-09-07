import Foundation
import SwiftData

/// Ett sted som gjør opptak om til tekst, slik at både grensesnittet og
/// handlingsknappen behandler feil likt.
///
/// Motoren velges her. Er nb-whisper med i bygget, brukes den — da skjer alt
/// inne i appens egen container. Mangler den, faller vi tilbake til Apples
/// modell, som også kjører på enheten, men i en systemprosess utenfor appen.
enum Transcription {
    /// Holdes i live mellom opptak. Modellen bruker flere sekunder på å lastes.
    private static let whisper = WhisperTranscriber()

    static var usesBundledModel: Bool { WhisperTranscriber.isBundled }

    @MainActor
    static func run(for recording: Recording, context: ModelContext) async {
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
