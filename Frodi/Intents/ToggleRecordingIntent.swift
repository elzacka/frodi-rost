import AppIntents
import AVFAudio

/// The intent the Action Button runs, through the app's control. The button is
/// held, not tapped: the first hold starts, the next stops.
///
/// `AudioRecordingIntent` is what lets a start happen with the device locked.
/// A plain intent may stop a recording in the background and never begin one;
/// iOS refused the session ('!int') and then the recorder ('!rec'), measured
/// on a device on 2026-09-16. This protocol tells the system that the app
/// records audio, and the system runs the intent in the app's process without
/// opening the app. The price is a Live Activity: it must start with the
/// recording and stay for as long as the recording runs, or iOS stops the
/// recording. `RecordingController` starts and ends it. The session such a
/// start opens is mixable, because iOS refuses any other from the background;
/// see `AudioRecorder.start()`.
///
/// `LiveActivityIntent` is the permission to start that activity from the
/// background; without it an activity can only be started with the app in front.
///
/// Compiled into the widget extension too, because the control and the Live
/// Activity's stop button name the intent. It never performs there: the system
/// hands both to the app.
struct ToggleRecordingIntent: AudioRecordingIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Start eller stopp opptak"
    static let description = IntentDescription("Starter et opptak i Fróði, eller stopper det som går.")

    @MainActor
    func perform() async throws -> some IntentResult {
        #if FRODI_WIDGET
        return .result()
        #else
        let controller = RecordingController.shared
        if controller.isRecording {
            controller.stopAndSave()
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
