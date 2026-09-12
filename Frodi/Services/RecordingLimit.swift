import Foundation

/// How long a recording can be, and how much text it becomes.
///
/// The limit exists because memory sets it. nb-whisper grows with the length of
/// the recording, about 60 MB per minute of audio on top of the 400 MB the model
/// itself takes. Measured on the simulator on 9 September 2026, ten minutes went
/// through at 1 130 MB while fifteen minutes was killed. Without a limit it is not
/// the recording that stops but the transcription afterwards, and then the text
/// is lost without anyone saying so.
///
/// Ten minutes is the longest length measured all the way through. The number
/// lives here alone, and everything else is computed from it: the sentence on the
/// Info page, the countdown in the recorder bar and the stop in `AudioRecorder`.
/// To change the limit, change this line.
///
/// **The ceiling has not been measured on a device.** The Neural Engine has a
/// different memory profile from the simulator, and a 4 GB device has less headroom
/// than the Mac. If recordings get killed on a device, this is the number to lower.
enum RecordingLimit {
    static let duration: TimeInterval = 10 * 60

    static var minutes: Int { Int(duration / 60) }

    /// Words are the unit the app already counts in: the detail view says «114 ord».
    ///
    /// 170 words a minute is measured, not assumed: 512 words in 3 minutes and
    /// 1 683 in 10. That is fast speech, so the number is a ceiling, not an
    /// estimate. Say less per minute and you get less text.
    static var words: Int { minutes * 170 }

    /// A number written in Norwegian, with a hard space as the thousands separator.
    ///
    /// The locale is pinned to Bokmål here for the same reason as in `AppLocale`: a
    /// device set to English must still show Norwegian text.
    static func formatted(_ number: Int) -> String {
        number.formatted(.number.locale(AppLocale.norwegian))
    }
}
