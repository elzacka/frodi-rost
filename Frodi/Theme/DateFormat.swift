import Foundation

extension Date {
    /// Datoen slik den vises på et opptak: 07.09.26, 00:53
    ///
    /// Ett sted, slik at listen og detaljvisningen ikke kan komme i utakt.
    /// Året er med fordi opptak blir liggende, og «7. sep.» sier ingenting om
    /// hvilket år det var når mappen har vokst.
    var recordingStamp: String {
        Self.stampFormatter.string(from: self)
    }

    private static let stampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "nb_NO")
        formatter.dateFormat = "dd.MM.yy, HH:mm"
        return formatter
    }()
}
