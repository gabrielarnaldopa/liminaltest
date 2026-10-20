import SwiftUI
import WebKit
import PDFKit

// MARK: - Liquid Glass (iOS 26 and later), with a soft raised surface before that

/// Corner radii for the rounder look: cards, the composer and small controls.
enum Liquid {
    static let card: CGFloat = 24
    static let field: CGFloat = 28
    static let control: CGFloat = 14
}

extension View {
    /// A floating glass surface: the composer, cards and panels.
    func liquidSurface(_ radius: CGFloat = Liquid.card, interactive: Bool = false) -> some View {
        modifier(LiquidSurface(radius: radius, interactive: interactive))
    }

    /// A glass capsule for chips and small buttons.
    func liquidCapsule() -> some View { modifier(LiquidCapsule()) }

    /// A round glass button (the menu button in the top bar).
    func liquidCircle() -> some View { modifier(LiquidCircle()) }

    /// On iOS 26 the system draws the navigation bar in glass; before, it keeps the flat app color.
    func liquidBars() -> some View { modifier(LiquidBars()) }

    /// Behind the composer: clear on iOS 26 so the conversation slides under the glass, the app color before.
    func liquidBackdrop() -> some View { modifier(LiquidBackdrop()) }
}

struct LiquidSurface: ViewModifier {
    let radius: CGFloat
    let interactive: Bool

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return AnyView(content.glassEffect(interactive ? .regular.interactive() : .regular,
                                               in: .rect(cornerRadius: radius, style: .continuous)))
        }
        #endif
        // Before iOS 26: frosted material with a light rim, so the app still reads as glass.
        return AnyView(content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.white.opacity(0.35), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 18, y: 6))
    }
}

struct LiquidCapsule: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return AnyView(content.glassEffect(.regular.interactive(), in: .capsule))
        }
        #endif
        return AnyView(content
            .background(.ultraThinMaterial, in: Capsule())
            .background(Palette.raised.opacity(0.55), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 13, y: 6))
    }
}

struct LiquidCircle: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return AnyView(content.glassEffect(.regular.interactive(), in: .circle))
        }
        #endif
        return AnyView(content
            .background(.ultraThinMaterial, in: Circle())
            .background(Palette.raised.opacity(0.55), in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.08), radius: 13, y: 6))
    }
}

struct LiquidBars: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return AnyView(content)
        }
        #endif
        return AnyView(content.toolbarBackground(Palette.bg, for: .navigationBar))
    }
}

struct LiquidBackdrop: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return AnyView(content.background(Color.clear))
        }
        #endif
        return AnyView(content.background(Palette.bg))
    }
}

/// A soft glow of the flame behind the home screen.
struct Aura: View {
    var body: some View {
        ZStack {
            Circle().fill(Palette.aura[0].opacity(0.22)).frame(width: 260, height: 260).offset(x: -70, y: 10)
            Circle().fill(Palette.aura[1].opacity(0.20)).frame(width: 230, height: 230).offset(x: 80, y: -20)
            Circle().fill(Palette.aura[2].opacity(0.14)).frame(width: 260, height: 260).offset(x: 10, y: 90)
        }
        .blur(radius: 60)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Buttons that shrink a little under your finger, with a spring back.
struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The round send and voice buttons, in the flame gradient.
struct FlameCircle: View {
    let systemImage: String
    var enabled: Bool = true

    var body: some View {
        Image(systemName: systemImage)
            .font(.k(.body).weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Palette.accentGradient).opacity(enabled ? 1 : 0.35))
            .shadow(color: Palette.accent.opacity(enabled ? 0.3 : 0), radius: 7, y: 4)
    }
}

// MARK: - PDFs with design

/// Lithium writes a PDF with design as a print-ready page (A4 sheets); here it becomes a real PDF,
/// drawn by the system's web engine: vector pages with selectable text.
enum PagePDF {
    /// A4 at 96 dots per inch, the size the page is written in.
    static let sheet = CGSize(width: 794, height: 1123)

    static func isPrintDoc(_ code: String) -> Bool {
        let lower = code.lowercased()
        return lower.range(of: #"<meta[^>]+liminal-entrega[^>]+pdf"#, options: .regularExpression) != nil
            || lower.range(of: #"@page\s*\{[^}]*size\s*:\s*(a4|letter|carta|legal)"#, options: .regularExpression) != nil
    }

    @MainActor
    static func make(html: String, title: String) async -> URL? {
        let web = WKWebView(frame: CGRect(origin: .zero, size: sheet), configuration: WKWebViewConfiguration())
        web.loadHTMLString(html, baseURL: nil)
        var waited = 0
        repeat {
            try? await Task.sleep(nanoseconds: 150_000_000)
            waited += 1
        } while web.isLoading && waited < 40
        try? await Task.sleep(nanoseconds: 300_000_000)
        let measured = try? await web.evaluateJavaScript("Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)")
        let height = (measured as? NSNumber)?.doubleValue ?? Double(sheet.height)
        let pages = min(60, max(1, Int((height / Double(sheet.height) - 0.02).rounded(.up))))
        // The whole document laid out at once, then one A4 slice per page.
        web.frame = CGRect(x: 0, y: 0, width: sheet.width, height: sheet.height * CGFloat(pages))
        try? await Task.sleep(nanoseconds: 250_000_000)
        let document = PDFDocument()
        for index in 0..<pages {
            let config = WKPDFConfiguration()
            config.rect = CGRect(x: 0, y: CGFloat(index) * sheet.height, width: sheet.width, height: sheet.height)
            guard let data = try? await web.pdf(configuration: config),
                  let page = PDFDocument(data: data)?.page(at: 0) else { continue }
            document.insert(page, at: document.pageCount)
        }
        guard document.pageCount > 0, let data = document.dataRepresentation() else { return nil }
        return try? DocExport.temporaryFile(data, title: title, ext: "pdf")
    }
}
