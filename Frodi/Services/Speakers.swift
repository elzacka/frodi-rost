import ArgmaxCore
import Foundation
import SpeakerKit

/// Who speaks when, for Avansert: pyannote community-1 through SpeakerKit, bundled like nb-whisper.
enum Speakers {
    /// The bundled model, laid out as SpeakerKit expects: `speaker_segmenter/pyannote-v3/W8A16/…`.
    nonisolated static var modelFolder: URL? {
        Bundle.main.url(forResource: "speakerkit", withExtension: nil, subdirectory: "Model")
    }

    /// Whether each model SpeakerKit loads is in the bundle, at the folder SpeakerKit itself derives for it.
    nonisolated static var isBundled: Bool {
        guard let modelFolder else { return false }
        return [ModelInfo.segmenter(), .embedder(), .plda()].allSatisfy { info in
            let folder = info.modelURL(baseURL: modelFolder).path
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
            return names.contains { $0.hasSuffix(".mlmodelc") }
        }
    }

    /// The only configuration the app uses. With a model folder SpeakerKit reads from disk and never calls its
    /// downloader (`PyannoteModelManager.resolveModels`); `download: false` keeps it from fetching at creation.
    nonisolated static var config: PyannoteConfig? {
        guard let modelFolder, isBundled else { return nil }
        return PyannoteConfig(
            modelFolder: modelFolder.path,
            download: false,
            // Off for the same reason as WhisperKit's log: nothing about a recording belongs in the unified log.
            verbose: false,
            logLevel: .none,
            // About 25 % faster on the device, the same voices on the guided interview (2026-10-03). Loses voices of a
            // second or less, such as a podcast jingle.
            fullRedundancy: false
        )
    }

    /// One stretch of one voice, in seconds.
    struct Turn: Equatable, Sendable {
        var start: TimeInterval
        var end: TimeInterval
        var speaker: Int
    }

    /// Kept between texts: loading the models takes seconds.
    @MainActor private static var kit: SpeakerKit?
    /// A load in progress, shared: SpeakerKit cannot be cancelled while it loads, so a second caller waits for the first.
    @MainActor private static var loading: Task<Void, Error>?

    /// Loads the models, so the pass after the last piece does not wait for them (about 6 s on the device, measured 2026-10-03).
    @MainActor
    static func load() async throws {
        if kit != nil { return }
        if let loading { return try await loading.value }
        guard let config else { throw TranscriptionError.modelMissing }
        let task = Task {
            let loaded = try await SpeakerKit(config)
            try await loaded.ensureModelsLoaded()
            kit = loaded
        }
        loading = task
        defer { loading = nil }
        try await task.value
    }

    /// Who spoke when, over the whole file. One pass, not per piece, so a voice keeps its number all the way through.
    @MainActor
    static func turns(in fileURL: URL) async throws -> [Turn] {
        try await load()
        guard let kit else { return [] }
        let file = try AudioPieces(url: fileURL)
        let audio = try await file.samples(from: 0, to: file.duration)
        return try await kit.diarize(audioArray: audio).segments
            .compactMap { segment in
                segment.speaker.speakerId.map { Turn(start: Double(segment.startTime), end: Double(segment.endTime), speaker: $0) }
            }
            .sorted { $0.start < $1.start }
    }

    /// Splits paragraphs where the voice changes and numbers the voices in the order they are first heard.
    /// A word belongs to the turn it overlaps most (right on the guided test interview, `dev_only/DECISIONS.md`).
    /// One voice in the whole text gives no labels. `correct` applies the word list to text rebuilt from words.
    nonisolated static func label(
        _ paragraphs: [TranscriptParagraph],
        turns: [Turn],
        correct: (String) -> String
    ) -> [TranscriptParagraph] {
        let unlabelled = paragraphs.map { TranscriptParagraph(start: $0.start, end: $0.end, text: $0.text) }
        guard !turns.isEmpty else { return unlabelled }

        var split: [TranscriptParagraph] = []
        for paragraph in paragraphs {
            guard let words = paragraph.words, !words.isEmpty else {
                split.append(TranscriptParagraph(
                    start: paragraph.start, end: paragraph.end, text: paragraph.text,
                    speaker: speaker(from: paragraph.start, to: paragraph.end, in: turns)
                ))
                continue
            }
            var parts: [(speaker: Int, words: [TimedWord])] = []
            for word in words {
                let voice = speaker(from: word.start, to: word.end, in: turns)
                if parts.last?.speaker == voice { parts[parts.count - 1].words.append(word) } else { parts.append((voice, [word])) }
            }
            if parts.count == 1 {
                split.append(TranscriptParagraph(start: paragraph.start, end: paragraph.end, text: paragraph.text, speaker: parts[0].speaker))
            } else {
                for part in parts {
                    let text = correct(part.words.map(\.text).joined().trimmingCharacters(in: .whitespaces))
                    guard !text.isEmpty else { continue }
                    split.append(TranscriptParagraph(start: part.words[0].start, end: part.words[part.words.count - 1].end, text: text, speaker: part.speaker))
                }
            }
        }

        var numbers: [Int: Int] = [:]
        for paragraph in split {
            if let voice = paragraph.speaker, numbers[voice] == nil { numbers[voice] = numbers.count + 1 }
        }
        guard numbers.count > 1 else { return unlabelled }
        return split.map { paragraph in
            var numbered = paragraph
            numbered.speaker = paragraph.speaker.flatMap { numbers[$0] }
            return numbered
        }
    }

    /// The voice with the largest share of the span; with none, the nearest turn.
    private nonisolated static func speaker(from start: TimeInterval, to end: TimeInterval, in turns: [Turn]) -> Int {
        var best: (speaker: Int, overlap: TimeInterval)?
        for turn in turns {
            let overlap = min(turn.end, end) - max(turn.start, start)
            if overlap > 0, overlap > (best?.overlap ?? 0) { best = (turn.speaker, overlap) }
        }
        if let best { return best.speaker }
        return turns.min { distance($0, start, end) < distance($1, start, end) }!.speaker
    }

    private nonisolated static func distance(_ turn: Turn, _ start: TimeInterval, _ end: TimeInterval) -> TimeInterval {
        max(turn.start - end, start - turn.end, 0)
    }
}
