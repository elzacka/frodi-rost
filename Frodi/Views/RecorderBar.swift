import SwiftUI

struct RecorderBar: View {
    let controller: RecordingController

    private var recorder: AudioRecorder { controller.recorder }

    var body: some View {
        VStack(spacing: Space.s3) {
            // Tallene står ved siden av knappen, ikke over den. Over knappen
            // ble feltet så høyt at listen med opptak forsvant bak det.
            //
            // Begge sidene tar like mye plass, så knappen står midt på skjermen
            // uansett hvor brede tallene er.
            HStack(spacing: Space.s4) {
                timer
                    .frame(maxWidth: .infinity, alignment: .leading)

                recordButton

                remaining
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if case .denied = recorder.state {
                Text("Fróði trenger tilgang til mikrofonen. Du gir tilgang i Innstillinger.")
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.s4)
            }
        }
        .padding(.horizontal, Space.s5)
        .padding(.vertical, Space.s4)
        .frame(maxWidth: .infinity)
        .background(Color.Frodi.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.Frodi.border)
                .frame(height: 1)
        }
    }

    /// Holder plassen sin også i hvile, ellers flytter knappen seg i det opptaket starter.
    private var timer: some View {
        Text(recorder.isRecording ? elapsed : " ")
            .font(.Frodi.timer)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(Color.Frodi.textPrimary)
            .contentTransition(.numericText())
            .accessibilityLabel("Tid gått")
            .accessibilityValue(spoken(recorder.duration))
            .accessibilityHidden(!recorder.isRecording)
    }

    /// Hva som er igjen av grensen, og hva grensen er før du har begynt.
    ///
    /// Den står til høyre for knappen, der speilingen av timeren sto før.
    /// Plassen var alt satt av, og to tall på hver sin side av knappen leses
    /// som det de er: det som har gått, og det som står igjen.
    ///
    /// Minustegnet er det samme som avspilleren bruker om gjenværende tid, og
    /// er det som skiller de to tallene fra hverandre uten en etikett.
    private var remaining: some View {
        Group {
            if recorder.isRecording {
                Text(verbatim: "−" + clock(recorder.remaining))
                    .font(.Frodi.bodyMedium)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityLabel("Tid igjen av opptaket")
                    .accessibilityValue(spoken(recorder.remaining))
            } else {
                Text("inntil \(RecordingLimit.minutes) min")
                    .font(.Frodi.caption)
                    .accessibilityLabel("Et opptak kan vare i inntil \(RecordingLimit.minutes) minutter")
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .foregroundStyle(Color.Frodi.textSecondary)
    }

    private var recordButton: some View {
        Button(action: toggle) {
            ZStack {
                Circle()
                    .strokeBorder(ringColor, lineWidth: RecordButton.ring)
                    .frame(width: RecordButton.diameter, height: RecordButton.diameter)

                Circle()
                    .fill(innerColor)
                    .frame(width: RecordButton.inner, height: RecordButton.inner)

                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: RecordButton.icon, weight: .medium))
                    .foregroundStyle(iconColor)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recorder.isRecording ? "Stopp opptak" : "Start opptak")
        .accessibilityAddTraits(.isButton)
    }

    private var elapsed: String {
        clock(recorder.duration)
    }

    private func clock(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }

    /// «2 minutter, 5 sekunder» – tallet skrevet ut, slik avspilleren gjør det.
    private func spoken(_ seconds: TimeInterval) -> String {
        let units = Duration.UnitsFormatStyle(allowedUnits: [.minutes, .seconds], width: .wide)
        return Duration.seconds(seconds).formatted(units)
    }

    private var ringColor: Color {
        recorder.state == .denied ? Color.Frodi.border : Color.Frodi.accentRecord
    }

    /// Avslått tilgang gir en tom knapp, ikke en fylt grå.
    ///
    /// Fyllet var border-fargen. Da border ble mørk nok til å være en synlig
    /// kant, ble den fylte knappen mørkere enn den aktive og leste som slått
    /// på. En kontur sier «ingenting her» uten å rope.
    private var innerColor: Color {
        switch recorder.state {
        case .recording: Color.Frodi.recordingActive
        case .denied: Color.Frodi.surface
        default: Color.Frodi.accentRecord
        }
    }

    private var iconColor: Color {
        switch recorder.state {
        case .recording: Color.Frodi.surface
        case .denied: Color.Frodi.textSecondary
        default: Color.Frodi.accentRecordOn
        }
    }

    private func toggle() {
        Task { await controller.toggle() }
    }
}
