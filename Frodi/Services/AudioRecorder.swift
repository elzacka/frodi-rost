import AVFoundation
import Observation
import OSLog

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

    /// True while a call, Siri or another app holds the microphone. The recording is
    /// paused, not stopped, and continues on its own when the interruption ends.
    private(set) var isInterrupted = false

    private var recorder: AVAudioRecorder?

    /// The file being written right now, so a pass over the folder can leave it
    /// alone. Set before the file exists: the recorder creates it before `record()`
    /// answers, and a pass in that moment must not take it for an orphan.
    private(set) var currentFileName: String?

    private var ticker: Task<Void, Never>?
    private var observers: [any NSObjectProtocol] = []

    var isRecording: Bool { state == .recording }

    /// Called when an interruption ends without the recording being able to go on:
    /// iOS said not to resume, or the audio system was reset underneath us. What is
    /// on disk is complete and must be saved, the same way as after a press on stop.
    var onInterruptionEnded: (() -> Void)?

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

        guard await AVAudioApplication.requestRecordPermission() else {
            state = .denied
            return false
        }

        do {
            let session = AVAudioSession.sharedInstance()
            // spokenAudio treats speech better than default, and playAndRecord lets us
            // play back without switching category afterwards.
            //
            // Non-mixable on purpose: other audio pauses while recording and resumes
            // after, so music does not end up in the recording. It also means the
            // session cannot be activated from the background ('!int'), but that
            // buys nothing to give up: a recording cannot be started from the
            // background at all, see `ToggleRecordingIntent`.
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
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
                // What iOS answers when an app tries to begin recording in the
                // background: cannotStartRecording, reported here as false. The
                // session is active and the recorder may have created the file;
                // both are cleaned up, or the next launch would find an empty
                // recording and other apps' audio would stay interrupted.
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
            isInterrupted = false
            state = .recording
            observeInterruptions()
            startTicker()
            return true
        } catch {
            Self.log.error("Recording did not start: \(error, privacy: .public)")
            currentFileName = nil
            state = .failed(String(localized: "Fikk ikke tilgang til mikrofonen."))
            return false
        }
    }

    /// Makes the recorder and starts it, off the main actor. `started` is
    /// false when iOS refuses to start recording.
    ///
    /// `record()` activates the session on its own, synchronously, even when it
    /// is already active, and Xcode flags that as a hang risk on the main thread.
    /// Measured 2026-09-19 with a probe around each step.
    ///
    /// The recorder comes back even when it did not start, so that it is
    /// released on the main actor and not on this thread. A device crashed on
    /// 2026-09-19 with an Objective-C weak-reference fatal right after
    /// `record()` had returned false here; the same failure released on the
    /// main thread on 2026-09-16 and did not. Suspected, not proven: the
    /// simulator cannot make `record()` fail the way a device does.
    ///
    /// Linear PCM in a CAF container, not AAC in an MPEG-4 one. Measured on
    /// 2026-09-14: an app killed mid-recording leaves an `.m4a` that cannot be
    /// opened at all, because the index is written at close. CAF with AAC opens
    /// but has no packets, for the same reason. Only PCM has no table to write,
    /// so a kill at any point leaves every frame playable. The file is about
    /// 115 MB an hour, and `AudioStorage.seal` turns it into AAC once the
    /// recording is finished.
    @concurrent
    private static func startRecorder(at url: URL) async throws -> sending (recorder: AVAudioRecorder, started: Bool) {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        return (recorder, recorder.record())
    }

    /// Stops the recording and returns the file name and length.
    ///
    /// The length is read from the file, not from the recorder. `currentTime` is
    /// zero once the recorder has stopped, and it stops by itself after an
    /// interruption or a reset of the audio system. The file is the truth either
    /// way.
    ///
    /// Nothing is deleted here. A recording is the user's, and the only thing that
    /// removes one is the user asking for it. A file with no frames at all is not
    /// a recording and is the one exception; a file that cannot be opened is not
    /// that file, see `savedDuration`.
    func stop() -> (fileName: String, duration: TimeInterval)? {
        guard let recorder, state == .recording else { return nil }

        // What the recorder counted, taken before it stops and forgets. The ticker's
        // copy covers a recorder the audio system has already invalidated.
        let counted = max(recorder.currentTime, duration)

        recorder.stop()
        stopTicker()
        stopObserving()
        self.recorder = nil
        currentFileName = nil
        state = .idle
        duration = 0
        isInterrupted = false

        // Off the main thread, and nothing here waits for it: the length is read
        // from the file, which the session has no say in.
        Task { _ = try? await AVAudioSession.sharedInstance().deactivate(options: .notifyOthersOnDeactivation) }

        let fileName = recorder.url.lastPathComponent
        let measured = AudioStorage.duration(fileName: fileName)
        guard let length = Self.savedDuration(measured: measured, counted: counted) else {
            Self.log.notice("Recording stopped: \(fileName, privacy: .public) is empty, deleted")
            AudioStorage.delete(fileName: fileName)
            return nil
        }
        Self.log.notice("Recording stopped: \(fileName, privacy: .public), measured \(measured.map { String($0) } ?? "unreadable", privacy: .public) s, counted \(counted, privacy: .public) s")

        // The file is closed now, and stays `.completeUnlessOpen` until
        // `Transcription.run` seals it. Sealing is not done here: it has to read the
        // closed file back, and that fails while the device is locked, which is
        // exactly when the Action Button stops a recording in the car. It used to
        // be done here, and the failure deleted the recording.
        return (fileName, length)
    }

    /// The length to save, or nil when the file is empty and should go.
    ///
    /// `measured` is the file's own length, nil when the file could not be opened.
    /// The two are not the same case. A closed `.completeUnlessOpen` file cannot be
    /// reopened while the device is locked, which is where a recording stops
    /// whenever the Action Button stops it in the car, or an interruption ends
    /// without the microphone coming back. Until 2026-09-15 nil was treated
    /// as empty, and the recording was deleted. Now the recorder's own count stands
    /// in; the file replaces it when it is sealed, if it is still zero. Only a file
    /// that opened and holds no frames is deleted.
    nonisolated static func savedDuration(measured: TimeInterval?, counted: TimeInterval) -> TimeInterval? {
        guard let measured else { return counted }
        return measured > 0 ? measured : nil
    }

    /// A call, Siri, an alarm or another app taking the microphone.
    ///
    /// iOS pauses the recorder by itself when the interruption begins. What the app
    /// has to do is continue when it ends, and save when it cannot. Without this
    /// the recorder stayed paused, the screen still said «recording», and the next
    /// press on stop read a length of zero. Everything said before the call was
    /// then deleted as too short.
    private func observeInterruptions() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        // iOS 27 split the old interruption notification in two: the session going
        // inactive, with who did it, and the system's advice on resuming once the
        // interruption is over. `stop()` deactivates the session itself; that one
        // carries `.app` and is not an interruption.
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

    private func interruptionBegan(source: AVAudioSession.DeactivationSource?) {
        guard state == .recording, let recorder, source != .app else { return }
        Self.log.notice("Interruption began at \(recorder.currentTime, privacy: .public) s")
        recorder.pause()
        isInterrupted = true
    }

    private func interruptionEnded(recommendation: AVAudioSession.ResumptionRecommendation?) async {
        guard state == .recording, let recorder, isInterrupted else { return }
        isInterrupted = false
        let shouldResume = recommendation == .shouldResume
        var resumed = false
        if shouldResume, (try? await AVAudioSession.sharedInstance().activate(options: [])) == true {
            // The activation took time, and a stop can have landed meanwhile.
            // Then the recorder is closed and its file is being saved, and a
            // `record()` on it would open the file again and write over it.
            guard state == .recording, self.recorder === recorder else { return }
            resumed = recorder.record()
        }
        Self.log.notice("Interruption ended, shouldResume \(shouldResume, privacy: .public), resumed \(resumed, privacy: .public)")
        if !resumed { onInterruptionEnded?() }
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
                guard let self, let recorder = self.recorder else { return }
                // Frozen while paused: `currentTime` holds across a pause, and the
                // display should say so rather than keep counting.
                if !self.isInterrupted { self.duration = recorder.currentTime }
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }
}
