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
        return AnyView(content
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Palette.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 16, y: 4))
    }
}

struct LiquidCapsule: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return AnyView(content.glassEffect(.regular.interactive(), in: .capsule))
        }
        #endif
        return AnyView(content.background(Palette.sunk, in: Capsule()))
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
