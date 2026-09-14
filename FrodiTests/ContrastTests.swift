import SwiftUI
import Testing
import UIKit
@testable import Frodi

/// WCAG 2.2 AA is a requirement, not a goal: 4.5:1 for ordinary text, 3:1 for
/// icons and other graphical elements.
///
/// The test exists because the fault sat there for half a year without being
/// seen. `TextSecondary` was at 3.92:1 against surface, which looks right on
/// screen and is impossible to spot by eye. Only arithmetic catches it.
@Suite("Kontrast")
struct ContrastTests {
    /// Relative luminance as WCAG defines it.
    static func luminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func channel(_ value: CGFloat) -> Double {
            let v = Double(value)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    static func ratio(_ foreground: String, on background: String) throws -> Double {
        let front = try #require(UIColor(named: foreground), "Fant ikke fargen \(foreground)")
        let back = try #require(UIColor(named: background), "Fant ikke fargen \(background)")
        let a = luminance(front), b = luminance(back)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Everything that is text in the app, on both surfaces text can sit on.
    @Test("Tekst når 4,5:1", arguments: [
        ("TextPrimary", "Background"),
        ("TextPrimary", "Surface"),
        ("TextSecondary", "Background"),
        ("TextSecondary", "Surface"),
        ("AccentRecordOn", "AccentRecord")
    ])
    func textMeetsAA(pair: (foreground: String, background: String)) throws {
        let measured = try Self.ratio(pair.foreground, on: pair.background)
        #expect(
            measured >= 4.5,
            "\(pair.foreground) på \(pair.background) er \(String(format: "%.2f", measured)):1, WCAG 2.2 AA krever 4,5:1"
        )
    }

    /// Icons, borders and surfaces that carry meaning without text.
    ///
    /// The accent is here because `.tint` colours the back button, the export icon
    /// and the player slider: icons with no text beside them. The border is here
    /// because it is the edge around cards and rows, and the dividers in the header
    /// and above the recorder bar.
    ///
    /// One pair is deliberately left out: the record button's change from
    /// accent-record to recording-active is 1.50:1. Colour is not the only signal.
    /// The icon switches from `mic.fill` to `stop.fill`, the timer starts, and the
    /// VoiceOver label changes. See dev_only/CLAUDE.md.
    @Test("Grafiske element når 3:1", arguments: [
        ("RecordingActive", "Background"),
        ("Surface", "RecordingActive"),
        ("AccentRecord", "Background"),
        ("AccentRecord", "Surface"),
        ("BorderNeutral", "Background"),
        ("BorderNeutral", "Surface")
    ])
    func graphicsMeetAA(pair: (foreground: String, background: String)) throws {
        let measured = try Self.ratio(pair.foreground, on: pair.background)
        #expect(
            measured >= 3.0,
            "\(pair.foreground) på \(pair.background) er \(String(format: "%.2f", measured)):1, WCAG 2.2 AA krever 3:1"
        )
    }

    /// The footnote has to read as quieter than the text it belongs to, and the
    /// difference has to be visible. It was not: the footnote used to be
    /// `TextSecondary` at 0.9 opacity on running text that was `TextSecondary`
    /// itself, which is 1,24:1 between the two. Nobody sees 1,24:1.
    ///
    /// Running text is `TextPrimary` now and the footnote is `TextSecondary`,
    /// which measures 2,88:1 between them. The ratio is a stand-in for «visibly
    /// lighter», not a WCAG requirement: the rules say nothing about two text
    /// colours on the same surface. 2,5 is the floor, so the tones can be tuned
    /// without the step quietly disappearing again.
    ///
    /// Each tone meets AA on its own: both pairs are in `textMeetsAA` above, and
    /// `TextSecondary` on `Surface` is the footnote's own number, 5,65:1.
    @Test("Fotnoten skiller seg synlig fra brødteksten")
    func footnoteIsVisiblyLighterThanBody() throws {
        let measured = try Self.ratio("TextSecondary", on: "TextPrimary")
        #expect(
            measured >= 2.5,
            "Fotnoten mot brødteksten er \(String(format: "%.2f", measured)):1, skillet må være minst 2,5:1"
        )
    }
}
