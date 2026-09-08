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

    /// Ikoner, kanter og flater som bærer betydning uten tekst.
    ///
    /// Aksenten står her fordi `.tint` farger tilbakeknappen, uthentingsikonet
    /// og skyveknappen i avspilleren – ikoner uten tekst ved siden av seg.
    /// Kanten står her fordi den er grensen rundt kort og rader, og
    /// skillelinjene i hodet og over opptaksfeltet.
    ///
    /// Ett par står med vilje utenfor: opptaksknappens skifte fra accent-record
    /// til recording-active er 1,50:1. Fargen er ikke det eneste signalet.
    /// Ikonet bytter fra `mic.fill` til `stop.fill`, timeren starter, og
    /// VoiceOver-etiketten endrer seg. Se dev_only/CLAUDE.md.
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
}
