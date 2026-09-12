import AVFoundation
import Observation

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

    private var recorder: AVAudioRecorder?
    private var ticker: Task<Void, Never>?

    var isRecording: Bool { state == .recording }

    /// How much of the limit is left. The countdown in the recorder bar reads this,
    /// so the user sees the end coming instead of being caught by it.
    var remaining: TimeInterval { max(RecordingLimit.duration - duration, 0) }

    /// Called when the recording has reached the limit and must be saved.
    ///
    /// The recorder does not save; `RecordingController` does, and only it knows
    /// about the database. Hence a closure here rather than the recorder learning
    /// about saving.
    var onLimitReached: (() -> Void)?

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
            try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)

            let name = "\(UUID().uuidString).m4a"
            let url = AudioStorage.directory.appendingPathComponent(name)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            guard newRecorder.record() else {
                state = .failed(String(localized: "Fikk ikke startet opptaket."))
                return false
            }

            AudioStorage.protectWhileRecording(url)
            recorder = newRecorder
            duration = 0
            state = .recording
            startTicker()
            return true
        } catch {
            state = .failed(String(localized: "Fikk ikke tilgang til mikrofonen."))
            return false
        }
    }

    /// Stops the recording and returns the file name and length.
    func stop() -> (fileName: String, duration: TimeInterval)? {
        guard let recorder, state == .recording else { return nil }

        let length = recorder.currentTime
        recorder.stop()
        stopTicker()
        self.recorder = nil
        state = .idle
        duration = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // A recording with no audio in it is not worth a row in the list.
        guard length >= 0.5 else {
            AudioStorage.delete(fileName: recorder.url.lastPathComponent)
            return nil
        }

        // The file is closed now. It is sealed with a key that exists only in this
        // device's Secure Enclave, and the plaintext is deleted.
        do {
            let sealed = try RecordingVault.seal(fileAt: recorder.url)
            let name = recorder.url.lastPathComponent + ".enc"
            let target = AudioStorage.directory.appendingPathComponent(name)
            try sealed.write(to: target, options: [.completeFileProtection])
            try? FileManager.default.removeItem(at: recorder.url)
            AudioStorage.protectFinished(target)
            return (name, length)
        } catch {
            // If we cannot encrypt, we do not leave the plaintext lying around.
            try? FileManager.default.removeItem(at: recorder.url)
            state = .failed(String(localized: "Fróði fikk ikke låst opptaket, og slettet det."))
            return nil
        }
    }

    private func startTicker() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, let recorder = self.recorder else { return }
                self.duration = recorder.currentTime

                // The recording stops itself at the limit. The countdown has shown it
                // coming, so this is no surprise.
                //
                // The stop must happen here, while the recording is still running: `stop()`
                // reads the length from `recorder.currentTime`, and that is zero as soon as
                // the recording has stopped. Had we let AVAudioRecorder stop itself with
                // `record(forDuration:)`, the length would have been zero and the recording
                // discarded as too short.
                if self.duration >= RecordingLimit.duration {
                    self.onLimitReached?()
                    return
                }
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }
}
