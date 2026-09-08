import AVFoundation

/// Lydkvittering for at opptaket startet eller stoppet.
///
/// I bil ligger telefonen flatt på ladeplaten, utenfor synsfeltet, og appen
/// kjører i bakgrunnen. Da er lyd eneste kanal igjen: du ser ikke
/// grensesnittet, og haptikk virker ikke fra bakgrunnen.
///
/// Tonene spilles gjennom appens egen lydøkt, ikke som systemlyd. Det er det
/// som gjør at de følger ruten til bilhøyttaleren over Bluetooth, og at de
/// ikke forsvinner om telefonen står på lydløs.
///
/// Den som kaller må ha en aktiv lydøkt. Kvitteringen setter ingen kategori
/// selv – å bytte kategori rundt hver tone ville gitt et rutebytte og et hakk
/// i lyden hver gang.
@MainActor
enum RecordingCue {
    /// Stigende. Opptaket går.
    case started
    /// Fallende. Opptaket er stoppet.
    case stopped
    /// Lav og lengre. Ingenting ble tatt opp.
    case failed

    /// Spiller kvitteringen og venter til den er ferdig.
    ///
    /// Ventingen er ikke høflighet: startkvitteringen må være ferdig før
    /// mikrofonen åpnes, ellers ligger pipetonen i opptaket.
    func play() async {
        guard let player = try? AVAudioPlayer(data: Self.wav(for: self)) else { return }

        // Holdes i live her. En lokal variabel kan slippes mens vi venter.
        Self.player = player
        player.prepareToPlay()
        guard player.play() else { return }

        try? await Task.sleep(for: .seconds(player.duration))
    }

    private static var player: AVAudioPlayer?

    private static let sampleRate = 44_100.0

    /// Toner som skiller seg fra hverandre uten at du ser skjermen: start går
    /// opp, stopp går ned, feil ligger lavt og varer lenger.
    private var tones: [(frequency: Double, seconds: Double)] {
        switch self {
        case .started: [(880, 0.10), (1318.5, 0.10)]
        case .stopped: [(1318.5, 0.10), (880, 0.10)]
        case .failed: [(392, 0.18), (294, 0.26)]
        }
    }

    /// Bygger tonen som WAV i minnet. Internal, ikke private, så testene kan
    /// slå fast at det faktisk kommer lyd ut.
    static func wav(for cue: RecordingCue) -> Data {
        // Litt stillhet først, så lydøkta rekker å komme i gang før tonen.
        // Uten den blir starten av den første pipen kuttet.
        var samples = [Int16](repeating: 0, count: Int(0.04 * sampleRate))

        for tone in cue.tones {
            let count = Int(tone.seconds * sampleRate)
            let attack = Int(0.008 * sampleRate)
            let release = Int(0.025 * sampleRate)

            for index in 0..<count {
                // Opp og ned igjen. En tone som starter eller slutter brått
                // knepper, og et knepp høres ut som en feil.
                let envelope = if index < attack {
                    Double(index) / Double(attack)
                } else if index > count - release {
                    Double(count - index) / Double(release)
                } else {
                    1.0
                }

                let angle = 2 * .pi * tone.frequency * Double(index) / sampleRate
                samples.append(Int16(sin(angle) * envelope * 0.6 * Double(Int16.max)))
            }
        }

        return riff(samples)
    }

    /// Minste mulige WAV: én kanal, 16 bit, ingen ekstra chunks.
    private static func riff(_ samples: [Int16]) -> Data {
        var data = Data()
        func append(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        func append(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        func append(_ text: String) {
            data.append(contentsOf: Array(text.utf8))
        }

        let byteCount = UInt32(samples.count * 2)
        let rate = UInt32(sampleRate)

        append("RIFF")
        append(36 + byteCount)
        append("WAVE")

        append("fmt ")
        append(UInt32(16))      // lengden på fmt-blokken
        append(UInt16(1))       // PCM, ukomprimert
        append(UInt16(1))       // mono
        append(rate)
        append(rate * 2)        // byte per sekund
        append(UInt16(2))       // byte per ramme
        append(UInt16(16))      // bit per prøve

        append("data")
        append(byteCount)
        for sample in samples { append(UInt16(bitPattern: sample)) }

        return data
    }
}
