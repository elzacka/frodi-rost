import SwiftUI
import WidgetKit

/// The two surfaces the app has outside its own window: the control the Action
/// Button is set to, and the Live Activity that stands for a running recording.
/// No home screen widget; there is nothing to show when nothing is recording.
@main
struct FrodiWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RecordingControl()
        RecordingLiveActivity()
    }
}
