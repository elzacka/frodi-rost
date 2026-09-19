import SwiftUI

/// The design system in code. The values here are the only ones to use: no
/// custom colours, spacings or radii out in the views.
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

        // Two text colours, and no third. Running text is `textPrimary`
        // (16,25:1 on Surface); the text that accompanies it, labels and
        // status lines, is `textSecondary` (5,65:1). No opacity blend: a
        // blend is a third tone in everything but name, and `ContrastTests`
        // measures the step between the two.

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
        /// Skranji is a display face and is kept to the logo. Titles such as «Ingen
        /// opptak ennå» must be readable quickly, also with large text and in a car,
        /// and WCAG 2.2 AA applies.
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

// MARK: - Header button
/// The info button at the right of the logo header. The design system gives no
/// measure, so the icon is the size of the one in the system navigation bar, and
/// the hit area is set to the 44 pt minimum.
enum HeaderButton {
    /// The glyph fills 75 × 67 % of the frame: 21 × 18,7 pt.
    static let icon: CGFloat = 28
    static let touch: CGFloat = 44
}

// MARK: - Icons
/// Icon sizes, in points.
///
/// Material Symbols are drawn on a 24 × 24 grid and scaled to these. The measures live
/// here for the same reason as the rest of the design system: a number at the
/// call site never gets changed along with the others.
///
/// The numbers are frames, not glyphs. Material leaves generous padding inside
/// its grid, so each frame was set to give the same visible glyph as the SF
/// Symbol the design was drawn with: a chevron 7 × 12 pt, a close cross 15 pt,
/// and so on. The measurements are in the design file under Ikoner.
enum IconSize {
    /// Chevrons in rows and cards, in line with the caption beside them.
    static let inline: CGFloat = 24
    /// Buttons in the navigation bar.
    static let toolbar: CGFloat = 26
    /// An icon standing alone above a message.
    static let notice: CGFloat = 24
}

// MARK: - Playback controls
/// The design system describes no player. The measures are derived: the play
/// button has the same diameter as the inner circle of the record button, and the
/// skip buttons are 44 pt, the minimum hit area.
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

// MARK: - Tracking
extension Text {
    /// Eyebrow labels are tracked 0.06 em in the design system.
    func eyebrowTracking() -> some View {
        tracking(11 * 0.06)
    }
}
