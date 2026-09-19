import AVFoundation
import Observation

/// Plays a recording.
///
/// The audio is decrypted into memory, never to disk. `AudioStorage.withDecrypted`
/// puts the plaintext in a temporary file, which is right for export and for
/// transcription, but would leave the whole recording unlocked on disk for as
/// long as playback lasts. `AVAudioPlayer(data:)` avoids that entirely.
@MainActor
@Observable
final class AudioPlayer {
    /// Shared, because the microphone and the speaker share one audio session. A
    /// recording started with the Action Button must be able to stop playback first.
    static let shared = AudioPlayer()

    enum State: Equatable {
        case idle
        case loading
        case ready
        case playing
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    /// Which recording is loaded. File name, not path, for the same reason as in `Recording`.
    private(set) var fileName: String?

    private var player: AVAudioPlayer?
    private var ticker: Task<Void, Never>?

    private init() {}

    var isPlaying: Bool { state == .playing }

    var isLoaded: Bool { state == .ready || state == .playing }

    // MARK: - Load
    /// Unlocks the recording and readies it for playback. Does nothing if it is
    /// already loaded.
    func prepare(_ recording: Recording) async {
        guard fileName != recording.fileName else { return }
        stop()

        state = .loading
        let name = recording.fileName
        fileName = name

        do {
            // The decryption bypasses the main actor. A long recording is tens of
            // megabytes, and the interface must not freeze meanwhile.
            let audio = try await Task.detached(priority: .userInitiated) {
                try AudioStorage.plaintext(fileName: name)
            }.value

            let newPlayer = try AVAudioPlayer(data: audio)
            newPlayer.prepareToPlay()
            player = newPlayer
            duration = newPlayer.duration
            currentTime = 0
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Controls
    func togglePlayback() {
        guard let player else { return }
        if player.isPlaying { pause() } else { Task { await play() } }
    }

    func pause() {
        guard let player, player.isPlaying else { return }
        player.pause()
        currentTime = player.currentTime
        stopTicker()
        state = .ready
    }

    /// Moves playback. Values outside the recording are clamped to the ends.
    func seek(to time: TimeInterval) {
        guard let player else { return }
        let clamped = min(max(time, 0), player.duration)
        player.currentTime = clamped
        currentTime = clamped
    }

    func skip(_ offset: TimeInterval) {
        guard let player else { return }
        seek(to: player.currentTime + offset)
    }

    /// Releases both the audio and the audio session. Called when the detail page
    /// closes, and before a new recording starts.
    func stop() {
        stopTicker()
        player?.stop()
        player = nil
        fileName = nil
        currentTime = 0
        duration = 0
        state = .idle
        deactivateSession()
    }

    // MARK: - Body
    private func play() async {
        guard let player else { return }

        do {
            // spokenAudio treats speech better than default. playback, not
            // playAndRecord: playback must not ask for the microphone. Activation
            // is asynchronous, as Xcode asks: on the main thread it blocks.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            guard try await session.activate(options: []) else {
                state = .failed(String(localized: "Fikk ikke startet avspillingen."))
                return
            }
        } catch {
            state = .failed(String(localized: "Fikk ikke startet avspillingen."))
            return
        }

        guard player.play() else {
            state = .failed(String(localized: "Fikk ikke startet avspillingen."))
            return
        }

        state = .playing
        startTicker()
    }

    private func startTicker() {
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, let player = self.player else { return }
                if player.isPlaying {
                    self.currentTime = player.currentTime
                } else {
                    self.finish()
                    return
                }
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    /// The recording has finished playing. `AVAudioPlayer` has a delegate for this,
    /// but it is called off the main actor; the ticker knows the same 100 ms later.
    private func finish() {
        stopTicker()
        player?.currentTime = 0
        currentTime = 0
        state = .ready
        deactivateSession()
    }

    private func deactivateSession() {
        Task { _ = try? await AVAudioSession.sharedInstance().deactivate(options: .notifyOthersOnDeactivation) }
    }
}
