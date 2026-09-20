import SwiftData
import SwiftUI

@main
struct FrodiApp: App {
    private let container: ModelContainer

    init() {
        // If the disk fails, fall back to memory so the app still records. The user
        // is told that recordings will not survive a restart, instead of the app
        // crashing at launch.
        var failed = false
        var resolved: ModelContainer
        do {
            resolved = try ModelContainer(for: Recording.self)
            AudioStorage.excludeFromBackup(store: resolved)
        } catch {
            failed = true
            let memoryOnly = ModelConfiguration(isStoredInMemoryOnly: true)
            // If even this fails, there is nothing left to save.
            resolved = try! ModelContainer(for: Recording.self, configurations: memoryOnly)
        }
        container = resolved
        RecordingController.shared.attach(container: resolved, storageFailed: failed)
    }

    var body: some Scene {
        WindowGroup {
            RecordingListView()
                // The design system defines light mode only.
                .preferredColorScheme(.light)
                .tint(Color.Frodi.accentRecord)
        }
        .modelContainer(container)
    }
}
