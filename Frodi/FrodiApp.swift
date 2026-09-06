import SwiftData
import SwiftUI

@main
struct FrodiApp: App {
    // Broen mellom App Intent og appen. Handlingsknappen kjører intenten
    // før noen view finnes, så flagget må ligge et sted begge når.
    @State private var launchRequest = LaunchRequest.shared

    var body: some Scene {
        WindowGroup {
            RecordingListView()
                .environment(launchRequest)
        }
        .modelContainer(for: Recording.self)
    }
}
