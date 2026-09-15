import SwiftUI

/// The Info page: what the app does, what it does not do, and what it builds on.
/// Opens as a sheet from the i in the logo header.
///
/// The sketch put Om fróði, Personvern and Versjonsinfo in a menu on a start
/// screen. That start screen no longer exists, so the content lives here. A sheet,
/// not a new page, because you should return to the list where you left it.
///
/// The sheet was called «Innstillinger» until 10 September 2026, and that was the
/// wrong name: the app has no options of its own. The word list and the text
/// format are the two things you can change on the page, and neither is a mode:
/// a list of names is not a setting, and a file extension is chosen once. The
/// title says what the page is.
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
                        speechModel
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
    /// The mark on the one footnote the page has. A raised digit and not a star:
    /// a star beside a field means «må fylles ut», and this card has a field.
    static let footnoteMark = "\u{00B9}"

    private var about: some View {
        card("Fróði røst") {
            paragraph("Fróði er norrønt og betyr «den kunnskapsrike».")
            paragraph("Appen tar opp lyd og gjør den om til norsk tekst, også med skjermen låst.")
            paragraph("Start og stopp med opptaksknappen nederst, eller ved å holde inne handlingsknappen. Knappen finnes på iPhone 15 Pro og nyere.")
            paragraph("Handlingsknappen må settes opp først: Innstillinger > Handlingsknapp > Snarvei > Bla ned og velg «Fróði røst – Start eller stopp opptak».")
            paragraph(
                "Ingen tidsgrense på opptak. Opptak lengre enn \(Transcription.immediateMinutes) minutter\(Self.footnoteMark) transkriberes når du ber om det.",
                // VoiceOver reads the mark as «opphøyd én», which says nothing. It
                // hears the footnote as the next element instead.
                spokenAs: "Ingen tidsgrense på opptak. Opptak lengre enn \(Transcription.immediateMinutes) minutter transkriberes når du ber om det."
            )
            paragraph("Teksten deles i avsnitt med tidspunkt du kan spille av lyden fra.")
            footnote("10 min: 4–5 min. 30 min: 11–13 min. 60 min: 22–27 min. (Grovt estimat)")
        }
    }

    /// The first sentence of the Personvern card, and the first sentence of
    /// PERSONVERN.md. A test keeps them the same sentence.
    static let privacyOpener = "Alt skjer på enheten. Ingen datatrafikk ut eller inn."

    private var privacy: some View {
        card("Personvern") {
            paragraph(Self.privacyOpener)
            // One sentence, not three states. The app exists to record, so the
            // permission is not a condition the page reports on: it is the one
            // thing the app asks for. RecorderBar says so on the main screen when
            // access is refused, which is where a user who cannot record is.
            paragraph("Appen ber om tilgang til mikrofonen. Ingenting annet.")
            paragraph("Opptak og tekst krypteres med en nøkkel som bare finnes i enheten (Secure Enclave), og blir ikke med i sikkerhetskopier.")
            paragraph("Teksten skjules når skjermen tas opp og når du bytter app.")
            paragraph("Eksporter lyd som .m4a og tekst som .txt eller .rtf. Bytter du enhet, må du eksportere opptakene først. Sletter du appen, er alt borte.")
            link("Mer om personvern", to: Self.privacyPolicy)
            link("Mer om sikkerhet", to: Self.securityPolicy)
        }
    }

    private var speechModel: some View {
        card("Språkmodell") {
            if Transcription.usesBundledModel {
                paragraph("Modellen nb-whisper-small fra Nasjonalbiblioteket følger med appen og kjører inne i den.")
                paragraph("Modellen er videretrent på 66\u{00A0}000 timer norsk tale. Den setter tegn og store bokstaver selv, og skriver om dialekt til bokmål.")
            } else {
                paragraph("Modellen fra Nasjonalbiblioteket er ikke med i dette bygget. Appen bruker dikteringen som følger med iOS.")
                paragraph("Den kjører også på enheten, men er svakere på norsk: Du må si «punktum» og «komma» selv, og dialekt blir ofte feil.")
            }
        }
    }

    /// The app's one setting. Names the model should spell right: the field is
    /// where a user types them once, and every transcription reads them.
    private var wordList: some View {
        card("Ordliste") {
            paragraph("Skriv inn navn og ord som en KI-modell vil kunne bomme på når den transkriberer. Skill dem med komma. Appen vil finne ord som ligner. Langt trykk på et opptak i listen gir deg valget «Lag teksten på nytt». Ordlisten er også kryptert på enheten.")

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
            paragraph("Lyden eksporteres alltid som .m4a. Velg hvilket format teksten skal eksporteres i.")

            HStack(spacing: Space.s2) {
                ForEach(RecordingExport.TextFormat.allCases, id: \.self) { format in
                    formatChoice(format)
                }
            }

            paragraph(".txt er ren tekst og kan limes inn hvor som helst. .rtf åpnes som dokument i Word, Pages og Notater, med overskrift, dato og tidspunkt for hvert avsnitt.")
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
    private static let privacyPolicy = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/PERSONVERN.md")!
    private static let securityPolicy = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/SECURITY.md")!

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
    /// the page is for, and the footnote below it has to read as quieter than
    /// something. The card label above it is the secondary tone, so the card has
    /// a label, a text and a note in three visibly different weights of grey.
    private func paragraph(_ text: String, spokenAs spoken: String? = nil) -> some View {
        Text(text)
            .font(.Frodi.caption)
            .foregroundStyle(Color.Frodi.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(spoken ?? text)
    }

    /// A footnote to the paragraph marked `footnoteMark`. Smaller and quieter
    /// than the text it belongs to: `footnote` at 10 pt, 23 % under the 13 pt of
    /// the paragraph, in `textSecondary` against the paragraph's `textPrimary`.
    ///
    /// Both steps are visible and neither costs contrast: the tone measures
    /// 5,65:1 on Surface, well over the 4,5:1 WCAG 2.2 AA asks for. The opacity
    /// blend this used to need is gone; `ContrastTests` measures what is left.
    ///
    /// The mark is written into the footnote itself rather than laid out as a
    /// hanging indent: one footnote on one card does not need the machinery, and
    /// a hanging indent breaks when the text scales.
    private func footnote(_ text: String) -> some View {
        Text(Self.footnoteMark + " " + text)
            .font(.Frodi.footnote)
            .foregroundStyle(Color.Frodi.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Fotnote. " + text)
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
