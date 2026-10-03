import SwiftUI

/// Settings: the three things you can set, what the app is, and the documents, as a sheet so you return to the list as you left it.
/// Order: settings, the card with version and address, then the documents (use, privacy, security, licences).
/// The prose lives in the documents; the page links to them rather than repeating them.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var words = WordList.load()
    /// The height of the word list field, in points. Kept between sessions so
    /// a field once dragged tall stays tall.
    @AppStorage(WordList.heightKey) private var fieldHeight = Double(WordListField.minHeight)
    /// The height when the finger landed on the grip; the drag adds to it.
    @State private var heightAtDragStart: Double?
    /// The same key `RecordingExport.TextFormat.chosen` reads.
    @AppStorage(RecordingExport.TextFormat.key) private var textFormat = RecordingExport.TextFormat.rtf
    /// The same key `TextMode.current` reads.
    @AppStorage(TextMode.key) private var textMode = TextMode.enkel

    var body: some View {
        NavigationStack {
            ZStack {
                Color.Frodi.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.s4) {
                        mode
                        wordList
                        export
                        about
                        documents
                    }
                    .padding(Space.s4)
                }
            }
            .navigationTitle("Innstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.Frodi.background, for: .navigationBar)
            .toolbar {
                // A cross, not «Ferdig»: there is nothing to confirm here, the sheet just
                // closes. The icon also carries no type, so the question of Inter beside the
                // system title goes away. VoiceOver needs the name the button does not write.
                ToolbarButton(icon: .close, label: "Lukk", placement: .topBarTrailing) { dismiss() }
            }
        }
    }

    // MARK: - Cards
    /// The first sentence about privacy here, and the first sentence of
    /// PERSONVERN.md. A test keeps them the same sentence.
    static let privacyOpener = "Alt skjer på enheten. Ingen datatrafikk ut eller inn."

    /// What the app is, what it runs on, which build this is, and where to write.
    private var about: some View {
        Card("Fróði røst") {
            paragraph("Fróði er norrønt og betyr «den kunnskapsrike».")
            paragraph("Appen tar opp lyd og gjør den om til norsk tekst. " + Self.privacyOpener)
            paragraph("Modellen nb-whisper-small fra Nasjonalbiblioteket er innebygd i appen og kjører på enheten.")
            paragraph("Versjon \(Self.versionNumber)")
            paragraph("Spørsmål eller feil: hei@tazk.no")
        }
    }

    /// One document per reader: user, privacy-minded, security reviewer, licence holders. Three links open on GitHub
    /// in Safari; the licences are an in-app screen, since the licences require their texts in the app itself.
    private var documents: some View {
        Card("Mer om appen") {
            link("Brukerveiledning", to: Self.userGuide)
            link("Personvernerklæring", to: Self.privacyPolicy)
            // SECURITY.md is written for security reviewers, in English; the label says so before the tap.
            link("Sikkerhet (engelsk)", to: Self.securityPolicy)
            licenses
        }
    }

    /// Names the model should spell right: typed once, read by every transcription.
    /// A `TextEditor` of fixed height, not a growing text field: the user sets the height with the lower-right grip, the text scrolls inside.
    /// The cards below follow the field's height through the layout, so nothing overlaps as it grows.
    private var wordList: some View {
        Card("Ordliste") {
            paragraph("Skriv inn navn og ord modellen kan bomme på. Skill dem med komma.")

            TextEditor(text: $words)
                .font(.Frodi.body)
                .foregroundStyle(Color.Frodi.textPrimary)
                .scrollContentBackground(.hidden)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel("Ordliste")
                .accessibilityHint("Skill ordene med komma")
                .padding(Space.s2)
                .frame(height: fieldHeight)
                .background(Color.Frodi.background, in: RoundedRectangle(cornerRadius: Radius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.control)
                        .strokeBorder(Color.Frodi.border, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) { placeholder }
                .overlay(alignment: .bottomTrailing) { grip }
                .onChange(of: words) { _, text in WordList.save(text) }
                .hiddenWhileScreenCaptured()
        }
    }

    /// `TextEditor` has no placeholder of its own. This one sits where the
    /// first line of text will, and lets touches through to the editor.
    @ViewBuilder
    private var placeholder: some View {
        if words.isEmpty {
            Text("Aall & Ulefos Brug, ISO 19011")
                .font(.Frodi.body)
                .foregroundStyle(Color.Frodi.textSecondary)
                .padding(WordListField.textInset)
                .padding(Space.s2)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The field's lower right corner: drag to resize; adjustable under VoiceOver, one touch target per step. High priority, or the
    /// scroll view takes the vertical drag. Measured in global space: the grip moves with every point the field grows, so in its
    /// own space the finger would seem to move back and the field would shrink again, frame after frame.
    private var grip: some View {
        IconView(.resize, size: WordListField.grip)
            .foregroundStyle(Color.Frodi.textSecondary)
            .padding(Space.s2)
            .frame(width: WordListField.gripTouch, height: WordListField.gripTouch, alignment: .bottomTrailing)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { drag in
                        let start = heightAtDragStart ?? fieldHeight
                        heightAtDragStart = start
                        fieldHeight = Self.clampedHeight(start + drag.translation.height)
                    }
                    .onEnded { _ in heightAtDragStart = nil }
            )
            .accessibilityLabel("Høyde på feltet")
            .accessibilityValue("\(Int(fieldHeight)) punkt")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: fieldHeight = Self.clampedHeight(fieldHeight + WordListField.step)
                case .decrement: fieldHeight = Self.clampedHeight(fieldHeight - WordListField.step)
                @unknown default: break
                }
            }
    }

    private static func clampedHeight(_ height: Double) -> Double {
        min(max(height, WordListField.minHeight), WordListField.maxHeight)
    }

    /// Avansert adds who said what.
    private var mode: some View {
        Card("Tekstmodus") {
            paragraph("Avansert viser hvem som sa hva (diarization).")

            // Stacked when one line cannot hold both, as at the largest text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Space.s2) { modePills }
                VStack(alignment: .leading, spacing: Space.s2) { modePills }
            }
        }
    }

    private var modePills: some View {
        ForEach([TextMode.enkel, .avansert], id: \.self) { choice in
            pill(choice.label, chosen: textMode == choice, spoken: "Tekstmodus \(choice.label)") { textMode = choice }
        }
    }

    /// The one choice the export offers in advance. What to hand over, audio or
    /// text or both, is asked where the export is made; the shape of the text
    /// is decided here, once, because it is the same every time.
    private var export: some View {
        Card("Eksport") {
            paragraph("Velg format for teksten.")

            HStack(spacing: Space.s2) {
                ForEach(RecordingExport.TextFormat.allCases, id: \.self) { format in
                    pill(format.label, chosen: textFormat == format, spoken: "Tekst som \(format.label)") { textFormat = format }
                }
            }
        }
    }

    /// A pill that is filled when chosen and outlined when not. The fill is
    /// the signal for sighted readers; VoiceOver hears «valgt».
    private func pill(_ label: String, chosen: Bool, spoken: String, choose: @escaping () -> Void) -> some View {
        Button(action: choose) {
            Text(verbatim: label)
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
        .accessibilityLabel(spoken)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    /// A row, not a link: the licences are inside the app. The chevron says so.
    private var licenses: some View {
        NavigationLink {
            LicensesView()
        } label: {
            HStack(spacing: Space.s2) {
                Text("Lisenser")
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textPrimary)
                Spacer()
                IconView(.chevronRight, size: IconSize.inline)
                    .foregroundStyle(Color.Frodi.textSecondary)
            }
            .frame(minHeight: ChoiceRow.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lisenser")
        .accessibilityHint("Åpner listen over modell, kode, ikoner og fonter")
    }

    // The links open in Safari. The app fetches nothing itself; it is the browser
    // that goes online, and only when you tap.
    private static let userGuide = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/BRUKERVEILEDNING.md")!
    private static let privacyPolicy = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/PERSONVERN.md")!
    private static let securityPolicy = URL(string: "https://github.com/elzacka/frodi-rost/blob/main/SECURITY.md")!

    private static var versionNumber: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(marketing) (\(build))"
    }

    // MARK: - Building blocks
    /// Running text in a card. `textPrimary`, not `textSecondary`: this is what
    /// the page is for. The card label above it is the secondary tone.
    private func paragraph(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.Frodi.caption)
            .foregroundStyle(Color.Frodi.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A link out of the app, same size and tone as the surrounding text. The small secondary `open_in_new` mark after the word says
    /// the document opens outside the app, which the row chevron does not, and is not colour alone.
    /// The icon is hidden from VoiceOver; the link trait already says «lenke».
    private func link(_ title: String, to url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: Space.s1) {
                Text(verbatim: title)
                    .font(.Frodi.caption)
                    .foregroundStyle(Color.Frodi.textPrimary)
                IconView(.external, size: IconSize.external)
                    .foregroundStyle(Color.Frodi.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The attribution and licence texts MIT, Apache 2.0, CC BY and OFL require, in the app and not only in the repo.
/// Same names and licences as TREDJEPART.md (which also has versions and links); `DocumentTests` fails if the two lists or `Package.resolved` disagree.
struct LicensesView: View {
    struct Component: Identifiable, Hashable {
        let name: String
        let origin: String
        let license: String
        /// The text file in `Resources/Licenses`, without `.txt`: the project's own file where it has one.
        let text: String

        var id: String { name }
    }

    static let model = [
        Component(name: "nb-whisper-small", origin: "Nasjonalbiblioteket", license: "Apache 2.0", text: "Apache-2.0"),
        Component(name: "CoreML-konvertering", origin: "Barrymanalow", license: "Apache 2.0", text: "Apache-2.0"),
        Component(name: "Tokenizer, whisper-small", origin: "OpenAI", license: "Apache 2.0", text: "Apache-2.0"),
        Component(name: "Talermodell, community-1", origin: "pyannote", license: "CC BY 4.0", text: "CC-BY-4.0"),
        Component(name: "CoreML-konvertering, talermodell", origin: "Argmax", license: "CC BY 4.0", text: "CC-BY-4.0")
    ]

    /// The packages Xcode resolves, by their identity in `Package.resolved`.
    static let code = [
        Component(name: "argmax-oss-swift", origin: "Argmax", license: "MIT", text: "argmax-oss-swift-LICENSE"),
        Component(name: "swift-argument-parser", origin: "Apple", license: "Apache 2.0", text: "swift-argument-parser-LICENSE")
    ]

    /// Source that ships inside argmax-oss-swift rather than as a package of its
    /// own. Apache 2.0 asks for attribution whichever way the code arrives.
    static let embedded = [
        Component(name: "swift-transformers", origin: "Hugging Face", license: "Apache 2.0", text: "argmax-oss-swift-NOTICES")
    ]

    static let icons = [
        Component(name: "Material Symbols", origin: "Google", license: "Apache 2.0", text: "Apache-2.0")
    ]

    static let fonts = [
        Component(name: "Skranji", origin: "Font Diner", license: "SIL Open Font License 1.1", text: "Skranji-OFL"),
        Component(name: "Inter", origin: "Rasmus Andersson", license: "SIL Open Font License 1.1", text: "Inter-OFL")
    ]

    static var allComponents: [Component] { model + code + embedded + icons + fonts }

    var body: some View {
        ZStack {
            Color.Frodi.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.s4) {
                    group("Modeller", Self.model)
                    group("Kode", Self.code + Self.embedded)
                    group("Ikoner", Self.icons)
                    group("Fonter", Self.fonts)
                }
                .padding(Space.s4)
            }
        }
        .navigationTitle("Lisenser")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.Frodi.background, for: .navigationBar)
        .frodiBackButton()
    }

    private func group(_ label: String, _ components: [Component]) -> some View {
        Card(label) {
            ForEach(components) { component in
                NavigationLink {
                    LicenseTextView(component: component)
                } label: {
                    HStack(spacing: Space.s2) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: component.name)
                                .font(.Frodi.bodyMedium)
                                .foregroundStyle(Color.Frodi.textPrimary)

                            Text("\(component.origin) · \(component.license)")
                                .font(.Frodi.meta)
                                .foregroundStyle(Color.Frodi.textSecondary)
                        }
                        Spacer()
                        IconView(.chevronRight, size: IconSize.inline)
                            .foregroundStyle(Color.Frodi.textSecondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: ChoiceRow.height, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Viser lisensteksten")
            }
        }
    }
}

/// One licence text, as the project ships it. Hard-wrapped lines are joined so
/// the text follows the screen width and Dynamic Type; blank lines stay paragraph breaks.
struct LicenseTextView: View {
    let component: LicensesView.Component

    static func paragraphs(of file: String) -> [String] {
        guard let url = Bundle.main.url(forResource: file, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n\n")
            .map { $0.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ") }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ZStack {
            Color.Frodi.background.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: Space.s3) {
                    ForEach(Array(Self.paragraphs(of: component.text).enumerated()), id: \.offset) { _, paragraph in
                        Text(verbatim: paragraph)
                            .font(.Frodi.caption)
                            .foregroundStyle(Color.Frodi.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(Space.s4)
            }
        }
        .navigationTitle(component.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.Frodi.background, for: .navigationBar)
        .frodiBackButton()
    }
}

/// The settings card from the design system: eyebrow label in capitals over
/// its content, on surface with a 1 px border. Innstillinger and Lisenser are
/// both built of it.
private struct Card<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    init(_ label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s3) {
            Text(verbatim: label)
                .font(.Frodi.eyebrow)
                .eyebrowTracking()
                .textCase(.uppercase)
                .foregroundStyle(Color.Frodi.textSecondary)
                .accessibilityAddTraits(.isHeader)

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
}
