import Foundation
import Testing
@testable import Frodi

/// Runs the bundled model over a real file, piece by piece. Needs the model in
/// the build and a fixture on disk, so it is a tool as much as a test:
///
/// ```bash
/// say -v Nora -f tekst.txt -o tekst.aiff
/// afconvert -f m4af -d aac@16000 -c 1 tekst.aiff tekst.m4a
/// TEST_RUNNER_FRODI_FIXTURE=/full/path/tekst.m4a xcodebuild ... \
///   -only-testing:FrodiTests/PiecewiseTranscriptionTests test
/// ```
///
/// Prints the pieces, the words and the peak memory, so a change to the piece
/// length or the seam can be measured rather than guessed at. The resume
/// test needs a fixture longer than one piece, `pieceLength`. With
/// `FRODI_WORDS` set, that text is the word list for the whole-file run.
@Suite("Transkribering i stykker", .serialized)
struct PiecewiseTranscriptionTests {
    private static var fixture: URL? {
        ProcessInfo.processInfo.environment["FRODI_FIXTURE"].map { URL(fileURLWithPath: $0) }
    }

    private static var enabled: Bool { fixture != nil && WhisperTranscriber.isBundled }

    private struct Piece {
        let position: TimeInterval
        let paragraphs: [TranscriptParagraph]
    }

    @MainActor
    private func transcribe(from start: TimeInterval, stopAfter limit: Int? = nil) async throws -> [Piece] {
        var pieces: [Piece] = []
        try await WhisperTranscriber().transcribe(fileURL: Self.fixture!, from: start) { paragraphs, position in
            pieces.append(Piece(position: position, paragraphs: paragraphs))
            return limit.map { pieces.count < $0 } ?? true
        }
        return pieces
    }

    private func words(_ pieces: [Piece]) -> Int {
        pieces.flatMap(\.paragraphs).reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
    }

    /// The whole file, in pieces that end where the file ends, with the memory it took.
    ///
    /// With `FRODI_WORDS` set, that text is the word list for the run, and the
    /// output says which of its entries came through. That is the check that
    /// the prompt reaches this model at all.
    @MainActor
    @Test("Hele filen kommer gjennom, stykke for stykke", .enabled(if: enabled))
    func wholeFile() async throws {
        let list = ProcessInfo.processInfo.environment["FRODI_WORDS"] ?? ""
        WordList.save(list)
        defer { WordList.save("") }

        let duration = try WhisperTranscriber.duration(of: Self.fixture!)
        let started = Date()
        let pieces = try await transcribe(from: 0)
        let text = WordList.correct(
            pieces.flatMap(\.paragraphs).map(\.text).joined(separator: " "),
            entries: WordList.entries(in: list)
        )
        for entry in WordList.prompt(from: list)?.components(separatedBy: ", ") ?? [] {
            print("  WORD \(entry): \(text.localizedCaseInsensitiveContains(entry) ? "found" : "missing")")
        }
        print("TEXT \(text)")

        let expected = Int((duration / WhisperTranscriber.pieceLength).rounded(.up))
        #expect(pieces.count == expected)
        #expect(abs(pieces.last!.position - duration) < 0.2)
        for (a, b) in zip(pieces, pieces.dropFirst()) {
            #expect(b.position > a.position)
            #expect(b.position - a.position <= WhisperTranscriber.pieceLength + 0.01)
        }
        for paragraph in pieces.flatMap(\.paragraphs) {
            #expect(paragraph.start < paragraph.end)
            #expect(paragraph.end <= duration + 1)
        }

        // The footprint right now, not the peak, which the simulator does not expose
        // here. Read after the last piece, so it shows what the pieces leave behind.
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        _ = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let peakMB = Double(info.phys_footprint) / 1_048_576
        print("""
        FIXTURE \(Self.fixture!.lastPathComponent): \(Int(duration)) s, \(pieces.count) pieces, \
        \(words(pieces)) words, \(Int(Date().timeIntervalSince(started))) s, footprint \(Int(peakMB)) MB
        """)
        for piece in pieces { print("  piece to \(Transcript.mark(piece.position)): \(piece.paragraphs.count) paragraphs") }
    }

    /// Stopping after the first piece and starting again from its end gives the
    /// same tail as one uninterrupted run would.
    @MainActor
    @Test("En avbrutt transkribering fortsetter der den slapp", .enabled(if: enabled))
    func resumes() async throws {
        let first = try await transcribe(from: 0, stopAfter: 1)
        #expect(first.count == 1)

        let rest = try await transcribe(from: first[0].position)
        let duration = try WhisperTranscriber.duration(of: Self.fixture!)
        // A fixture shorter than one piece has no rest to resume; fail, do not trap the host.
        let last = try #require(rest.last, "Fikseringen er kortere enn ett stykke")
        #expect(abs(last.position - duration) < 0.2)
        #expect(rest.flatMap(\.paragraphs).allSatisfy { $0.start >= first[0].position - 0.01 })

        let whole = try await transcribe(from: 0)
        let joined = words(first) + words(rest)
        #expect(abs(joined - words(whole)) <= 5, "\(joined) mot \(words(whole)) ord")
    }
}
