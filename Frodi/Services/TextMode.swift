import Foundation

/// «Tekstmodus». Enkel is the text alone; Avansert adds who said what (speaker diarization).
enum TextMode: String {
    case enkel
    case avansert

    static let key = "textMode"

    var label: String {
        switch self {
        case .enkel: "Enkel"
        case .avansert: "Avansert"
        }
    }

    nonisolated static var current: TextMode {
        UserDefaults.standard.string(forKey: key).flatMap(TextMode.init(rawValue:)) ?? .enkel
    }
}
