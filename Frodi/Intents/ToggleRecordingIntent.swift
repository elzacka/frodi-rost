import AppIntents
import AVFoundation

/// Intenten handlingsknappen kjører. Ett trykk starter, neste trykk stopper.
///
/// `supportedModes` lar den kjøre i bakgrunnen. Både start og stopp forsøkes
/// der først, fordi å åpne appen er det som tvinger fram Face ID eller kode
/// når skjermen er låst. I bil ligger enheten gjerne flatt på ladeplaten og
/// ser ikke ansiktet ditt, så opplåsingen er ikke bare et ekstra trykk – den
/// kan ikke fullføres mens du kjører.
///
/// Gir ikke iOS oss mikrofonen i bakgrunnen, er forgrunnen eneste vei, og da
/// må enheten låses opp. Forsøket koster ingenting når det feiler.
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

        // Uten mikrofontillatelse er det ingen vits i å prøve i bakgrunnen:
        // spørsmålet kan bare stilles i forgrunnen, og et forsøk her ville
        // bare fått nei uten at du ble spurt.
        if AVAudioApplication.shared.recordPermission == .granted,
           await controller.start() {
            return .result()
        }

        // Da må appen fram, og iOS krever opplåsing.
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
