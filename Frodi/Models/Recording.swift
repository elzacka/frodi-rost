import Foundation
import SwiftData

@Model
final class Recording {
    var createdAt: Date = Date()
    var duration: TimeInterval = 0

    /// Bare filnavnet, aldri hele stien. Sandkassen til appen får ny sti ved
    /// oppdatering og reinstallasjon, så en lagret absolutt sti peker på ingenting
    /// etter neste versjon.
    var fileName: String = ""

    var transcript: String?
    var transcriptionFailed: Bool = false

    /// Ble opptaket startet med handlingsknappen? Vises som en pille i listen.
    var startedWithActionButton: Bool = false

    init(createdAt: Date = Date(), duration: TimeInterval, fileName: String) {
        self.createdAt = createdAt
        self.duration = duration
        self.fileName = fileName
    }

    var fileURL: URL {
        AudioStorage.directory.appendingPathComponent(fileName)
    }

    var hasTranscript: Bool {
        guard let transcript else { return false }
        return !transcript.isEmpty
    }
}
