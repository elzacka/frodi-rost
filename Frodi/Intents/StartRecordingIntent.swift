import AppIntents

/// Intenten handlingsknappen kjører. Ett trykk starter, neste trykk stopper.
///
/// `supportedModes` lar den kjøre i bakgrunnen når den bare skal stoppe et
/// opptak som alt går. Det er dette som gjør at du kan stoppe med skjermen
/// låst, uten å låse opp. Skal den starte, trenger den mikrofonen, og da
/// flytter iOS den til forgrunnen av seg selv.
struct ToggleRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start eller stopp opptak"
    static let description = IntentDescription("Starter et opptak i Fróði, eller stopper det som går.")
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @MainActor
    func perform() async throws -> some IntentResult {
        let controller = RecordingController.shared

        // Å stoppe krever ingenting av grensesnittet, og går fint i bakgrunnen.
        if controller.isRecording {
            controller.stopAndSave()
            return .result()
        }

        // Å starte krever mikrofonen. Den får vi bare i forgrunnen.
        // alwaysConfirm er false fordi du alt har bedt om dette ved å trykke
        // på knappen. Et bekreftelsessteg til ville vært i veien i bil.
        if systemContext.currentMode == .background {
            try await continueInForeground(alwaysConfirm: false)
        }
        await controller.start()
        return .result()
    }
}

struct FrodiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleRecordingIntent(),
            phrases: [
                "Start opptak i \(.applicationName)",
                "Stopp opptak i \(.applicationName)",
                "Ta opp med \(.applicationName)"
            ],
            shortTitle: "Start eller stopp opptak",
            systemImageName: "mic.fill"
        )
    }
}
