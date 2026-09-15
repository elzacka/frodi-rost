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

    /// The file being written right now, so a pass over the folder can leave it alone.
    var currentFileName: String? { recorder?.url.lastPathComponent }

    private var ticker: Task<Void, Never>?
    private var observers: [any NSObjectProtocol] = []

    var isRecording: Bool { state == .recording }

    /// Called when an interruption ends without the recording being able to go on:
    /// iOS said not to resume, or the audio system was reset underneath us. What is
    /// on disk is complete and must be saved, the same way as after a press on stop.
    var onInterruptionEnded: (() -> Void)?

    /// Events only, never content: when a recording starts and stops, and what
    /// interrupted it. The 19 minute recording lost on 14 September 2026 left no
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
            // duckOthers is what lets the Action Button start a recording with the
            // device locked. A non-mixable session cannot be activated from the
            // background: setActive(true) fails with '!int', cannotInterruptOthers,
            // and the intent then has to open the app, which on a locked device
            // means Face ID. Seen on a device on 16 September 2026. A mixable
            // session may activate in the background, and ducking lowers whatever
            // else is playing instead of stopping it.
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers]
            )
            try session.setActive(true)

            let name = "\(UUID().uuidString).caf"
            let url = AudioStorage.directory.appendingPathComponent(name)

            // Linear PCM in a CAF container, not AAC in an MPEG-4 one. Measured on
            // 14 September 2026: an app killed mid-recording leaves an `.m4a` that
            // cannot be opened at all, because the index is written at close. CAF
            // with AAC opens but has no packets, for the same reason. Only PCM has
            // no table to write, so a kill at any point leaves every frame playable.
            // The file is about 115 MB an hour, and `AudioStorage.seal` turns it
            // into AAC once the recording is finished.
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: Self.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]

            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            guard newRecorder.record() else {
                Self.log.error("Recording did not start: record() returned false")
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
            state = .failed(String(localized: "Fikk ikke tilgang til mikrofonen."))
            return false
        }
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
        state = .idle
        duration = 0
        isInterrupted = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

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
    /// without the microphone coming back. Until 15 September 2026 nil was treated
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

        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let info = notification.userInfo
            let type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt)
                .flatMap { AVAudioSession.InterruptionType(rawValue: $0) }
            let options = (info?[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map { AVAudioSession.InterruptionOptions(rawValue: $0) }
            Task { @MainActor in self?.interruption(type, options: options ?? []) }
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

    private func interruption(_ type: AVAudioSession.InterruptionType?, options: AVAudioSession.InterruptionOptions) {
        guard state == .recording, let recorder else { return }

        switch type {
        case .began:
            Self.log.notice("Interruption began at \(recorder.currentTime, privacy: .public) s")
            recorder.pause()
            isInterrupted = true
        case .ended:
            isInterrupted = false
            let resumed = options.contains(.shouldResume)
                && (try? AVAudioSession.sharedInstance().setActive(true)) != nil
                && recorder.record()
            Self.log.notice("Interruption ended, shouldResume \(options.contains(.shouldResume), privacy: .public), resumed \(resumed, privacy: .public)")
            if !resumed { onInterruptionEnded?() }
        default:
            Self.log.error("Interruption notification without a type")
        }
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
