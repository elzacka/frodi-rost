import Foundation
import Testing
@testable import Frodi

/// The published documents and the app make the same claims. Each claim used
/// to be written in two places with nothing binding them, which is how copies
/// drift. These tests read the documents from the repository, so they run on
/// the Mac the simulator runs on, like `IsolationTests`.
@MainActor
@Suite("Dokumentene og appen sier det samme")
struct DocumentTests {
    private static let root = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// Lines, with table cells trimmed to one space around each pipe, so a
    /// formatter that pads the columns does not change what a row says.
    private static func document(_ name: String) throws -> [Substring] {
        try String(contentsOf: root.appending(path: name), encoding: .utf8)
            .split(separator: "\n")
            .map { line in
                guard line.hasPrefix("|") else { return line }
                return Substring(line.split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .joined(separator: " | ")
                    .trimmingCharacters(in: .whitespaces))
            }
    }

    /// The table row whose first cell is `name`, ignoring case.
    private static func row(for name: String, in lines: [Substring]) -> Substring? {
        lines.first { $0.lowercased().hasPrefix("| \(name.lowercased()) |") }
    }

    /// Attribution is a licence obligation. The app's list and TREDJEPART.md are
    /// the same claim in two places; this test is what keeps them one claim.
    @Test("Lisenslisten i appen står i TREDJEPART.md med samme lisens")
    func licenceListsAgree() throws {
        let lines = try Self.document("TREDJEPART.md")
        for component in LicensesView.allComponents {
            let row = Self.row(for: component.name, in: lines)
            #expect(row != nil, "\(component.name) mangler i TREDJEPART.md")
            #expect(row?.contains("| \(component.license) |") == true, "\(component.name) har en annen lisens i TREDJEPART.md")
        }
    }

    /// Every package Xcode resolved is attributed, nothing is attributed that is
    /// no longer resolved, and the version and link in TREDJEPART.md are the ones
    /// in `Package.resolved`. The day WhisperKit pulls in a ninth package, this fails.
    @Test("Kodepakkene er de Package.resolved løser opp, med samme versjon og lenke")
    func packagesMatchResolved() throws {
        let path = "Frodi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
        let data = try Data(contentsOf: Self.root.appending(path: path))
        let pins = try JSONDecoder().decode(Resolved.self, from: data).pins

        let listed = Set(LicensesView.code.map { $0.name.lowercased() })
        #expect(listed == Set(pins.map(\.identity)), "Lisenslisten i appen og Package.resolved har ikke de samme pakkene")

        let lines = try Self.document("TREDJEPART.md")
        for pin in pins {
            let row = Self.row(for: pin.identity, in: lines)
            let version = try #require(pin.state.version, "\(pin.identity) er ikke låst til en versjon")
            #expect(row?.contains("| \(version) |") == true, "\(pin.identity) \(version) står ikke i TREDJEPART.md")
            let link = pin.location.hasSuffix(".git") ? String(pin.location.dropLast(4)) : pin.location
            #expect(row?.contains(link) == true, "\(pin.identity) lenker ikke til \(link) i TREDJEPART.md")
        }
    }

    /// The sentence has been rewritten in two apps at once before, which is
    /// exactly when copies drift.
    @Test("Personvern-kortet åpner med samme setning som PERSONVERN.md")
    func privacyOpenerAgrees() throws {
        let text = try String(contentsOf: Self.root.appending(path: "PERSONVERN.md"), encoding: .utf8)
        #expect(text.contains(InfoView.privacyOpener))
    }

    private struct Resolved: Decodable {
        struct Pin: Decodable {
            struct State: Decodable { let version: String? }
            let identity: String
            let location: String
            let state: State
        }
        let pins: [Pin]
    }
}
