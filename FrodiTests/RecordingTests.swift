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

    @Test("hasTranscript følger om teksten er forseglet")
    func hasTranscriptTracksSealedText() throws {
        let recording = Recording(duration: 1, fileName: "a.m4a.enc")
        #expect(recording.hasTranscript == false)

        try recording.setTranscript("hei")
        #expect(recording.hasTranscript == true)
        #expect(try recording.transcript() == "hei")
    }
}
