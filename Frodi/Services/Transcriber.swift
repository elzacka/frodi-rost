import Foundation
import Speech

/// Porten mot tale til tekst. Alt som gjør om lyd til tekst går gjennom denne,
/// slik at nb-whisper kan erstatte Apples motor uten at resten av appen merker det.
protocol Transcriber: Sendable {
    /// Er norsk tale til tekst tilgjengelig på enheten, uten nett?
    var isAvailableOffline: Bool { get async }

    func transcribe(fileURL: URL) async throws -> String
}

enum TranscriptionError: LocalizedError {
    case notAuthorized
    case unavailableOffline
    case empty
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            String(localized: "Fróði har ikke fått lov til å gjøre tale om til tekst. Du kan slå det på i Innstillinger.")
        case .unavailableOffline:
            String(localized: "Norsk tale til tekst er ikke lastet ned på denne telefonen ennå.")
        case .empty:
            String(localized: "Fant ingen tale i opptaket.")
        case .underlying(let message):
            message
        }
    }
}

/// Apples egen motor, låst til å kjøre på enheten.
///
/// `requiresOnDeviceRecognition` er det som holder løftet om at ingenting
/// forlater telefonen. Uten den sender Apple lyden til sine egne servere.
struct AppleTranscriber: Transcriber {
    private let locale = Locale(identifier: "nb-NO")

    var isAvailableOffline: Bool {
        get async {
            guard let recognizer = SFSpeechRecognizer(locale: locale) else { return false }
            return recognizer.isAvailable && recognizer.supportsOnDeviceRecognition
        }
    }

    func transcribe(fileURL: URL) async throws -> String {
        guard await Self.authorize() else { throw TranscriptionError.notAuthorized }

        guard let recognizer = SFSpeechRecognizer(locale: locale),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            throw TranscriptionError.unavailableOffline
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        let text = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            // Kalles flere ganger. Vi svarer bare på det siste resultatet,
            // og bruker en boks for å unngå å gjenoppta continuation to ganger.
            let hasResumed = ResumeGuard()
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if hasResumed.claim() {
                        continuation.resume(throwing: TranscriptionError.underlying(error.localizedDescription))
                    }
                    return
                }
                guard let result, result.isFinal else { return }
                if hasResumed.claim() {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranscriptionError.empty }
        return trimmed
    }

    private static func authorize() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

/// Sørger for at en continuation bare gjenopptas én gang.
private final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var used = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if used { return false }
        used = true
        return true
    }
}
