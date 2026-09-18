import SwiftUI

/// The Info page: what the app is, what it builds on, and where the documents
/// are. Opens as a sheet from the menu button in the logo header. A sheet, not
/// a new page, because you should return to the list where you left it.
///
/// How to use the app is in BRUKERVEILEDNING.md and the privacy facts are in
/// PERSONVERN.md; the page links to both rather than repeating them.
///
/// Not «Innstillinger»: the app has no options of its own. The word list and
/// the text format are the two things you can change on the page, and neither
/// is a mode: a list of names is not a setting, and a file extension is chosen
/// once. The title says what the page is.
struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var words = WordList.load()
    /// The same key `RecordingExport.TextFormat.chosen` reads.
    @AppStorage(RecordingExport.TextFormat.key) private var textFormat = RecordingExport.TextFormat.rtf

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Frodi.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.s4) {
                        about
                        privacy
                        languageModel
                        wordList
                        export
                        licenses
                        version
                    }
                    .padding(Space.s4)
                }
            }
            .navigationTitle("Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.Frodi.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // A cross, not «Ferdig»: there is nothing to confirm here, the sheet just
                    // closes. The icon also carries no type, so the question of Inter beside the
                    // system title goes away. VoiceOver needs the name the button does not write.
                    Button { dismiss() } label: { IconView(.close, size: IconSize.toolbar) }
                        .accessibilityLabel("Lukk")
                }
            }
        }
    }

    // MARK: - Cards
    /// What the app is, and the link to how it is used.
    private var about: some View {
        card("Fróði røst") {
            paragraph("Fróði er norrønt og betyr «den kunnskapsrike».")
            paragraph("Appen tar opp lyd og gjør den om til norsk tekst.")
            link("Brukerveiledning", to: Self.userGuide)
        }
    }

    /// The first sentence of the Personvern card, and the first sentence of
    /// PERSONVERN.md. A test keeps them the same sentence.
    static let privacyOpener = "Alt skjer på enheten. Ingen datatrafikk ut eller inn."

    /// The promise, and the document that spells it out.
    private var privacy: some View {
        card("Personvern") {
            paragraph(Self.privacyOpener)
            link("Personvernerklæring", to: Self.privacyPolicy)
        }
    }

    private var languageModel: some View {
        card("Språkmodell") {
            paragraph("Modellen nb-whisper-small fra Nasjonalbiblioteket følger med appen og kjører inne i den.")
            paragraph("Modellen er videretrent på 66\u{00A0}000 timer norsk tale. Den setter tegn og store bokstaver selv, og skriver om dialekt til bokmål.")
        }
    }

    /// The app's one setting. Names the model should spell right: the field is
    /// where a user types them once, and every transcription reads them.
    private var wordList: some View {
        card("Ordliste") {
            paragraph("Skriv inn navn og ord modellen kan bomme på. Skill dem med komma.")

            TextField("Aall & Ulefos Brug, ISO 19011", text: $words, axis: .vertical)
                .lineLimit(2...8)
                .font(.Frodi.body)
                .foregroundStyle(Color.Frodi.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(Space.s3)
                .background(Color.Frodi.background, in: RoundedRectangle(cornerRadius: Radius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control)
                        .strokeBorder(Color.Frodi.border, lineWidth: 1)
                )
                .accessibilityLabel("Ordliste")
                .onChange(of: words) { _, text in WordList.save(text) }
                .hiddenWhileScreenCaptured()
        }
    }

    /// The one choice the export offers in advance. What to hand over, audio or
    /// text or both, is asked where the export is made; the shape of the text
    /// is decided here, once, because it is the same every time.
    private var export: some View {
        card("Eksport") {
            paragraph("Lyden eksporteres alltid som .m4a. Velg format for teksten.")

            HStack(spacing: Space.s2) {
                ForEach(RecordingExport.TextFormat.allCases, id: \.self) { format in
                    formatChoice(format)
                }
            }
        }
    }

    /// A pill that is filled when chosen and outlined when not. The fill is
    /// the signal for sighted readers; VoiceOver hears «valgt».
    private func formatChoice(_ format: RecordingExport.TextFormat) -> some View {
        let chosen = textFormat == format
        return Button {
            textFormat = format
        } label: {
            Text(format.label)
                .font(.Frodi.bodyMedium)
                .foregroundStyle(chosen ? Color.Frodi.accentRecordOn : Color.Frodi.textPrimary)
                .padding(.horizontal, Space.s4)
                .padding(.vertical, Space.s2)
                .background(chosen ? Color.Frodi.accentRecord : Color.Frodi.background, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.Frodi.border, lineWidth: chosen ? 0 : 1))
                .frame(minHeight: ChoiceRow.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tekst som \(format.label)")
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    private var licenses: some View {
        NavigationLink {
            LicensesView()
        } label: {
            card("Lisenser", opensScreen: true) {
                paragraph("Modell, kode, ikoner og fonter appen bygger på, med lisens.")
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lisenser")
        .accessibilityHint("Åpner listen over modell, kode og fonter")
    }

    private var version: some View {
        card("Versjon") {
            paragraph("Fróði røst \(Self.versionNumber)")
            paragraph("Spørsmål eller feil: hei@tazk.no")
        }
    }

    // The links open in Safari. The app fetches nothing itself; it is the browser
    // that goes online, and only when you tap.
    private static let userGuide = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/BRUKERVEILEDNING.md")!
    private static let privacyPolicy = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/PERSONVERN.md")!

    private static var versionNumber: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(marketing) (\(build))"
    }

    // MARK: - Building blocks
    /// The settings card from the design system: eyebrow label in capitals over
    /// body text in caption, on surface with a 1 px border.
    @ViewBuilder
    private func card(_ label: String, opensScreen: Bool = false, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            HStack(spacing: Space.s2) {
                Text(label)
                    .font(.Frodi.eyebrow)
                    .eyebrowTracking()
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .accessibilityAddTraits(.isHeader)

                if opensScreen {
                    Spacer()
                    IconView(.chevronRight, size: IconSize.inline)
                        .foregroundStyle(Color.Frodi.textSecondary)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(Color.Frodi.surface, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.Frodi.border, lineWidth: 1)
        )
    }

    /// Running text in a card. `textPrimary`, not `textSecondary`: this is what
    /// the page is for. The card label above it is the secondary tone.
    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(.Frodi.caption)
            .foregroundStyle(Color.Frodi.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }


    /// A link out of the app, at the same size and in the same tone as the text
    /// around it. The underline is what marks it, and it is the only mark: a link
    /// must not be told apart by colour alone, so nothing is lost by dropping the
    /// colour difference the running text used to give it for free.
    private func link(_ title: String, to url: URL) -> some View {
        Link(title, destination: url)
            .font(.Frodi.caption)
            .underline()
            .tint(Color.Frodi.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The attribution Apache 2.0 requires, in the app and not only in the repo.
///
/// The same names and licences as TREDJEPART.md, which also carries versions
/// and links. `DocumentTests` fails if the two lists, or `Package.resolved`,
/// disagree.
struct LicensesView: View {
    struct Component: Identifiable {
        let name: String
        let origin: String
        let license: String

        var id: String { name }
    }

    static let model = [
        Component(name: "nb-whisper-small", origin: "Nasjonalbiblioteket", license: "Apache 2.0"),
        Component(name: "CoreML-konvertering", origin: "Barrymanalow", license: "Apache 2.0"),
        Component(name: "Tokenizer, whisper-small", origin: "OpenAI", license: "Apache 2.0")
    ]

    static let code = [
        Component(name: "WhisperKit", origin: "Argmax", license: "MIT"),
        Component(name: "swift-transformers", origin: "Hugging Face", license: "Apache 2.0"),
        Component(name: "swift-jinja", origin: "Hugging Face", license: "Apache 2.0"),
        Component(name: "swift-collections", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-argument-parser", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-crypto", origin: "Apple", license: "Apache 2.0"),
        Component(name: "swift-asn1", origin: "Apple", license: "Apache 2.0"),
        Component(name: "yyjson", origin: "Yao Yuan", license: "MIT")
    ]

    static let icons = [
        Component(name: "Material Symbols", origin: "Google", license: "Apache 2.0")
    ]

    static let fonts = [
        Component(name: "Skranji", origin: "Font Diner", license: "SIL Open Font License 1.1"),
        Component(name: "Inter", origin: "Rasmus Andersson", license: "SIL Open Font License 1.1")
    ]

    static var allComponents: [Component] { model + code + icons + fonts }

    var body: some View {
        ZStack {
            Color.Frodi.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.s4) {
                    group("Modell", Self.model)
                    group("Kode", Self.code)
                    group("Ikoner", Self.icons)
                    group("Fonter", Self.fonts)
                }
                .padding(Space.s4)
            }
        }
        .navigationTitle("Lisenser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.Frodi.background, for: .navigationBar)
    }

    private func group(_ label: String, _ components: [Component]) -> some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(label)
                .font(.Frodi.eyebrow)
                .eyebrowTracking()
                .textCase(.uppercase)
                .foregroundStyle(Color.Frodi.textSecondary)
                .accessibilityAddTraits(.isHeader)

            ForEach(components) { component in
                VStack(alignment: .leading, spacing: 2) {
                    Text(component.name)
                        .font(.Frodi.bodyMedium)
                        .foregroundStyle(Color.Frodi.textPrimary)

                    Text("\(component.origin) · \(component.license)")
                        .font(.Frodi.meta)
                        .foregroundStyle(Color.Frodi.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.s4)
        .background(Color.Frodi.surface, in: RoundedRectangle(cornerRadius: Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.Frodi.border, lineWidth: 1)
        )
    }
}
