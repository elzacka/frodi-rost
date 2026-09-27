import Foundation
import SwiftData
import os

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

    /// The name the user gives the recording, sealed like the text: a name often
    /// says who was interviewed. Nil until one is given; the list then shows the
    /// date.
    private(set) var sealedTitle: Data?

    /// What the recording was when it came into the app. Written once, see
    /// `recordOrigin`, and never by anything the user does.
    private(set) var sealedOrigin: Data?

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

    /// Longer than any name worth giving, short enough to fit a heading.
    static let titleLimit = 100

    /// The user's name for the recording, or nil. Opened on first use and kept
    /// in memory: the list shows one in every row it draws, and every open goes
    /// through the Secure Enclave.
    func title() -> String? {
        guard let sealedTitle else { return nil }
        if let opened = OpenedTitles.cache.withLock({ $0[sealedTitle] }) { return opened }
        guard let title = try? RecordingVault.openText(sealedTitle) else { return nil }
        OpenedTitles.cache.withLock { $0[sealedTitle] = title }
        return title
    }

    /// Names the recording, on one line. A blank name removes it, and the list
    /// shows the date again. Only the name changes: the origin keeps what the
    /// recording was.
    func setTitle(_ title: String?) throws {
        let line = (title ?? "")
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else {
            sealedTitle = nil
            return
        }
        let name = String(line.prefix(Self.titleLimit))
        let sealed = try RecordingVault.seal(name)
        OpenedTitles.cache.withLock { $0[sealed] = name }
        sealedTitle = sealed
    }

    /// Writes the origin, once. A recording that has one keeps it: there is no
    /// other path that writes the field, and this one refuses a second time.
    func recordOrigin(_ origin: RecordingOrigin) throws {
        guard sealedOrigin == nil else { return }
        sealedOrigin = try RecordingVault.seal(try origin.encoded())
    }

    /// The origin, checked: it opens, it decodes, and it names this recording.
    func origin() -> OriginState {
        guard let sealedOrigin else { return .none }
        return RecordingOrigin.verify(sealedOrigin, fileName: fileName)
    }
}

/// Opened names, by their sealed bytes.
private enum OpenedTitles {
    static let cache = OSAllocatedUnfairLock<[Data: String]>(initialState: [:])
}
