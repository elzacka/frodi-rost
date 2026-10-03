import Foundation
import Testing
@testable import Frodi

/// Runs the bundled model piece by piece over a real file (`FRODI_FIXTURE`); prints pieces, words, peak memory.
/// Resume test needs a fixture longer than `pieceLength`. `FRODI_WORDS`: word list for the whole-file run.
/// Fixture and run command: README, *Verktøy og målinger*.
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
        try await WhisperTranscriber().transcribe(fileURL: Self.fixture!, from: start, words: false) { paragraphs, position in
            pieces.append(Piece(position: position, paragraphs: paragraphs))
            return limit.map { pieces.count < $0 } ?? true
        }
        return pieces
    }

    private func words(_ pieces: [Piece]) -> Int {
        pieces.flatMap(\.paragraphs).reduce(0) { $0 + $1.text.split(whereSeparator: \.isWhitespace).count }
    }

    /// The whole file, in pieces that end where the file ends, with the memory it took.
    /// With `FRODI_WORDS` set, that text is the word list and the output says which entries came through: proves the prompt reaches this model.
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

    /// Avansert end to end: words with times from every paragraph, retried ones included, then the voices.
    /// Prints the labelled text for a listening check; `FRODI_SPEAKERS` is the number of voices expected.
    @MainActor
    @Test("Avansert merker hvem som sa hva", .enabled(if: enabled))
    func whoSaidWhat() async throws {
        var paragraphs: [TranscriptParagraph] = []
        try await WhisperTranscriber().transcribe(fileURL: Self.fixture!, from: 0, words: true) { piece, _ in
            paragraphs += piece
            return true
        }
        #expect(paragraphs.allSatisfy { $0.words?.isEmpty == false }, "Et avsnitt mangler ordtider")

        let started = Date()
        let turns = try await Speakers.turns(in: Self.fixture!)
        let labelled = Speakers.label(paragraphs, turns: turns) { $0 }
        let voices = Set(labelled.compactMap(\.speaker)).count
        print("Hvem sa hva: \(voices) stemmer, \(String(format: "%.1f", Date().timeIntervalSince(started))) s")
        print(Transcript.compose(labelled))
        if let expected = ProcessInfo.processInfo.environment["FRODI_SPEAKERS"].flatMap(Int.init) {
            #expect(voices == expected)
        }
    }
}
