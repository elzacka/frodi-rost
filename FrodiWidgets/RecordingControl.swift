import AppIntents
import SwiftUI
import WidgetKit

/// The control under Innstillinger > Handlingsknapp > Kontroller, and in Kontrollsenter: one press runs `ToggleRecordingIntent`.
/// A button, not a toggle: state would need an app group, which SECURITY.md rules out; the Live Activity already shows it.
/// The symbol is SF: the system draws a control's image and takes symbols only.
struct RecordingControl: ControlWidget {
    static let kind = "com.Tazk.Frodi.record"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ToggleRecordingIntent()) {
                Label("Opptak", systemImage: "mic.fill")
            }
        }
        .displayName("Start eller stopp opptak")
        .description("Starter et opptak i Fróði eller stopper det som går.")
    }
}
