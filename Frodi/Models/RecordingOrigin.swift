import Foundation

/// What a recording was when it came into the app, written once and sealed.
///
/// The name the user gives a recording can change; this cannot. It is set once,
/// at the import for a file brought in, and at the seal for a recording made
/// here, and `Recording.recordOrigin` refuses a second write. It is sealed
/// through `RecordingVault` like the text, which gives two things: it cannot be
/// read off the device, and a change to the stored bytes makes it fail to open
/// rather than open wrong. It carries the stem of its recording's file name, so
/// an origin moved onto another row does not match there either.
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
        /// The codec as Core Audio names it, «MPEG Layer 3» or «AAC».
        let format: String
        let sampleRate: Double
        let channels: Int
        /// The creation date in the file's own metadata, if it had one.
        let createdAt: Date?
        /// The file's other metadata, by common key: title, artist, software and
        /// the like, as text. Kept as it was, not interpreted.
        let tags: [String: String]
    }

    static func recordingID(for fileName: String) -> String {
        String(fileName.prefix { $0 != "." })
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

    /// Opens a sealed origin and checks that it belongs to the recording with
    /// this file name. A key the locked device refuses is not a sign of
    /// tampering, and gives nothing rather than a warning.
    static func verify(_ sealed: Data, fileName: String) -> OriginState {
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
        return .verified(origin)
    }
}

/// What the recording page can say about a recording's origin.
enum OriginState: Equatable {
    /// A recording from before origins were kept. There is nothing to show.
    case none
    case verified(RecordingOrigin)
    /// The sealed origin did not open, or belongs to another recording.
    case unverifiable

    var verified: RecordingOrigin? {
        if case .verified(let origin) = self { origin } else { nil }
    }
}
