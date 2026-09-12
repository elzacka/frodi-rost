import SwiftData
import SwiftUI

@main
struct FrodiApp: App {
    private let container: ModelContainer

    init() {
        // Feiler disken, faller vi tilbake til minnet slik at appen fortsatt tar
        // opp. Brukeren får beskjed om at opptakene ikke overlever omstart, i
        // stedet for at appen kræsjer ved oppstart.
        var failed = false
        var resolved: ModelContainer
        do {
            resolved = try ModelContainer(for: Recording.self)
            AudioStorage.excludeFromBackup(store: resolved)
        } catch {
            failed = true
            let memoryOnly = ModelConfiguration(isStoredInMemoryOnly: true)
            // Klarer vi ikke engang dette, er det ingenting igjen å redde.
            resolved = try! ModelContainer(for: Recording.self, configurations: memoryOnly)
        }
        container = resolved
        RecordingController.shared.attach(container: resolved, storageFailed: failed)
    }

    var body: some Scene {
        WindowGroup {
            RecordingListView()
                // Designsystemet definerer kun lys modus.
                .preferredColorScheme(.light)
                .tint(Color.Frodi.accentRecord)
        }
        .modelContainer(container)
    }
}
