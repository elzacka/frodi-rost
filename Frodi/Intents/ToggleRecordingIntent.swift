import AppIntents

/// The intent the Action Button runs. The button is held, not tapped: the first
/// hold starts, the next stops.
///
/// `supportedModes` lets it run in the background, and stopping does: it needs
/// nothing from the interface and no unlock. Starting cannot. iOS lets an app
/// continue a recording in the background, never begin one; the answer is
/// `AVAudioSession.ErrorCode.cannotStartRecording`, which `AVAudioRecorder`
/// reports as `record()` returning false. Measured on a device on
/// 16 September 2026, first with a non-mixable session (activation refused)
/// and then with a mixable one (activation allowed, recording refused). So a
/// start goes to the foreground at once, and on a locked device that means
/// Face ID or the passcode. In a car, start before you drive; the button then
/// only has to stop, and stopping works with the screen locked.
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

        // alwaysConfirm is false because you already asked for this by pressing the
        // button. Another confirmation step would be in the way in a car.
        if systemContext.currentMode == .background {
            try await continueInForeground(alwaysConfirm: false)
        }
        await controller.start()
        return .result()
    }
}

/// Published so the intent appears under Fróði røst in the Action Button's
/// shortcut picker. The picker needs a phrase: with `phrases: []` the entry
/// disappeared from Innstillinger > Handlingsknapp > Snarvei on a device, so
/// one phrase stays, the fewest that keep the button working. It also gives
/// Siri a way in; that cannot be had one without the other.
struct FrodiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleRecordingIntent(),
            phrases: ["Start eller stopp opptak i \(.applicationName)"],
            shortTitle: "Start eller stopp opptak",
            systemImageName: "mic.fill"
        )
    }
}
