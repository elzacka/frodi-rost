import SwiftUI

/// The design system in code: the only source of colours, spacings and radii; no custom values in views.
///
/// Source: dev_only/designsystem/frodi-designsystem.html

// MARK: - Colours
extension Color {
    enum Frodi {
        static let background = Color("Background")
        static let surface = Color("Surface")
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let border = Color("BorderNeutral")

        /// Used only for recording-related elements.
        static let accentRecord = Color("AccentRecord")
        /// Text and icons on top of `accentRecord`. Never pure black or white.
        static let accentRecordOn = Color("AccentRecordOn")
        /// A recording is in progress.
        static let recordingActive = Color("RecordingActive")

        // Two text colours, no third. Running text is `textPrimary` (16,25:1 on Surface); labels and status lines are
        // `textSecondary` (5,65:1). No opacity blend: it is a third tone in all but name; `ContrastTests` measures the step.

        // accent-knowledge (#2E9C82) is reserved for the knowledge feature and is
        // therefore not here yet. Add it when that feature is built.
    }
}

// MARK: - Typography
extension Font {
    enum Frodi {
        /// Skranji Bold. Logo and app name. The same face as in the app icon.
        static let display = custom("Skranji-Bold", size: 26, relativeTo: .largeTitle)
        /// Inter 600. Screen titles.
        ///
        /// Skranji is kept to the logo: «Ingen opptak ennå» must read fast at large text and in a car (WCAG 2.2 AA).
        static let title = custom("Inter-SemiBold", size: 20, relativeTo: .title2)
        /// Inter 500, tracked. Small labels above a section.
        static let eyebrow = custom("Inter-Medium", size: 11, relativeTo: .caption2)
        /// Inter 500. The timer while recording. Must be readable at a distance in a car.
        static let timer = custom("Inter-Medium", size: 32, relativeTo: .largeTitle)
        static let body = custom("Inter-Regular", size: 15, relativeTo: .body)
        static let bodyMedium = custom("Inter-Medium", size: 15, relativeTo: .body)
        static let caption = custom("Inter-Regular", size: 13, relativeTo: .footnote)
        static let meta = custom("Inter-Regular", size: 11, relativeTo: .caption2)
    }
}

// MARK: - Spacing
/// 8 px grid. No custom numbers outside this scale.
enum Space {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let s6: CGFloat = 24
    static let s7: CGFloat = 32
    static let s8: CGFloat = 40
}

// MARK: - Corner radius
enum Radius {
    static let control: CGFloat = 12
    static let card: CGFloat = 16
}

// MARK: - Record button
enum RecordButton {
    static let diameter: CGFloat = 76
    static let inner: CGFloat = 56
    static let ring: CGFloat = 3
    static let icon: CGFloat = 30
}

// MARK: - Live Activity
/// Lock Screen and Dynamic Island recording. Measures are the recorder bar's (timer in `timer`, stop button = record button's
/// inner circle) so both surfaces match; the design system describes neither.
enum LiveActivity {
    static let stop: CGFloat = RecordButton.inner
    static let stopIcon: CGFloat = RecordButton.icon
    /// The microphone in the compact and minimal island, beside the clock's text.
    static let compactIcon: CGFloat = 20
}

// MARK: - Header button
/// Info button right of the logo header. No design-system measure: icon size as in the system navigation bar, hit area 44 pt minimum.
enum HeaderButton {
    /// The glyph fills 75 × 67 % of the frame: 21 × 18,7 pt.
    static let icon: CGFloat = 28
    static let touch: CGFloat = 44
}

// MARK: - Icons
/// Icon sizes in points: frames, not glyphs, for Material Symbols (24 × 24 grid). Material pads its grid, so each frame gives
/// the visible glyph of the SF Symbol drawn in the design (chevron 7 × 12 pt, close cross 15 pt); see design file, Ikoner.
enum IconSize {
    /// Chevrons in rows and cards, in line with the caption beside them.
    static let inline: CGFloat = 24
    /// Buttons in the navigation bar.
    static let toolbar: CGFloat = 26
    /// An icon standing alone above a message.
    static let notice: CGFloat = 24
    /// The mark after a link that leaves the app, beside a caption. The glyph
    /// fills 75 % of the frame: 10,5 pt, under the text's cap height, so it is
    /// read as a mark on the word and not as a second word.
    static let external: CGFloat = 14
}

// MARK: - Icon badge
/// Small disc adding a meaning to an icon (the «add» on the import waveform), sized as fractions of the icon's frame.
/// AccentRecord disc, glyph in AccentRecordOn (import is the other way to record); `ContrastTests`: 3,25:1 vs background, 4,59:1 glyph.
enum IconBadge {
    /// 10,5 pt on the 28 pt header icon. The glyph gets the same frame, and
    /// Material's `add` fills 58 % of it: a 6 pt plus.
    static let diameter: CGFloat = 0.375
    /// Gap cut out of the icon around the disc, in points. The round bite out of the fourth bar is deliberate: clear of the bars the
    /// disc floated beside the icon, closer it clipped a corner that read as a flaw.
    static let gap: CGFloat = 1.5
    /// The disc's centre: (790, 830) on Material's 960 grid, in the corner the
    /// waveform leaves empty under its last bar.
    static let center = UnitPoint(x: 790.0 / 960, y: 830.0 / 960)
}

// MARK: - Playback controls
/// No player in the design system; measures derived: play = record button's inner circle, skip buttons 44 pt (minimum hit area).
enum PlayerControl {
    static let play: CGFloat = 56
    static let playIcon: CGFloat = 30
    static let skip: CGFloat = 44
    static let skipIcon: CGFloat = 26
}

// MARK: - Collapsed content
/// The design system describes no expander. The row that folds the text out and
/// in is 44 pt tall, the minimum hit area.
enum Disclosure {
    static let row: CGFloat = 44
}

// MARK: - Choice sheet
/// The design system describes no dialog. An answer in a `ChoiceSheet` is a row
/// in the shape of a list row, 44 pt tall, the minimum hit area.
enum ChoiceRow {
    static let height: CGFloat = 44
}

// MARK: - Word list field
/// No resizable field in the design system. The Ordliste field has a lower-right grip that drags it taller or shorter, so a long list reads in a tall field and a short one does not hold the page.
enum WordListField {
    /// Three lines of body text with the insets. Where the field starts, and
    /// the least the grip allows.
    static let minHeight: CGFloat = 88
    /// About half a screen. The page scrolls; the field need not be it.
    static let maxHeight: CGFloat = 400
    /// The grip glyph, and the touch area around it.
    static let grip: CGFloat = 16
    static let gripTouch: CGFloat = 44
    /// One step of the grip under VoiceOver: one touch target.
    static let step: CGFloat = 44
    /// `TextEditor`'s own inset around its text. The placeholder is drawn over
    /// the editor and has to start where the typed text will.
    static let textInset = EdgeInsets(top: 8, leading: 5, bottom: 8, trailing: 5)
}

// MARK: - Tracking
extension Text {
    /// Eyebrow labels are tracked 0.06 em in the design system.
    func eyebrowTracking() -> some View {
        tracking(11 * 0.06)
    }
}
