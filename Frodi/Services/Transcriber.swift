import Foundation

/// The gateway to speech to text. Everything that turns audio into text goes
/// through this, so the engine can be swapped without the rest of the app noticing.
///
/// Bound to the main actor because WhisperKit is not `Sendable` and therefore
/// cannot cross an actor boundary. The engines do the actual work on their own threads.
@MainActor
protocol Transcriber {
    /// Turns the audio from `start` to the end into paragraphs, a piece at a time.
    ///
    /// After each piece the paragraphs found in it and the position reached are
    /// handed to `piece`. Returning false stops the transcription there; what has
    /// been handed over is kept, and a later call from that position goes on.
    func transcribe(
        fileURL: URL,
        from start: TimeInterval,
        piece: ([TranscriptParagraph], TimeInterval) async -> Bool
    ) async throws
}

enum TranscriptionError: LocalizedError {
    case modelMissing
    case empty
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            String(localized: "Språkmodellen mangler i appen.")
        case .empty:
            String(localized: "Fant ingen tale i opptaket.")
        case .underlying(let message):
            message
        }
    }

    /// Stored on the recording so the list and the detail view can state the real cause.
    var code: String {
        switch self {
        case .modelMissing: "modelMissing"
        case .empty: "empty"
        case .underlying: "other"
        }
    }

    /// Short text for the list row.
    static func shortText(for code: String?) -> String {
        switch code {
        case "modelMissing": String(localized: "språkmodell mangler")
        case "empty": String(localized: "ingen tale")
        case "other": String(localized: "noe gikk galt")
        default: String(localized: "ingen tekst")
        }
    }

    /// Longer explanation for the detail screen.
    static func explanation(for code: String?) -> String {
        switch code {
        case "modelMissing":
            String(localized: "Språkmodellen mangler i appen. Installer appen på nytt for å rette feilen.")
        case "empty":
            String(localized: "Fant ingen tale i dette opptaket.")
        case "other":
            String(localized: "Fróði fikk ikke laget teksten denne gangen.")
        default:
            String(localized: "Venter på teksten.")
        }
    }
}
