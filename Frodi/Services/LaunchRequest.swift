import Observation

/// Signal fra App Intent til appen: start et opptak så snart appen er oppe.
///
/// En delt instans er nødvendig her fordi intenten kjører uten tilgang til
/// SwiftUI-hierarkiet. Den holder én bool og ingen logikk.
@MainActor
@Observable
final class LaunchRequest {
    static let shared = LaunchRequest()

    var shouldStartRecording = false

    private init() {}
}
