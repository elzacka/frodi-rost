import Foundation
import Testing
@testable import Frodi

/// The model sits as a folder reference. Flatten it and the two config.json
/// files collide, and WhisperKit cannot find the tokenizer. These tests catch
/// exactly that regression.
@Suite("Modell i pakken")
struct BundledModelTests {
    private var modelIsPresent: Bool { WhisperTranscriber.modelFolder != nil }

    @Test("Modell og tokenizer peker begge et sted")
    func bothFoldersResolve() throws {
        try #require(modelIsPresent, "Modellen er ikke i dette bygget. Kjør Scripts/fetch-model.sh")
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

    /// WhisperKit looks the tokenizer up at exactly this path.
    @Test("Tokenizeren ligger på stien WhisperKit forventer")
    func tokenizerLayoutIsExact() throws {
        let tokenizer = try #require(WhisperTranscriber.tokenizerFolder)
        let file = tokenizer
            .appendingPathComponent("models/openai/whisper-small/tokenizer.json")
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test("Appen bruker den innebygde modellen, ikke Apples")
    func bundledModelIsPreferred() throws {
        try #require(modelIsPresent)
        #expect(Transcription.usesBundledModel)
    }
}
