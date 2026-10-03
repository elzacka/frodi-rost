import AppIntents
import AVFAudio

/// Action Button intent: first hold starts, next stops. Compiled into the widget too, never performed there.
/// `AudioRecordingIntent` lets a start run locked (plain intents hit '!int'/'!rec'); needs a Live Activity for the whole recording.
/// `LiveActivityIntent` starts it from the background; the session must be mixable, see `AudioRecorder.start()`.
struct ToggleRecordingIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Start eller stopp opptak"
    static let description = IntentDescription("Starter et opptak i Fróði eller stopper det som går.")

    @MainActor
    func perform() async throws -> some IntentResult {
        #if FRODI_WIDGET
        return .result()
        #else
        let controller = RecordingController.shared
        if controller.isRecording {
            controller.stopAndSave()
            await controller.recorder.sessionReleased()
            return .result()
        }
        // The microphone prompt cannot be shown from the background. The first
        // start is made in the app, and that is not the in-car case.
        guard AVAudioApplication.shared.recordPermission == .granted else {
            throw RecordingIntentError.microphoneNotGranted
        }
        guard await controller.start() else { throw RecordingIntentError.didNotStart }
        return .result()
        #endif
    }
}

/// What the system shows when the intent cannot do its job. Errors only; a
/// start or stop that went through says nothing, the Live Activity does.
enum RecordingIntentError: Error, CustomLocalizedStringResourceConvertible {
    case microphoneNotGranted
    case didNotStart

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .microphoneNotGranted: "Åpne Fróði og start et opptak der først, så appen får tilgang til mikrofonen."
        case .didNotStart: "Fróði fikk ikke startet opptaket."
        }
    }
}
