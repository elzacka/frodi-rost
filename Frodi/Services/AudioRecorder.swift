import AVFoundation
import Observation
import OSLog
import UIKit

@MainActor
@Observable
final class AudioRecorder {
    enum State: Equatable {
        case idle
        case recording
        case denied
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var duration: TimeInterval = 0

    /// True while a call, Siri or another app holds the microphone. The recording
    /// waits, and goes on by itself in a new file when the interruption ends.
    private(set) var isInterrupted = false

    /// The recorder of the current segment. Nil while interrupted: iOS stops it,
    /// and it is not reused, see `interruptionBegan`.
    private var recorder: AVAudioRecorder?

    /// The length of the segments closed by interruptions so far. The recorder's
    /// `currentTime` counts the current segment alone.
    private var completed: TimeInterval = 0

    /// How many files the recording is in so far; names the next one.
    private var segments = 0

    /// The file being written right now, so a pass over the folder can leave it
    /// alone. Set before the file exists: the recorder creates it before `record()`
    /// answers, and a pass in that moment must not take it for an orphan.
    private(set) var currentFileName: String?

    private var ticker: Task<Void, Never>?
    private var observers: [any NSObjectProtocol] = []

    /// The session given up after a stop; the next start waits for it.
    /// A deactivation still in flight lands between activation and `record()`, which then fails
    /// (device, 2026-09-20; the player's deactivation is the same call on the same session).
    private var deactivation: Task<Void, Never>?

    var isRecording: Bool { state == .recording }

    /// Called when an interruption ends without the recording being able to go on:
    /// iOS said not to resume, or the audio system was reset underneath us. What is
    /// on disk is complete and must be saved, the same way as after a press on stop.
    var onInterruptionEnded: (() -> Void)?

    /// Called with true when an interruption pauses the recording, and with false
    /// when it goes on. `duration` is up to date at both calls.
    var onInterruptionChanged: ((Bool) -> Void)?

    /// Events only, never content: when a recording starts and stops, and what
    /// interrupted it. The 19 minute recording lost on 2026-09-14 left no
    /// trace of why, and the system's own lines did not say either.
    nonisolated static let log = Logger(subsystem: "com.Tazk.Frodi", category: "recording")

    /// The sample rate of the file on disk. What the speech model hears, and enough
    /// for speech: 8 kHz of bandwidth is wideband telephony.
    nonisolated static let sampleRate: Double = 16_000

    /// Starts recording. Returns false if the microphone is not available.
    @discardableResult
    func start() async -> Bool {
        guard state != .recording else { return true }

        await deactivation?.value

        guard await AVAudioApplication.requestRecordPermission() else {
            state = .denied
            return false
        }

        do {
            let session = AVAudioSession.sharedInstance()
            let inBackground = Self.inBackground
            Self.log.notice("Starting, in background: \(inBackground, privacy: .public)")
            try Self.setCategory(inBackground: inBackground)
            // Asynchronous, as Xcode asks: activation waits for the audio daemon
            // and blocks the main thread when called on it.
            guard try await session.activate(options: []) else {
                Self.log.error("Recording did not start: the session was not activated")
                state = .failed(String(localized: "Fikk ikke tilgang til mikrofonen."))
                return false
            }

            let name = "\(UUID().uuidString).caf"
            let url = AudioStorage.directory.appendingPathComponent(name)
            currentFileName = name

            let (newRecorder, started) = try await Self.startRecorder(at: url)
            guard started else {
                // iOS refuses to begin recording in the background (cannotStartRecording, reported as false). The session is active and
                // the file may exist: clean up both, or the next launch finds an empty recording and other apps' audio stays interrupted.
                Self.log.error("Recording did not start: record() returned false")
                _ = try? await session.deactivate(options: .notifyOthersOnDeactivation)
                try? FileManager.default.removeItem(at: url)
                currentFileName = nil
                state = .failed(String(localized: "Fikk ikke startet opptaket."))
                return false
            }
            Self.log.notice("Recording started: \(name, privacy: .public)")

            AudioStorage.protectWhileRecording(url)
            recorder = newRecorder
            duration = 0
            completed = 0
            segments = 1
            isInterrupted = false
            state = .recording
            observeInterruptions()
            startTicker()
            return true
        } catch {
            Self.log.error("Recording did not start: \(error, privacy: .public)")
            // The session may be active by now, and a ducking one would keep
            // other audio low until the next stop.
            _ = try? await AVAudioSession.sharedInstance().deactivate(options: .notifyOthersOnDeactivation)
            currentFileName = nil
            state = .failed(String(localized: "Fikk ikke tilgang til mikrofonen."))
            return false
        }
    }

