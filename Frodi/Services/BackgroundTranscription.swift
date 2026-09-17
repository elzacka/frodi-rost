import BackgroundTasks
import OSLog
import SwiftData

/// Transcription while the device sits locked on the charger.
///
/// An hour of interview takes the device a long time at full load. Rather than
/// leave the app open for it, the user plugs the device in, and iOS runs this
/// task when the device is charging and idle. The task picks up whatever is
/// waiting: short recordings without text and long ones the user has asked
/// for, each from where it left off. When iOS calls time, the run stops at the
/// next piece and the rest waits for the next window.
///
/// What makes it possible is that the sealed audio and the key are usable
/// after the first unlock since boot; see `AudioStorage.protectFinished` and
/// `RecordingVault.createKey`. On a device whose key was created by a build
/// that used the stricter class, the open fails quietly and the task ends
/// with nothing done; the transcription then runs when the app is next open.
@MainActor
enum BackgroundTranscription {
    nonisolated static let identifier = "com.Tazk.Frodi.transcribe"
    nonisolated static let log = Logger(subsystem: "com.Tazk.Frodi", category: "transcription")

    /// Must run before the app has finished launching, so it is called from the
    /// app's initialiser.
    static func register(container: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            nonisolated(unsafe) let task = task
            Task { @MainActor in await run(task, container: container) }
        }
    }

    /// Asks for a run the next time the device is charging. Called when the app
    /// goes to the background, and again at the end of a run that left work.
    /// Nothing is asked for when nothing is waiting.
    static func schedule(context: ModelContext) {
        guard hasPendingWork(context) else { return }
        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresExternalPower = true
        request.requiresNetworkConnectivity = false
        Task {
            do {
                try await BGTaskScheduler.shared.submitTaskRequest(request)
            } catch {
                // Refused, not queued. The reason is what a charger run that never
                // happened would need: not permitted, too many pending, unavailable.
                log.error("Could not schedule transcription: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static func hasPendingWork(_ context: ModelContext) -> Bool {
        let recordings = (try? context.fetch(FetchDescriptor<Recording>())) ?? []
        return recordings.contains {
            !$0.hasTranscript && $0.failureCode != "empty" && !Transcription.awaitsRequest($0)
        }
    }

    private static func run(_ task: BGTask, container: ModelContainer) async {
        let context = container.mainContext
        task.expirationHandler = {
            Task { @MainActor in Transcription.stop() }
        }
        await Transcription.runPending(context: context)
        task.setTaskCompleted(success: true)
        schedule(context: context)
    }
}
