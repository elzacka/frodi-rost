import Foundation

/// Henter ut et opptak for videre behandling.
///
/// Eksport er en bevisst handling, ikke en åpen dør. Filene ligger kryptert til
/// vanlig, og låses opp bare i det øyeblikket du ber om det. Klarteksten legges
/// i mappen for midlertidige filer og ryddes bort etter deling.
///
/// Delingen går gjennom iOS' egen delingsmeny, som lar deg velge Filer på
/// enheten eller AirDrop. Begge er lokale. Fróði laster ingenting opp selv,
/// og har ingen nettverkskode å gjøre det med.
enum RecordingExport {
    /// Skriver lyd og tekst til midlertidige filer klare for deling.
    static func prepare(_ recording: Recording) async throws -> [URL] {
        var urls: [URL] = []

        let stamp = Self.stamp(recording.createdAt)
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("Eksport-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let sealed = try Data(contentsOf: recording.fileURL)
        let audio = folder.appendingPathComponent("frodi-\(stamp).m4a")
        try RecordingVault.open(sealed).write(to: audio, options: [.completeFileProtectionUnlessOpen])
        urls.append(audio)

        if let transcript = try recording.transcript(), !transcript.isEmpty {
            let text = folder.appendingPathComponent("frodi-\(stamp).txt")
            try utf8WithBOM(transcript).write(to: text, options: [.completeFileProtectionUnlessOpen])
            urls.append(text)
        }

        return urls
    }

    /// Skriver teksten som UTF-8 med byte order mark.
    ///
    /// Uten BOM gjetter mange lesere at en `.txt` er Latin-1, og da blir «så»
    /// til «sÃ¥». Filen er UTF-8 uansett; de tre bytene forteller leseren det.
    static func utf8WithBOM(_ text: String) -> Data {
        Data([0xEF, 0xBB, 0xBF]) + Data(text.utf8)
    }

    /// Rydder bort klarteksten etter at delingen er ferdig.
    static func cleanUp(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }

    private static func stamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        formatter.locale = Locale(identifier: "nb_NO")
        return formatter.string(from: date)
    }
}
