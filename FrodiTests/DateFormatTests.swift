import Foundation
import Testing
@testable import Frodi

@Suite("Datoformat")
struct DateFormatTests {
    private func date(_ iso: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Europe/Oslo")
        formatter.formatOptions = [.withInternetDateTime]
        return try #require(formatter.date(from: iso))
    }

    @Test("Vises som dd.MM.yy, HH:mm")
    func usesNorwegianShortFormat() throws {
        let stamp = try date("2026-09-07T00:53:00+02:00").recordingStamp
        #expect(stamp == "07.09.26, 00:53")
    }

    /// Dagen skal ha ledende null, ellers hopper kolonnen i listen.
    @Test("Ledende null på dag og måned")
    func padsSingleDigits() throws {
        #expect(try date("2026-01-05T09:07:00+01:00").recordingStamp == "05.01.26, 09:07")
    }

    /// 24-timers klokke uansett hva telefonen står på. Et opptak klokka 13
    /// og ett klokka 01 skal ikke se like ut.
    @Test("24-timers klokke")
    func usesTwentyFourHourClock() throws {
        #expect(try date("2026-09-07T13:05:00+02:00").recordingStamp == "07.09.26, 13:05")
    }
}
