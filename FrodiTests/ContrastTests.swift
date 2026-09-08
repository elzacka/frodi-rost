import Testing
import UIKit
@testable import Frodi

/// WCAG 2.2 AA er et krav, ikke et mål: 4,5:1 for vanlig tekst, 3:1 for ikoner
/// og andre grafiske element.
///
/// Testen finnes fordi feilen var der i et halvt år uten å bli sett.
/// `TextSecondary` lå på 3,92:1 mot surface, som ser riktig ut på skjermen og
/// er umulig å oppdage med øyet. Bare et regnestykke fanger den.
@Suite("Kontrast")
struct ContrastTests {
    /// Relativ luminans slik WCAG definerer den.
    private static func luminance(_ color: UIColor) -> Double {
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

    /// Alt som er tekst i appen, på begge flatene tekst kan ligge på.
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

    /// Ikoner og flater som bærer betydning uten tekst. Opptaksknappen fylles
    /// med `recording-active` mens den tar opp, og ikonet oppå er surface.
    ///
    /// `accent-record` mot background står ikke her. Den er 2,02:1, og det er
    /// ikke flaten som sier at knappen er en knapp — det gjør mikrofonikonet
    /// oppå, som er 5,47:1. Tallet er notert i dev_only/CLAUDE.md som et åpent
    /// designspørsmål, ikke gjemt bort her.
    @Test("Grafiske element når 3:1", arguments: [
        ("RecordingActive", "Background"),
        ("Surface", "RecordingActive")
    ])
    func graphicsMeetAA(pair: (foreground: String, background: String)) throws {
        let measured = try Self.ratio(pair.foreground, on: pair.background)
        #expect(
            measured >= 3.0,
            "\(pair.foreground) på \(pair.background) er \(String(format: "%.2f", measured)):1, WCAG 2.2 AA krever 3:1"
        )
    }
}
