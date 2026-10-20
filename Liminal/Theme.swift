import SwiftUI
import UIKit

// Kuolki's palette: the interface is light and dark gray only.
// The macOS traffic-light colors carry meaning:
// green = on, healthy, paid · yellow = in progress, near a limit, points · red = errors, stop, destructive.

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// A color that switches between a light-mode and a dark-mode value.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

enum Palette {
    // Grays
    static let bg = Color.dynamic(light: 0xF2F2F7, dark: 0x000000)
    static let side = Color.dynamic(light: 0xEBEBEE, dark: 0x151517)
    static let raised = Color.dynamic(light: 0xFFFFFF, dark: 0x1C1C1E)
    static let sunk = Color.dynamic(light: 0xEDEDF0, dark: 0x242426)
    static let sel = Color.dynamic(light: 0xE2E2E6, dark: 0x3A3A3C)
    static let ink = Color.dynamic(light: 0x1D1D1F, dark: 0xF5F5F7)
    static let ink2 = Color.dynamic(light: 0x48484A, dark: 0xC7C7CC)
    static let ink3 = Color.dynamic(light: 0x6E6E73, dark: 0x98989D)
    static let line = Color.dynamic(light: 0xD8D8DD, dark: 0x38383A)
    static let line2 = Color.dynamic(light: 0xC4C4C9, dark: 0x48484A)
    static let bubble = Color.dynamic(light: 0xE9E9EE, dark: 0x2C2C2E)

    // Kuolki's one accent: the lithium flame from the launch film (coral, crimson, magenta).
    static let accent = Color(hex: 0xFF2D55)
    static let accentGradient = LinearGradient(colors: [Color(hex: 0xFF8A5C), Color(hex: 0xFF2D55), Color(hex: 0xD9268F)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
    static let aura: [Color] = [Color(hex: 0xFF2D55), Color(hex: 0xFF8A5C), Color(hex: 0x8C50FF)]

    // macOS traffic lights
    static let red = Color(hex: 0xFF5F57)
    static let yellow = Color(hex: 0xFEBC2E)
    static let green = Color(hex: 0x28C840)

    // Readable text versions of the traffic lights
    static let redText = Color.dynamic(light: 0xC4302B, dark: 0xFF7B74)
    static let yellowText = Color.dynamic(light: 0x8A5A00, dark: 0xFEBC2E)
    /// Code blocks stay dark in both themes, like a terminal.
    static let codeBg = Color.dynamic(light: 0x1C1C1E, dark: 0x111113)
    static let codeHead = Color.dynamic(light: 0x2C2C2E, dark: 0x1F1F22)
    static let codeInk = Color.dynamic(light: 0xE5E5EA, dark: 0xE5E5EA)
    static let codeMuted = Color.dynamic(light: 0x98989D, dark: 0x98989D)
    static let greenText = Color.dynamic(light: 0x1A7F2E, dark: 0x4BD865)

    // Soft backgrounds
    static let redTint = Color.dynamic(light: 0xFFE6E4, dark: 0x3B2321)
    static let yellowTint = Color.dynamic(light: 0xFFF3D9, dark: 0x3A3122)

    /// Colors people can give a project.
    static let projectColors: [UInt32] = [0x28C840, 0xFEBC2E, 0xFF5F57, 0x8E8E93, 0x636366, 0xAEAEB2]
}

enum StatusLevel {
    case good, warn, bad

    var color: Color {
        switch self {
        case .good: return Palette.green
        case .warn: return Palette.yellow
        case .bad: return Palette.red
        }
    }

    /// Green under 70%, yellow from 70%, red from 90%.
    static func forUsage(used: Int, cap: Int) -> StatusLevel {
        guard cap > 0 else { return .bad }
        let fraction = Double(used) / Double(cap)
        if fraction >= 0.9 { return .bad }
        if fraction >= 0.7 { return .warn }
        return .good
    }
}

extension ThemeChoice {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension FontScale {
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .pequena: return .medium
        case .normal: return .large
        case .grande: return .xLarge
        }
    }
}
