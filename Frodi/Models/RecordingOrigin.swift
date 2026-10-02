import CryptoKit
import Foundation

/// What a recording was on arrival; written once, sealed (`Recording.recordOrigin` refuses a second write).
/// Sealed via `RecordingVault`: unreadable off-device, tamper-evident. Bound to file stem, date, length, audio checksum.
/// Not proof to others: the date is the device clock, an imported checksum names the file, not its authenticity. See SECURITY.md.
struct RecordingOrigin: Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable {
        case recorded, imported
    }

    /// The file name's stem, which is the recording's own id.
    let recordingID: String
    let source: Source
    /// When the recording was made, as the list dates it.
    let createdAt: Date
    let duration: TimeInterval
    /// Of the audio as sealed: the bytes an export hands over as `.m4a`.
    let audioSHA256: String
    /// When a file was brought in. Nil for a recording made here.
    let importedAt: Date?
    /// The file as it was picked, before it was converted. Nil for a recording
    /// made here.
    let original: OriginalFile?

    /// An imported file as it was, read before the conversion touched it.
    struct OriginalFile: Codable, Equatable, Sendable {
        let name: String
        let byteCount: Int
        /// Of the file's bytes, in hex. Anyone holding the original can check it
        /// with `shasum -a 256`.
        let sha256: String
        /// The codec as a reader knows it, «MP3» or «AAC».
        let format: String
        let sampleRate: Double
        let channels: Int
        /// The creation date in the file's own metadata, if it had one, as the
        /// file states it. The row is dated from it only when it is plausible;
        /// see `AudioImport.plausibleDate`.
        let createdAt: Date?
        /// The file's other metadata, by common key: title, artist, software and
        /// the like, as text. Kept as it was, not interpreted. Never a location,
        /// see `AudioImport.metadata`.
        let tags: [String: String]
    }

    static func recordingID(for fileName: String) -> String {
        String(fileName.prefix { $0 != "." })
    }

    /// In hex, the way `shasum -a 256` prints it.
    static func checksum(_ data: Data) -> String {
        SHA256.hash(data: data).hex
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(self)
    }

    static func decoded(from data: Data) throws -> RecordingOrigin {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RecordingOrigin.self, from: data)
    }

    /// Opens a sealed origin and checks it against its row: same recording, same date to the second, same length. A key the
    /// locked device refuses is not tampering and gives nothing, not a warning. The audio is checked separately
    /// (`OriginState.matching`) since that reads the whole file.
    static func verify(_ sealed: Data, fileName: String, createdAt: Date, duration: TimeInterval) -> OriginState {
        let data: Data
        do {
            data = try RecordingVault.open(sealed)
        } catch RecordingVault.VaultError.keyUnavailable {
            return .none
        } catch {
            return .unverifiable
        }
        guard let origin = try? decoded(from: data), origin.recordingID == recordingID(for: fileName) else {
            return .unverifiable
        }
        guard abs(origin.createdAt.timeIntervalSince(createdAt)) < 1, abs(origin.duration - duration) < 0.5 else {
            return .mismatched(origin)
        }
        return .verified(origin)
    }
}

extension SHA256.Digest {
    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

/// What the recording page can say about a recording's origin.
enum OriginState: Equatable {
    /// A recording from before origins were kept. There is nothing to show.
    case none
    case verified(RecordingOrigin)
    /// The origin opened and is this recording's, but the row's date or length,
    /// or the audio on disk, is not what it was written for. The origin is what
    /// was locked, and the page shows it under the warning.
    case mismatched(RecordingOrigin)
    /// The sealed origin did not open, or belongs to another recording. Nothing
    /// in it can be shown.
    case unverifiable

    var verified: RecordingOrigin? {
        if case .verified(let origin) = self { origin } else { nil }
    }

    /// Whether the page and the export have to say that the details cannot be
    /// confirmed.
    var isDoubtful: Bool {
        switch self {
        case .mismatched, .unverifiable: true
        case .none, .verified: false
        }
    }

    /// The same state, with the audio on disk checked too.
    func matching(audioChecksum: String) -> OriginState {
        guard let origin = verified, origin.audioSHA256 != audioChecksum else { return self }
        return .mismatched(origin)
    }
}
