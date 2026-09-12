import Foundation
import SwiftData

@Model
final class Recording {
    var createdAt: Date = Date()
    var duration: TimeInterval = 0

    /// Only the file name, never the full path. The app's sandbox gets a new path on
    /// update and reinstall, so a stored absolute path points at nothing after the
    /// next version.
    var fileName: String = ""

    /// The text is sealed the same way as the audio.
    ///
    /// A transcript is often more exposing than the audio file. It is searchable,
    /// readable at a glance, and can be copied without being played. Protecting the
    /// audio and leaving the text in the clear would be locking the door and leaving
    /// the window open.
    var sealedTranscript: Data?

    var transcriptionFailed: Bool = false

    /// Set at the start and cleared at the end of `Transcription.run`, which is the
    /// only place that saves while the flag is true. If the app crashes in the middle
    /// of an attempt without anything else having saved in between, the next launch
    /// reads the flag as `false` from disk, and `transcribePending()` picks the
    /// recording up again without it being stuck as «transkriberer».
    var isTranscribing: Bool = false

    /// Why the text is missing. Without this the app says «fant ingen tale» even when
    /// the reason is that the speech model does not exist, and that is a false message.
    var failureCode: String?

    init(createdAt: Date = Date(), duration: TimeInterval, fileName: String) {
        self.createdAt = createdAt
        self.duration = duration
        self.fileName = fileName
    }

    var fileURL: URL {
        AudioStorage.directory.appendingPathComponent(fileName)
    }

    var hasTranscript: Bool { sealedTranscript != nil }

    /// Unlocks the text. Called only when it is actually going to be shown or exported.
    func transcript() throws -> String? {
        guard let sealedTranscript else { return nil }
        return try RecordingVault.openText(sealedTranscript)
    }

    func setTranscript(_ text: String) throws {
        sealedTranscript = try RecordingVault.seal(text)
    }
}
