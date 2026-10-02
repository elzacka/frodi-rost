import Foundation

/// Fróði transcribes Norwegian Bokmål and nothing else.
/// Deliberately hardcoded, not `Locale.current`: with the device in English the app must still produce Bokmål.
/// `nb` is Bokmål; `nn` is Nynorsk and must never be used here.
enum AppLocale {
    static let norwegian = Locale(identifier: "nb-NO")

    /// Is this Bokmål? `nb` and the older `no` are accepted, `nn` never.
    static func isBokmal(_ locale: Locale) -> Bool {
        guard let code = locale.language.languageCode?.identifier.lowercased() else { return false }
        return code == "nb" || code == "no"
    }
}
