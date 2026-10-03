import Foundation
import SpeakerKit
import Testing
@testable import Frodi

/// The model sits as a folder reference. Flatten it and the two config.json files collide, and WhisperKit cannot find
/// the tokenizer. The model is the app's only engine, so a build without it is broken: the suite fails rather than
/// skips (`Scripts/fetch-model.sh`).
@Suite("Modell i pakken")
struct BundledModelTests {
    @Test("Modell og tokenizer peker begge et sted")
    func bothFoldersResolve() {
        #expect(WhisperTranscriber.tokenizerFolder != nil)
        #expect(WhisperTranscriber.isBundled)
    }

    @Test("De tre CoreML-delene finnes")
    func coreMLPartsExist() throws {
        let model = try #require(WhisperTranscriber.modelFolder)
        for part in ["AudioEncoder", "MelSpectrogram", "TextDecoder"] {
            let url = model.appendingPathComponent("\(part).mlmodelc")
            #expect(FileManager.default.fileExists(atPath: url.path), "\(part) mangler")
        }
    }

    /// WhisperKit looks the tokenizer up at exactly this path, and needs both
    /// files. Missing either, it would fetch them from Hugging Face; the app's own
    /// check is what stops that, so the check must see the same files.
    @Test("Tokenizeren ligger på stien WhisperKit forventer")
    func tokenizerLayoutIsExact() throws {
        let tokenizer = try #require(WhisperTranscriber.tokenizerFolder)
        let folder = tokenizer.appendingPathComponent("models/openai/whisper-small")
        for name in ["tokenizer.json", "tokenizer_config.json"] {
            #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path), "\(name) mangler")
        }
        #expect(WhisperTranscriber.tokenizerFiles == ["tokenizer.json", "tokenizer_config.json"])
        #expect(WhisperTranscriber.tokenizerIsComplete)
    }

    @Test("Talermodellen ligger der SpeakerKit leter")
    func speakerModelIsBundled() {
        #expect(Speakers.isBundled)
    }

    /// The app's promise is no network. SpeakerKit downloads by default; the app's one configuration must
    /// point at the bundle with downloads off, and the bundled files must be enough to load and run.
    @Test("Talermodellen henter aldri fra nett")
    func speakerModelNeverDownloads() async throws {
        let config = try #require(Speakers.config)
        #expect(!config.download)
        #expect(config.modelDownloadConfig.modelFolder == Speakers.modelFolder?.path)

        let speakers = try await SpeakerKit(config)
        _ = try await speakers.diarize(audioArray: [Float](repeating: 0, count: 16_000 * 5))
    }
}
