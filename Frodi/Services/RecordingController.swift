import Foundation
import Observation
import SwiftData

/// Eier opptaket, og er stedet både grensesnittet og handlingsknappen snakker med.
///
/// Den må være delt fordi en App Intent kjører uten tilgang til SwiftUI. Skulle
/// opptakeren ligget i et view, kunne ikke handlingsknappen stoppe et opptak som
/// alt går.
@MainActor
@Observable
final class RecordingController {
    static let shared = RecordingController()

    private(set) var recorder = AudioRecorder()

    /// Settes når databasen ikke lot seg åpne. Da lagres opptakene bare i minnet.
    private(set) var storageFailed = false

    private var container: ModelContainer?

    private init() {
        // Opptakeren teller selv, og sier fra når grensen er nådd. Lagringen
        // er den samme som når du trykker stopp.
        recorder.onLimitReached = { [weak self] in self?.stopAndSave() }
    }

    var isRecording: Bool { recorder.isRecording }

    func attach(container: ModelContainer, storageFailed: Bool) {
        self.container = container
        self.storageFailed = storageFailed
    }

    /// Starter hvis stille, stopper hvis den går. Dette er det handlingsknappen kaller.
    /// Returnerer true hvis et opptak nå pågår.
    @discardableResult
    func toggle() async -> Bool {
        if recorder.isRecording {
            stopAndSave()
            return false
        }
        AudioPlayer.shared.stop()
        return await recorder.start()
    }

    /// Starter opptak. Returnerer false hvis mikrofonen ikke lot seg ta i bruk.
    /// Handlingsknappen bruker svaret til å avgjøre om den må åpne appen.
    @discardableResult
    func start() async -> Bool {
        guard !recorder.isRecording else { return true }
        // Avspilling og opptak deler lydøkta. Spiller vi av når opptaket
        // starter, tar mikrofonen opp høyttaleren.
        AudioPlayer.shared.stop()
        return await recorder.start()
    }

    func stopAndSave() {
        guard let result = recorder.stop() else { return }

        let recording = Recording(duration: result.duration, fileName: result.fileName)

        guard let context = container?.mainContext else { return }
        context.insert(recording)
        try? context.save()

        // Teksten lages etterpå. Feiler den, står årsaken på opptaket.
        Task { await Transcription.run(for: recording, context: context) }
    }
}
