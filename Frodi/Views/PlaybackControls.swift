import SwiftUI

/// Avspilling av ett opptak: spill av og pause, hopp femten sekunder hver vei,
/// og en slider som både viser og setter posisjonen.
struct PlaybackControls: View {
    let recording: Recording
    let player: AudioPlayer

    /// Hvor langt hoppknappene flytter seg. Oppførsel, ikke et designtoken.
    private static let skipSeconds: TimeInterval = 15

    /// Holder fingerens posisjon mens du drar. Uten den rykker knappen tilbake
    /// hver gang tikkeren oppdaterer avspillingstiden.
    @State private var scrub: TimeInterval?

    var body: some View {
        VStack(spacing: Space.s4) {
            if case .failed(let message) = player.state {
                Text(message)
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textSecondary)
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
        .task { await player.prepare(recording) }
        .onDisappear { player.stop() }
    }

    // MARK: - Posisjon

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

            // VoiceOver leser posisjonen fra slideren over, så de to tallene
            // her ville bare blitt sagt to ganger til.
            HStack(spacing: Space.s2) {
                Text(clock(displayTime))
                Spacer(minLength: Space.s2)
                Text("−" + clock(max(player.duration - displayTime, 0)))
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

    /// En slider med området 0...0 er udefinert, så et tomt opptak får et sekund.
    private var sliderRange: TimeInterval {
        max(player.duration, 1)
    }

    private var displayTime: TimeInterval {
        scrub ?? player.currentTime
    }

    // MARK: - Knapper

    private var buttons: some View {
        HStack(spacing: Space.s6) {
            skipButton(
                -Self.skipSeconds,
                symbol: "gobackward.15",
                label: "Hopp 15 sekunder tilbake"
            )

            playButton

            skipButton(
                Self.skipSeconds,
                symbol: "goforward.15",
                label: "Hopp 15 sekunder fram"
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

                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: PlayerControl.playIcon, weight: .medium))
                    .foregroundStyle(Color.Frodi.accentRecordOn)
                    // Trekanten har tyngdepunktet til venstre for midten og ser
                    // skjev ut i en sirkel uten denne. Optisk retting, ikke avstand.
                    .offset(x: player.isPlaying ? 0 : 2)
            }
        }
        .buttonStyle(.plain)
        .disabled(!player.isLoaded)
        .accessibilityLabel(player.isPlaying ? "Pause" : "Spill av")
        .accessibilityAddTraits(.isButton)
    }

    private func skipButton(_ offset: TimeInterval, symbol: String, label: String) -> some View {
        Button {
            player.skip(offset)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: PlayerControl.skipIcon, weight: .medium))
                .foregroundStyle(Color.Frodi.textPrimary)
                .frame(width: PlayerControl.skip, height: PlayerControl.skip)
        }
        .buttonStyle(.plain)
        .disabled(!player.isLoaded)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Tekst

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
