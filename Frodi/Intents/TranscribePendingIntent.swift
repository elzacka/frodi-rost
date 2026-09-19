import AppIntents

/// «Lag tekst» as an action in the Shortcuts app: everything waiting for text
/// gets it, the long recordings included, without the app in front.
///
/// The point is an automation. `BackgroundTranscription` asks iOS for a run on
/// the charger and iOS decides when, or whether; a Shortcuts automation on
/// «når laderen kobles til» runs this intent at once, and iOS 27's
/// `LongRunningIntent` lets it keep working after `perform` would otherwise
/// have been cut off. It is deliberately not an App Shortcut: that would put
/// it in the Action Button's picker beside the one shortcut the button is for. Whether the system lets it hold the device for an hour
/// of nb-whisper has not been measured; the run saves after every piece, so a
/// cut costs the piece, not the text.
///
/// Runs in the background only. There is nothing to show, and going to the
/// foreground would mean an unlock.
struct TranscribePendingIntent: LongRunningIntent, CancellableIntent {
    static let title: LocalizedStringResource = "Lag tekst"
    static let description = IntentDescription("Lager tekst av opptakene som venter på det.")
    static let supportedModes: IntentModes = [.background]

    func perform() async throws -> some IntentResult {
        // The closure is handed to the background task, so it must not be
        // main-actor-isolated or capture anything that is; the hop happens inside.
        try await performBackgroundTask {
            await Transcription.runAllPending()
        } onCancel: { _ in
            // The run stops at the next piece; what is done is saved.
            Task { @MainActor in Transcription.stop() }
        }
        return .result()
    }
}
