import AppIntents
import AVFoundation

/// The intent the Action Button runs. The button is held, not tapped: the first
/// hold starts, the next stops.
///
/// `supportedModes` lets it run in the background. Both start and stop are tried
/// there first, because opening the app is what forces Face ID or the passcode
/// when the screen is locked. In a car the device typically lies flat on the
/// charging pad and cannot see your face, so the unlock is not just an extra tap;
/// it cannot be completed while you drive.
///
/// If iOS does not give us the microphone in the background, the foreground is
/// the only way, and then the device has to be unlocked. The attempt costs
/// nothing when it fails.
struct ToggleRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start eller stopp opptak"
    static let description = IntentDescription("Starter et opptak i Fróði, eller stopper det som går.")
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @MainActor
    func perform() async throws -> some IntentResult {
        let controller = RecordingController.shared

        // Stopping needs nothing from the interface, and works fine in the background.
        if controller.isRecording {
            controller.stopAndSave()
            return .result()
        }

        // Without microphone permission there is no point trying in the background:
        // the question can only be asked in the foreground, and an attempt here would
        // just get a no without you being asked.
        if AVAudioApplication.shared.recordPermission == .granted,
           await controller.start() {
            return .result()
        }

        // Then the app has to come forward, and iOS requires an unlock.
        // alwaysConfirm is false because you already asked for this by pressing the
        // button. Another confirmation step would be in the way in a car.
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