    private static var inBackground: Bool { UIApplication.shared.applicationState == .background }

    /// spokenAudio suits speech; playAndRecord allows playback without a category switch.
    /// Non-mixable in the foreground, so other audio pauses and stays out of the recording. From the background iOS refuses it ('!int'),
    /// also for `AudioRecordingIntent` (device 2026-09-26; simulator allows it); there it ducks others (mixable). A resume chooses again.
    private static func setCategory(inBackground: Bool) throws {
        var options: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothHFP]
        if inBackground { options.insert(.duckOthers) }
        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .spokenAudio, options: options)
    }

    /// Returns when the session a stop gave up is released. The control's intent waits for it: iOS may suspend the app once
    /// the intent returns and a release in flight never happens, leaving music ducked by a background start low.
    func sessionReleased() async {
        await deactivation?.value
    }

    /// Starts the recorder off the main actor (`record()` activates the session synchronously: hang risk); `started` false if refused
    /// Returned even unstarted, to release it on the main actor: off-main release crashed a device (ObjC weak-ref; suspected).
    /// PCM CAF, not AAC: after a kill m4a/CAF-AAC are unplayable (index at close). ~115 MB/h; `seal` makes AAC
    @concurrent
    private static func startRecorder(at url: URL) async throws -> sending (recorder: AVAudioRecorder, started: Bool) {
        let recorder = try AVAudioRecorder(url: url, settings: fileSettings)
        return (recorder, recorder.record())
    }

    /// The format of a recording until it is sealed. `AudioImport` writes an
    /// imported file in the same one, so the two are the same thing on disk.
    nonisolated static var fileSettings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
    }

    /// Stops the recording and returns the file name and length.
    /// Length is read from the file: `currentTime` is zero once stopped, also after an interruption or audio reset. Nothing is deleted
    /// (only the user removes a recording) except a file with no frames; an unopenable file is not that, see `savedDuration`.
    func stop() -> (fileName: String, duration: TimeInterval)? {
        guard state == .recording, let fileName = currentFileName else { return nil }

        // What the recorder counted, taken before it stops and forgets. The ticker's
        // copy covers a recorder the audio system has already invalidated, and
        // there is no recorder at all while a call is on.
        let counted = max(completed + (recorder?.currentTime ?? 0), duration)

        recorder?.stop()
        stopTicker()
        stopObserving()
        recorder = nil
        currentFileName = nil
        state = .idle
        duration = 0
        isInterrupted = false

        // Off the main thread, and nothing here waits for it: the length is read
        // from the file, which the session has no say in. The next start does.
        deactivation = Task { _ = try? await AVAudioSession.sharedInstance().deactivate(options: .notifyOthersOnDeactivation) }

        let measured = AudioStorage.duration(fileName: fileName)
        guard let length = Self.savedDuration(measured: measured, counted: counted) else {
            Self.log.notice("Recording stopped: \(fileName, privacy: .public) is empty, deleted")
            AudioStorage.delete(fileName: fileName)
            return nil
        }
        Self.log.notice("Recording stopped: \(fileName, privacy: .public), measured \(measured.map { String($0) } ?? "unreadable", privacy: .public) s, counted \(counted, privacy: .public) s")

        // File stays `.completeUnlessOpen` until `Transcription.run` seals it. Not sealed here: sealing reads the closed file back,
        // which fails while the device is locked (Action Button stop in the car); the unlock pass seals it instead.
        return (fileName, length)
    }

    /// The length to save, or nil when the file is empty and should go. `measured` is nil when the file could not be opened.
    /// A closed `.completeUnlessOpen` file cannot be reopened while locked (Action Button stop, interruption ending), so the
    /// recorder's count stands in until seal replaces it, if still zero. Only an opened file with no frames is deleted.
    nonisolated static func savedDuration(measured: TimeInterval?, counted: TimeInterval) -> TimeInterval? {
        guard let measured else { return counted }
        return measured > 0 ? measured : nil
    }

    /// A call, Siri, an alarm or another app taking the microphone. iOS stops the recorder itself; the app must continue when it
    /// ends and save when it cannot. Otherwise the screen says «recording» on a stopped recorder and stop reads length zero,
    /// deleting everything said before the call as too short.
    private func observeInterruptions() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        // iOS 27 splits the interruption notification in two: the session going inactive (with who did it) and the system's resume
        // advice. `stop()` deactivates the session itself; that one carries `.app` and is not an interruption.
        observers.append(center.addObserver(
            forName: AVAudioSession.didBecomeInactiveNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let context = notification.userInfo?[AVAudioSession.deactivationContextKey]
                as? AVAudioSession.DeactivationContext
            Task { @MainActor in self?.interruptionBegan(source: context?.source) }
        })

        observers.append(center.addObserver(
            forName: AVAudioSession.resumptionRecommendationNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let context = notification.userInfo?[AVAudioSession.resumptionContextKey]
                as? AVAudioSession.ResumptionContext
            Task { @MainActor in await self?.interruptionEnded(recommendation: context?.recommendation) }
        })

        // The audio daemon restarted. Every recorder is invalid after this, and there
        // is no resuming; the file on disk is intact and gets saved.
        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Self.log.error("Media services were reset while recording")
            Task { @MainActor in self?.onInterruptionEnded?() }
        })
    }

    /// Closes the segment; the recorder is not paused or reused: iOS already stopped it, and `record()` on a stopped
    /// `AVAudioRecorder` restarts its file (device 2026-09-20: 21 s, call, resume, 44 s more gave a 44 s file). The recording so far
    /// is a finished file; the resume goes on in the next, and `AudioStorage.seal` joins them.
    private func interruptionBegan(source: AVAudioSession.DeactivationSource?) {
        guard state == .recording, let recorder, source != .app else { return }
        let position = recorder.currentTime
        Self.log.notice("Interruption began at \(self.completed + position, privacy: .public) s")
        recorder.stop()
        self.recorder = nil
        completed += position
        duration = completed
        isInterrupted = true
        onInterruptionChanged?(true)
    }

    private func interruptionEnded(recommendation: AVAudioSession.ResumptionRecommendation?) async {
        guard state == .recording, isInterrupted, let fileName = currentFileName else { return }
        isInterrupted = false
        let shouldResume = recommendation == .shouldResume
        let inBackground = Self.inBackground
        var resumed = false
        if shouldResume, (try? Self.setCategory(inBackground: inBackground)) != nil,
           (try? await AVAudioSession.sharedInstance().activate(options: [])) == true,
           state == .recording, currentFileName == fileName {
            let name = AudioStorage.continuationName(for: fileName, index: segments)
            let url = AudioStorage.directory.appendingPathComponent(name)
            if let next = try? await Self.startRecorder(at: url) {
                // Each activation took time, and a stop can have landed meanwhile.
                // Then the recording is being saved without this file, and the
                // recorder just made must not go on writing it.
                if next.started, state == .recording, currentFileName == fileName {
                    AudioStorage.protectWhileRecording(url)
                    recorder = next.recorder
                    segments += 1
                    resumed = true
                } else {
                    next.recorder.stop()
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        Self.log.notice("Interruption ended, shouldResume \(shouldResume, privacy: .public), in background \(inBackground, privacy: .public), resumed \(resumed, privacy: .public)")
        if resumed { onInterruptionChanged?(false) } else { onInterruptionEnded?() }
    }

    private func stopObserving() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
    }

    private func startTicker() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self else { return }
                // Frozen while interrupted: there is no recorder then, and the
                // display should say so rather than keep counting.
                if let recorder = self.recorder { self.duration = self.completed + recorder.currentTime }
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }
}
