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

    /// Starter opptak. Returnerer false hvis mikrofonen ikke er tilgjengelig.
    @discardableResult
    func start() async -> Bool {
        guard state != .recording else { return true }

        guard await AVAudioApplication.requestRecordPermission() else {
            state = .denied
            return false
        }

        do {
            let session = AVAudioSession.sharedInstance()
            // spokenAudio gir bedre behandling av tale enn default, og
            // playAndRecord lar oss spille av uten å bytte kategori etterpå.
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

    /// Stopper opptaket og gir tilbake filnavn og lengde.
    func stop() -> (fileName: String, duration: TimeInterval)? {
        guard let recorder, state == .recording else { return nil }

        let length = recorder.currentTime
        recorder.stop()
        stopTicker()
        self.recorder = nil
        state = .idle
        duration = 0

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        // Et opptak uten lyd i er ikke verdt en rad i listen.
        guard length >= 0.5 else {
            AudioStorage.delete(fileName: recorder.url.lastPathComponent)
            return nil
        }

        // Filen er lukket nå. Den forsegles med en nøkkel som bare finnes i
        // denne enhetens Secure Enclave, og klarteksten slettes.
        do {
            let sealed = try RecordingVault.seal(fileAt: recorder.url)
            let name = recorder.url.lastPathComponent + ".enc"
            let target = AudioStorage.directory.appendingPathComponent(name)
            try sealed.write(to: target, options: [.completeFileProtection])
            try? FileManager.default.removeItem(at: recorder.url)
            AudioStorage.protectFinished(target)
            return (name, length)
        } catch {
            // Klarer vi ikke å kryptere, beholder vi ikke klarteksten liggende.
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
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }
}
