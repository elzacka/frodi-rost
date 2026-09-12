import Foundation
import Testing
@testable import Frodi

/// The model sits as a folder reference. Flatten it and the two config.json
/// files collide, and WhisperKit cannot find the tokenizer. These tests catch
/// exactly that regression.
///
/// The model is optional: a clone that skipped `Scripts/fetch-model.sh` builds
/// and runs on Apple's engine, and the README says so. The suite therefore skips
/// without the model instead of turning four tests red.
@Suite("Modell i pakken", .enabled(if: WhisperTranscriber.modelFolder != nil, "Modellen er ikke i dette bygget. Kjør Scripts/fetch-model.sh"))
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

    @Test("Appen bruker den innebygde modellen, ikke Apples")
    func bundledModelIsPreferred() {
        #expect(Transcription.usesBundledModel)
    }
}
