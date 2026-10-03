import Foundation

/// «Tekstmodus». Enkel is the text alone; Avansert adds who said what (speaker diarization).
enum TextMode: String {
    case enkel
    case avansert

    static let key = "textMode"

    nonisolated static var current: TextMode {
        UserDefaults.standard.string(forKey: key).flatMap(TextMode.init(rawValue:)) ?? .enkel
    }
}
