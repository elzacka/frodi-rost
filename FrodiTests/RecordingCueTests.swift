import Foundation
import Testing
@testable import Frodi

@Suite("RecordingCue")
@MainActor
struct RecordingCueTests {
    private let cues: [RecordingCue] = [.started, .stopped, .failed]

    @Test("kvitteringen er en gyldig WAV som AVAudioPlayer kan lese")
    func buildsValidWav() {
        for cue in cues {
            let data = RecordingCue.wav(for: cue)
            #expect(data.prefix(4) == Data("RIFF".utf8))
            #expect(data[8..<12] == Data("WAVE".utf8))

            // Lengden i headeren må stemme med det som faktisk ligger der,
            // ellers spiller AVAudioPlayer bare deler av tonen.
            let declared = data[4..<8].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
            #expect(Int(declared) == data.count - 8)
        }
    }

    @Test("det kommer faktisk lyd ut, ikke stillhet")
    func tonesAreAudible() {
        for cue in cues {
            let data = RecordingCue.wav(for: cue)
            let samples = data.dropFirst(44)
            let peak = stride(from: 0, to: samples.count - 1, by: 2).map { offset -> Int16 in
                let index = samples.startIndex + offset
                return Int16(bitPattern: UInt16(samples[index]) | UInt16(samples[index + 1]) << 8)
            }.map { abs(Int($0)) }.max() ?? 0

            // Godt over stillhet, godt under klipping.
            #expect(peak > 10_000)
            #expect(peak < Int(Int16.max))
        }
    }

    @Test("start, stopp og feil høres forskjellige ut")
    func cuesAreDistinct() {
        let rendered = cues.map { RecordingCue.wav(for: $0) }
        #expect(Set(rendered).count == cues.count)
    }

    @Test("kvitteringen er kort nok til å ikke være i veien")
    func staysShort() {
        for cue in cues {
            // 44 byte header, 16 bit mono ved 44,1 kHz.
            let seconds = Double(RecordingCue.wav(for: cue).count - 44) / 2 / 44_100
            #expect(seconds > 0.1)
            #expect(seconds < 0.6)
        }
    }
}
