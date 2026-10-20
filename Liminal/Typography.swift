import SwiftUI
import UIKit

// MARK: - Kuolki's typeface

/// Bricolage Grotesque for text, and its display cut for big titles. Sizes follow Dynamic Type,
/// so the text-size setting and the system's accessibility sizes keep working.
extension Font {
    static func k(_ style: Font.TextStyle) -> Font {
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
}

enum KFont {
    /// Font names inside the app (Liminal/Fonts, listed under UIAppFonts in Info.plist).
    static let text = "BricolageGrotesque-Regular"
    static let display = "BricolageGrotesqueDisplay-SemiBold"

    /// Navigation bar titles in the same typeface; the bars themselves keep the system glass.
    static func applyToBars() {
        if let f = UIFont(name: "BricolageGrotesque-SemiBold", size: 17) {
            UINavigationBar.appearance().titleTextAttributes = [.font: f]
        }
        if let f = UIFont(name: "BricolageGrotesqueDisplay-Bold", size: 34) {
            UINavigationBar.appearance().largeTitleTextAttributes = [.font: f]
        }
    }
}
