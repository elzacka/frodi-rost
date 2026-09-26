import SwiftUI

/// Playback of one recording: play and pause, skip ten seconds either way,
/// and a slider that both shows and sets the position.
struct PlaybackControls: View {
    let recording: Recording
    let player: AudioPlayer

    @State private var controller = RecordingController.shared

    /// How far the skip buttons move. Behaviour, not a design token. Internal
    /// so `IconTests` can hold it to the number drawn inside the skip icons.
    static let skipSeconds: TimeInterval = 10

    /// Holds the finger's position while you drag. Without it the knob jumps back
    /// every time the ticker updates the playback time.
    @State private var scrub: TimeInterval?

    var body: some View {
        VStack(spacing: Space.s4) {
            if case .failed(let message) = player.state {
                Text(verbatim: message)
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                position
                buttons
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Space.s4)
        .background(Color.Frodi.surface, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.Frodi.border, lineWidth: 1)
        )
        // Not while a recording runs: readying the player sets the session to
        // playback, which has no input, and the microphone would go out from
        // under the recorder. The page opens with the controls disabled, and
        // the player is readied when the recording stops.
        .task(id: controller.isRecording) {
            guard !controller.isRecording else { return }
            await player.prepare(recording)
        }
        .onDisappear { Task { await player.stop() } }
    }

    // MARK: - Position
    private var position: some View {
        VStack(spacing: Space.s1) {
            Slider(value: sliderValue, in: 0...sliderRange) { editing in
                guard !editing, let scrub else { return }
                player.seek(to: scrub)
                self.scrub = nil
            }
            .tint(Color.Frodi.accentRecord)
            .disabled(!player.isLoaded)
            .accessibilityLabel("Posisjon i opptaket")
            .accessibilityValue(spokenPosition)

            // VoiceOver reads the position from the slider above, so the two numbers
            // here would only be said twice more.
            HStack(spacing: Space.s2) {
                Text(verbatim: clock(displayTime))
                Spacer(minLength: Space.s2)
                Text(verbatim: "−" + clock(max(player.duration - displayTime, 0)))
            }
            .font(.Frodi.meta)
            .monospacedDigit()
            .foregroundStyle(Color.Frodi.textSecondary)
            .accessibilityHidden(true)
        }
    }

    private var sliderValue: Binding<TimeInterval> {
        Binding(get: { displayTime }, set: { scrub = $0 })
    }

    /// A slider with the range 0...0 is undefined, so an empty recording gets one second.
    private var sliderRange: TimeInterval {
        max(player.duration, 1)
    }

    private var displayTime: TimeInterval {
        scrub ?? player.currentTime
    }

    // MARK: - Buttons
    private var buttons: some View {
        HStack(spacing: Space.s6) {
            skipButton(
                -Self.skipSeconds,
                icon: .skipBack,
                label: "Hopp 10 sekunder tilbake"
            )

            playButton

            skipButton(
                Self.skipSeconds,
                icon: .skipForward,
                label: "Hopp 10 sekunder frem"
            )
        }
    }

    private var playButton: some View {
        Button {
            player.togglePlayback()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.Frodi.accentRecord)
                    .frame(width: PlayerControl.play, height: PlayerControl.play)

                IconView(player.isPlaying ? .pause : .play, size: PlayerControl.playIcon)
                    .foregroundStyle(Color.Frodi.accentRecordOn)
            }
        }
        .buttonStyle(.plain)
        .disabled(!player.isLoaded)
        .accessibilityLabel(player.isPlaying ? "Pause" : "Spill av")
        .accessibilityAddTraits(.isButton)
    }

    /// The arrow says the direction, the number inside it says how far.
    ///
    /// The number is part of the glyph, so `skipSeconds` and the icons are held
    /// together by `IconTests`, not by the layout: change one, change the other.
    private func skipButton(_ offset: TimeInterval, icon: Icon, label: String) -> some View {
        Button {
            player.skip(offset)
        } label: {
            IconView(icon, size: PlayerControl.skipIcon)
                .foregroundStyle(Color.Frodi.textPrimary)
                .frame(width: PlayerControl.skip, height: PlayerControl.skip)
        }
        .buttonStyle(.plain)
        .disabled(!player.isLoaded)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Text
    private func clock(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }

    private var spokenPosition: String {
        let units = Duration.UnitsFormatStyle(allowedUnits: [.minutes, .seconds], width: .wide)
        let at = Duration.seconds(displayTime).formatted(units)
        let total = Duration.seconds(player.duration).formatted(units)
        return "\(at) av \(total)"
    }
}
