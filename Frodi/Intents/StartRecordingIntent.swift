import AppIntents

/// Intenten handlingsknappen kjører.
///
/// `openAppWhenRun` er true med vilje. iOS gir ikke pålitelig mikrofontilgang
/// til en app som startes i bakgrunnen, og i bil er det dessuten en fordel å se
/// på skjermen at opptaket faktisk går.
struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start opptak"
    static let description = IntentDescription("Starter et nytt lydopptak i Fróði.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        LaunchRequest.shared.shouldStartRecording = true
        return .result()
    }
}

struct FrodiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start opptak i \(.applicationName)",
                "Ta opp med \(.applicationName)"
            ],
            shortTitle: "Start opptak",
            systemImageName: "mic.fill"
        )
    }
}
