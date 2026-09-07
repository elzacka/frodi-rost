import AVFoundation
import Observation

/// Spiller av et opptak.
///
/// Lyden dekrypteres til minnet, aldri til disk. `AudioStorage.withDecrypted`
/// legger klarteksten i en midlertidig fil, som er riktig for eksport og for
/// transkribering, men ville latt hele opptaket ligge ulåst på disken så lenge
/// avspillingen varer. `AVAudioPlayer(data:)` slipper det helt.
@MainActor
@Observable
final class AudioPlayer {
    /// Delt, fordi mikrofonen og høyttaleren deler samme lydøkt. Et opptak som
    /// startes med handlingsknappen må kunne stanse avspillingen først.
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

    /// Hvilket opptak som ligger klart. Filnavn, ikke sti — samme grunn som i `Recording`.
    private(set) var fileName: String?

    private var player: AVAudioPlayer?
    private var ticker: Task<Void, Never>?

    private init() {}

    var isPlaying: Bool { state == .playing }

    var isLoaded: Bool { state == .ready || state == .playing }

    // MARK: - Last inn

    /// Låser opp opptaket og gjør det klart til avspilling. Gjør ingenting hvis
    /// det alt ligger klart.
    func prepare(_ recording: Recording) async {
        guard fileName != recording.fileName else { return }
        stop()

        state = .loading
        fileName = recording.fileName
        let url = recording.fileURL

        do {
            // Dekrypteringen går utenom hovedaktøren. Et langt opptak er noen
            // titalls megabyte, og grensesnittet skal ikke stå stille imens.
            let audio = try await Task.detached(priority: .userInitiated) {
                try RecordingVault.open(try Data(contentsOf: url))
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

    // MARK: - Kontroller

    func togglePlayback() {
        guard let player else { return }
        if player.isPlaying { pause() } else { play() }
    }

    func pause() {
        guard let player, player.isPlaying else { return }
        player.pause()
        currentTime = player.currentTime
        stopTicker()
        state = .ready
    }

    /// Flytter avspillingen. Verdier utenfor opptaket klippes til endene.
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

    /// Slipper både lyden og lydøkta. Kalles når detaljsiden lukkes, og før et
    /// nytt opptak starter.
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

    // MARK: - Innmat

    private func play() {
        guard let player else { return }

        do {
            // spokenAudio gir tale bedre behandling enn default. playback, ikke
            // playAndRecord: avspilling skal ikke be om mikrofonen.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
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

    /// Opptaket er spilt ferdig. `AVAudioPlayer` har en delegat for dette, men
    /// den kalles utenfor hovedaktøren; tikkeren vet det samme 100 ms senere.
    private func finish() {
        stopTicker()
        player?.currentTime = 0
        currentTime = 0
        state = .ready
        deactivateSession()
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
