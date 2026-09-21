import AppIntents
import SwiftUI
import WidgetKit

/// The control under Innstillinger > Handlingsknapp > Kontroller, and in
/// Kontrollsenter. One press runs `ToggleRecordingIntent`: start if idle, stop
/// if running.
///
/// A button, not a toggle. A toggle would show whether a recording runs, but
/// the extension cannot read the app's state without an app group, and the
/// Live Activity already shows it on the same screen. The button keeps the
/// attack surface where SECURITY.md says it is: no app group.
///
/// The symbol is SF: a control's image is drawn by the system, which takes
/// symbols only. The one other exception is the same one for the same reason.
struct RecordingControl: ControlWidget {
    static let kind = "com.Tazk.Frodi.record"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ToggleRecordingIntent()) {
                Label("Opptak", systemImage: "mic.fill")
            }
        }
        .displayName("Start eller stopp opptak")
        .description("Starter et opptak i Fróði, eller stopper det som går.")
    }
}
