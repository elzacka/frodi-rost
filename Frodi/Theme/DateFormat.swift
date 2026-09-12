import Foundation

extension Date {
    /// The date as shown on a recording: 07.09.26, 00:53
    ///
    /// One place, so the list and the detail view cannot drift apart. The year is
    /// included because recordings stay around, and «7. sep.» says nothing about
    /// which year it was once the folder has grown.
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
