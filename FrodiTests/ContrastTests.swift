import SwiftUI
import Testing
import UIKit
@testable import Frodi

/// WCAG 2.2 AA is a requirement: 4.5:1 for ordinary text, 3:1 for icons and graphical elements.
///
/// Only arithmetic catches faults: `TextSecondary` sat at 3.92:1 against surface, which looks right on screen.
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

    /// Icons, borders and surfaces that carry meaning without text: the accent (`.tint`: back button, export icon, player slider) and the border.
    /// Left out deliberately: record button accent-record to recording-active, 1.50:1. Colour is not the only signal: icon mic.fill to
    /// stop.fill, timer starts, VoiceOver label changes. See dev_only/DECISIONS.md.
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

    /// Secondary text must read visibly quieter than running text (`TextPrimary` vs `TextSecondary`, 2,88:1 apart). The ratio stands in for
    /// «visibly lighter», not a WCAG rule; 2,5 is the floor so tuning cannot make the step vanish. Each tone meets AA alone: see `textMeetsAA`.
    @Test("Sekundær tekst skiller seg synlig fra brødteksten")
    func secondaryIsVisiblyLighterThanBody() throws {
        let measured = try Self.ratio("TextSecondary", on: "TextPrimary")
        #expect(
            measured >= 2.5,
            "Sekundær tekst mot brødteksten er \(String(format: "%.2f", measured)):1, skillet må være minst 2,5:1"
        )
    }
}
