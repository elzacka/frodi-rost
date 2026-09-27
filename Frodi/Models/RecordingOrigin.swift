import CryptoKit
import Foundation

/// What a recording was when it came into the app, written once and sealed.
///
/// The name the user gives a recording can change; this cannot. It is written
/// once, the moment the audio is sealed, and `Recording.recordOrigin` refuses a
/// second write. It is sealed through `RecordingVault` like the text, which
/// gives two things: it cannot be read off the device, and a change to the
/// stored bytes makes it fail to open rather than open wrong.
///
/// It is tied to its recording three ways. It names the recording's file stem,
/// so an origin moved onto another row does not match there. It holds the date
/// and length, which `verify` compares with the row's own, so the list's plain
/// fields cannot be changed without the page saying so. And it holds the
/// checksum of the sealed audio, which the recording page compares with the
/// audio on disk when the details are opened, so another sealed file swapped in
/// under the same name does not pass either.
///
/// What it cannot give is proof to anyone else. The date comes from the
/// device's clock, and the checksum of an imported original says which file
/// came in, not that the file is what it claims. See SECURITY.md.
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

    /// Opens a sealed origin and checks it against the row it hangs on: the same
    /// recording, the same date to the second, the same length. A key the locked
    /// device refuses is not a sign of tampering, and gives nothing rather than a
    /// warning. The audio is checked separately, see `OriginState.matching`,
    /// since that means reading the whole file.
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
