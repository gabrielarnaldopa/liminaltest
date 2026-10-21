import SwiftUI
import UIKit

// MARK: - Kuolki's typeface

/// Bricolage Grotesque for text, and its display cut for big titles. Sizes follow Dynamic Type,
/// so the text-size setting and the system's accessibility sizes keep working.
extension Font {
    static func k(_ style: Font.TextStyle) -> Font {
        switch KFont.family {
        case .kuolki: return bricolage(style)
        case .sistema: return system(style, design: .default)
        case .clasica: return system(style, design: .serif)
        }
    }

    private static func bricolage(_ style: Font.TextStyle) -> Font {
        switch style {
        case .largeTitle: return .custom(KFont.display, size: 34, relativeTo: style).weight(.bold)
        case .title: return .custom(KFont.display, size: 28, relativeTo: style).weight(.semibold)
        case .title2: return .custom(KFont.display, size: 22, relativeTo: style).weight(.semibold)
        case .title3: return .custom(KFont.text, size: 20, relativeTo: style).weight(.semibold)
        case .headline: return .custom(KFont.text, size: 17, relativeTo: style).weight(.semibold)
        case .body: return .custom(KFont.text, size: 17, relativeTo: style)
        case .callout: return .custom(KFont.text, size: 16, relativeTo: style)
        case .subheadline: return .custom(KFont.text, size: 15, relativeTo: style)
        case .footnote: return .custom(KFont.text, size: 13, relativeTo: style)
        case .caption: return .custom(KFont.text, size: 12, relativeTo: style)
        case .caption2: return .custom(KFont.text, size: 11, relativeTo: style)
        @unknown default: return .custom(KFont.text, size: 17, relativeTo: .body)
        }
    }

    /// The iPhone's own typefaces (San Francisco, or New York with serifs), with the same weights.
    private static func system(_ style: Font.TextStyle, design: Font.Design) -> Font {
        let base = Font.system(style, design: design)
        switch style {
        case .largeTitle: return base.weight(.bold)
        case .title, .title2, .title3, .headline: return base.weight(.semibold)
        default: return base
        }
    }
}

enum KFont {
    /// Font names inside the app (Liminal/Fonts, listed under UIAppFonts in Info.plist).
    static let text = "BricolageGrotesque-Regular"
    static let display = "BricolageGrotesqueDisplay-SemiBold"

    /// The typeface chosen in Ajustes › Apariencia (set before the screens redraw).
    static var family: FontFamily = .kuolki

    /// Navigation bar titles in the same typeface; the bars themselves keep the system glass.
    static func applyToBars() {
        let title: UIFont?
        let large: UIFont?
        switch family {
        case .kuolki:
            title = UIFont(name: "BricolageGrotesque-SemiBold", size: 17)
            large = UIFont(name: "BricolageGrotesqueDisplay-Bold", size: 34)
        case .sistema:
            title = UIFont.systemFont(ofSize: 17, weight: .semibold)
            large = UIFont.systemFont(ofSize: 34, weight: .bold)
        case .clasica:
            title = UIFont.systemFont(ofSize: 17, weight: .semibold).withDesign(.serif)
            large = UIFont.systemFont(ofSize: 34, weight: .bold).withDesign(.serif)
        }
        if let title { UINavigationBar.appearance().titleTextAttributes = [.font: title] }
        if let large { UINavigationBar.appearance().largeTitleTextAttributes = [.font: large] }
    }
}

extension UIFont {
    /// The same font in another design of the system typeface (serif, rounded).
    func withDesign(_ design: UIFontDescriptor.SystemDesign) -> UIFont {
        guard let descriptor = fontDescriptor.withDesign(design) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

extension View {
    /// The person's theme and text size. Sheets get it too, so they change at once
    /// instead of keeping the look they opened with.
    func kAppearance(_ prefs: Prefs) -> some View {
        self
            .preferredColorScheme(prefs.theme.colorScheme)
            .dynamicTypeSize(prefs.fontScale.dynamicTypeSize)
    }
}
