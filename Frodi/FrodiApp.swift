import SwiftData
import SwiftUI
import UIKit

@main
struct FrodiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
                .readsConcealment()
                // The design system defines light mode only.
                .preferredColorScheme(.light)
                .tint(Color.Frodi.accentRecord)
        }
        .modelContainer(container)
    }
}

/// Apple's keyboard only: a keyboard from another company, given Full Access, can send what is typed, and names are typed here.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier
    ) -> Bool {
        extensionPointIdentifier != .keyboard
    }
}
