import Foundation
import Testing
@testable import Frodi

@Suite("Recording")
struct RecordingTests {
    @Test("fileURL bygges fra filnavn, ikke fra en lagret absolutt sti")
    func fileURLDerivesFromFileName() {
        let recording = Recording(duration: 12, fileName: "abc.m4a")
        #expect(recording.fileURL.lastPathComponent == "abc.m4a")
        #expect(recording.fileURL.path.contains("Opptak"))
    }

    @Test("hasTranscript er false for tom tekst")
    func emptyTranscriptCountsAsMissing() {
        let recording = Recording(duration: 1, fileName: "a.m4a")
        #expect(recording.hasTranscript == false)
        recording.transcript = ""
        #expect(recording.hasTranscript == false)
        recording.transcript = "hei"
        #expect(recording.hasTranscript == true)
    }
}
