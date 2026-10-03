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
            logLevel: .none
        )
    }
}
