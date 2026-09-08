import Foundation

/// Hvor lydfilene ligger, og hvordan de beskyttes.
///
/// To ting styres herfra, og de trekker i hver sin retning:
/// opptaket må kunne skrives mens skjermen er låst, og den ferdige filen skal
/// ikke kunne leses mens skjermen er låst.
enum AudioStorage {
    static var directory: URL {
        let base = URL.documentsDirectory.appendingPathComponent("Opptak", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(
                at: base,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]
            )
        }
        // Settes hver gang, ikke bare ved opprettelse. Flagget kan bli
        // nullstilt av filoperasjoner, og en mappe laget av en tidligere
        // versjon har det ikke i det hele tatt.
        excludeFromBackup(base)
        return base
    }

    /// Beskyttelse mens opptaket går.
    ///
    /// `completeUnlessOpen` lar en fil som allerede er åpen bli skrevet videre
    /// etter at skjermen låses. Med `complete` ville opptaket stoppet i det
    /// telefonen låste seg – altså nøyaktig i bilen, som er hele poenget.
    static func protectWhileRecording(_ url: URL) {
        setProtection(.completeUnlessOpen, on: url)
    }

    /// Beskyttelse etter at opptaket er ferdig.
    ///
    /// Nå er filen lukket, og da er `complete` riktig: innholdet kan ikke leses
    /// mens telefonen er låst, heller ikke av noe som har fysisk tilgang.
    static func protectFinished(_ url: URL) {
        setProtection(.complete, on: url)
        excludeFromBackup(url)
    }

    /// Kjører en jobb med opptaket midlertidig dekryptert.
    ///
    /// Klarteksten lever bare så lenge jobben varer, i mappen for
    /// midlertidige filer, og slettes uansett hvordan jobben ender.
    static func withDecrypted<T>(
        fileName: String,
        _ body: (URL) async throws -> T
    ) async throws -> T {
        let sealed = try Data(contentsOf: directory.appendingPathComponent(fileName))
        let plaintext = try RecordingVault.open(sealed)

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".m4a")
        try plaintext.write(to: temporary, options: [.completeFileProtectionUnlessOpen])
        defer { try? FileManager.default.removeItem(at: temporary) }

        return try await body(temporary)
    }

    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }

    private static func setProtection(_ level: FileProtectionType, on url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: level],
            ofItemAtPath: url.path
        )
    }

    /// Holder opptakene utenfor iCloud-sikkerhetskopien.
    ///
    /// Apple kaller dette veiledning til systemet, ikke en garanti, og flagget
    /// kan bli nullstilt av filoperasjoner. Vi setter det derfor på nytt hver
    /// gang en fil er ferdig. Vil du ha en garanti, må innholdet krypteres med
    /// en nøkkel som ikke finnes utenfor denne telefonen.
    private static func excludeFromBackup(_ url: URL) {
        var target = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? target.setResourceValues(values)
    }
}
