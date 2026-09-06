import Foundation

/// Hvor lydfilene ligger. Ett sted, så resten av appen slipper å vite det.
enum AudioStorage {
    static var directory: URL {
        let base = URL.documentsDirectory.appendingPathComponent("Opptak", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }

    /// Filbeskyttelse på hver enkelt fil. Opptak kan inneholde hva som helst,
    /// og skal ikke kunne leses mens telefonen er låst.
    static func protect(_ url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: url.path
        )
    }

    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }
}
