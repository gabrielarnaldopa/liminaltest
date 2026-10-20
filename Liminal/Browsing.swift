import Foundation

// MARK: - Browsing: what Lithium did on the web, and what it asks permission for

/// One step Lithium took on the web: a search or a page it opened.
struct ToolStep: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var query: String = ""
    var url: String = ""
    var host: String = ""
    /// start, done, error or denied
    var status: String = "start"
    var title: String = ""

    var isSearch: Bool { name == "buscar_en_internet" }
    var isBusy: Bool { status == "start" }
    var siteHost: String { host.isEmpty ? Browsing.host(of: url) : host }

    /// What the chat shows for this step.
    var label: String {
        let q = "«\(query.count > 70 ? String(query.prefix(69)) + "…" : query)»"
        if isSearch {
            switch status {
            case "start": return "Buscando \(q)…"
            case "denied": return "Sin permiso para buscar \(q)"
            case "error": return "No se pudo buscar \(q)"
            default: return "Buscó \(q)"
            }
        }
        switch status {
        case "start": return "Abriendo \(siteHost)…"
        case "denied": return "Sin permiso para entrar a \(siteHost)"
        case "error": return "No se pudo abrir \(siteHost)"
        default:
            let shortTitle = title.count > 60 ? String(title.prefix(59)) + "…" : title
            return shortTitle.isEmpty ? "Leyó \(siteHost)" : "Leyó \(shortTitle) · \(siteHost)"
        }
    }

    /// Keeps what is known and adds what is new.
    mutating func merge(_ other: ToolStep) {
        if !other.name.isEmpty { name = other.name }
        if !other.query.isEmpty { query = other.query }
        if !other.url.isEmpty { url = other.url }
        if !other.host.isEmpty { host = other.host }
        if !other.status.isEmpty { status = other.status }
        if !other.title.isEmpty { title = other.title }
    }
}

/// A page Lithium used for an answer.
struct SourceLink: Codable, Equatable, Hashable, Sendable {
    var title: String
    var url: String
    var host: String { Browsing.host(of: url) }
}

/// Lithium wants to search or open a site and waits for the person's answer.
struct AskRequest: Codable, Equatable, Sendable {
    var items: [ToolStep]
    /// Opaque continuation the server needs to pick the answer up again.
    var state: String

    var hosts: [String] {
        var seen: [String] = []
        for item in items where !item.isSearch && !item.siteHost.isEmpty && !seen.contains(item.siteHost) {
            seen.append(item.siteHost)
        }
        return seen
    }
    var wantsSearch: Bool { items.contains { $0.isSearch } }

    var title: String {
        if hosts.isEmpty { return "\(Brand.modelName) quiere buscar en internet" }
        return "\(Brand.modelName) quiere entrar a \(hosts.joined(separator: ", "))" + (wantsSearch ? " y buscar en internet" : "")
    }

    var alwaysLabel: String {
        if hosts.isEmpty { return "Buscar siempre sin preguntar" }
        return hosts.count > 1 ? "Permitir siempre estos sitios" : "Permitir siempre este sitio"
    }

    /// Short text for the Dynamic Island and notifications.
    var summary: String {
        if let host = hosts.first { return "Quiere entrar a \(host)" }
        return "Quiere buscar «\(items.first?.query ?? "")»"
    }
}

/// An answer that runs on the server, as it is right now.
struct JobSnapshot: Equatable, Sendable {
    var status: String
    var text: String
    var think: String = ""
    var tools: [ToolStep] = []
    var sources: [SourceLink] = []
    var ask: AskRequest? = nil
    var notice: String? = nil
    var error: String? = nil

    var isRunning: Bool { status == "running" }
}

/// What the connected server can do.
struct ServerInfo: Equatable, Sendable {
    var ready: Bool
    var search: Bool
    var background: Bool
    var country: String?
}

/// Before entering a site, Lithium asks, goes ahead, or does not browse at all.
enum BrowseMode: String, Codable, CaseIterable, Identifiable {
    case ask, auto, off
    var id: String { rawValue }

    var name: String {
        switch self {
        case .ask: return "Preguntar"
        case .auto: return "Automático"
        case .off: return "Apagado"
        }
    }

    var detail: String {
        switch self {
        case .ask: return "Lithium te pide permiso para cada sitio nuevo y tú decides."
        case .auto: return "Lithium busca y abre páginas sin preguntarte."
        case .off: return "Lithium responde solo con lo que sabe."
        }
    }
}

/// A phone or computer where the account is signed in.
struct DeviceInfo: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var platform: String
    var created: Double
    var lastSeen: Double
    var country: String?
    var current: Bool

    var isPhone: Bool {
        let text = (platform + " " + name).lowercased()
        return text.contains("ios") || text.contains("iphone") || text.contains("ipad") || text.contains("android")
    }
}

/// This device's identity in the account's device list. The token stays in the Keychain.
struct DeviceRecord: Codable, Equatable {
    var id: String
    var email: String
    var token: String?
}

enum Browsing {
    static func host(of url: String) -> String {
        guard let host = URL(string: url)?.host?.lowercased() else { return url }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// An address typed in the browser: a full URL, a domain, or words to search.
    static func url(from typed: String) -> URL? {
        let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if text.lowercased().hasPrefix("http://") || text.lowercased().hasPrefix("https://") { return URL(string: text) }
        let looksLikeDomain = !text.contains(" ") && text.contains(".") && !text.hasPrefix(".") && !text.hasSuffix(".")
        if looksLikeDomain { return URL(string: "https://" + text) }
        var parts = URLComponents(string: "https://duckduckgo.com/")
        parts?.queryItems = [URLQueryItem(name: "q", value: text)]
        return parts?.url
    }
}

// MARK: - Countries and how they pay

struct Country: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }
}

/// A page to open in the built-in browser (`url` nil opens it empty, ready to type an address).
struct BrowserTarget: Identifiable, Equatable {
    let id = UUID()
    var url: URL?
}

enum Region {
    static let all: [Country] = [
        .init(code: "VE", name: "Venezuela"), .init(code: "CO", name: "Colombia"), .init(code: "MX", name: "México"),
        .init(code: "PE", name: "Perú"), .init(code: "CL", name: "Chile"), .init(code: "AR", name: "Argentina"),
        .init(code: "EC", name: "Ecuador"), .init(code: "PA", name: "Panamá"), .init(code: "DO", name: "República Dominicana"),
        .init(code: "ES", name: "España"), .init(code: "US", name: "Estados Unidos"), .init(code: "BR", name: "Brasil"),
        .init(code: "XX", name: "Otro país")
    ]

    private static let byTimeZone: [String: String] = [
        "America/Caracas": "VE", "America/Bogota": "CO", "America/Mexico_City": "MX", "America/Monterrey": "MX",
        "America/Cancun": "MX", "America/Tijuana": "MX", "America/Merida": "MX", "America/Lima": "PE",
        "America/Santiago": "CL", "America/Argentina/Buenos_Aires": "AR", "America/Buenos_Aires": "AR",
        "America/Guayaquil": "EC", "America/Panama": "PA", "America/Santo_Domingo": "DO", "Europe/Madrid": "ES",
        "Atlantic/Canary": "ES", "America/Sao_Paulo": "BR", "America/New_York": "US", "America/Chicago": "US",
        "America/Denver": "US", "America/Los_Angeles": "US", "America/Phoenix": "US"
    ]

    /// "es_VE" or "es-VE" → "VE".
    static func code(fromLocale identifier: String) -> String? {
        let parts = identifier.split(whereSeparator: { $0 == "_" || $0 == "-" })
        guard parts.count >= 2, let last = parts.last, last.count == 2 else { return nil }
        return last.uppercased()
    }

    static func name(_ code: String) -> String {
        all.first { $0.code == code }?.name ?? code
    }

    /// The person's country: by time zone first (Venezuela is America/Caracas), then by the server, then by the phone's region.
    static func detect(timeZone: String, serverCountry: String?, phoneRegion: String?) -> String {
        if let code = byTimeZone[timeZone] { return code }
        let known = Set(all.map(\.code))
        if let code = serverCountry?.uppercased(), !code.isEmpty { return known.contains(code) ? code : "XX" }
        if let code = phoneRegion?.uppercased(), known.contains(code) { return code }
        return "XX"
    }

    /// Venezuela pays with Pago Móvil too; everywhere else, card and stablecoins.
    static func methods(for code: String) -> [PayMethod] {
        code == "VE" ? [.pagoMovil, .usdt, .usdc, .card] : [.card, .usdt, .usdc]
    }
}

// MARK: - Slash commands

struct SlashCommand: Identifiable, Equatable {
    enum Run: Equatable { case voice, browser, fast, advanced, temporary, newChat, research, dev }
    enum Action: Equatable {
        /// Adds an instruction for Lithium in front of what the person writes.
        case prefix(String, web: Bool, placeholder: String)
        case create(CreationKind)
        case mode(ChatMode)
        case run(Run)
    }

    let key: String
    let icon: String
    let title: String
    let detail: String
    let action: Action
    var id: String { key }

    static let all: [SlashCommand] = [
        .init(key: "pagina", icon: "chevron.left.forwardslash.chevron.right", title: "Página web", detail: "Una página o app que se ve en vivo",
              action: .prefix("Crea una página web completa, moderna y bonita (un solo archivo HTML) para: ", web: false, placeholder: "Describe la página: de qué es, qué secciones, qué estilo")),
        .init(key: "presentacion", icon: "play.rectangle", title: "Presentación", detail: "Diapositivas en vivo, a pantalla completa",
              action: .prefix("Haz una presentación en HTML con diapositivas a pantalla completa sobre: ", web: false, placeholder: "¿De qué es la presentación y para quién?")),
        .init(key: "documento", icon: "doc.text", title: "Documento", detail: "Un Word o PDF listo para descargar",
              action: .prefix("Hazme un documento en Word sobre: ", web: false, placeholder: "¿Qué documento necesitas?")),
        .init(key: "codigo", icon: "curlybraces", title: "Código", detail: "En cualquier lenguaje",
              action: .prefix("Escribe el código para: ", web: false, placeholder: "¿Qué tiene que hacer el código?")),
        .init(key: "investigar", icon: "books.vertical", title: "Investigación a fondo", detail: "Muchas fuentes y un informe con citas", action: .run(.research)),
        .init(key: "dev", icon: "chevron.left.forwardslash.chevron.right", title: "Kuolki Dev", detail: "Un agente que programa dentro de tu proyecto", action: .run(.dev)),
        .init(key: "buscar", icon: "magnifyingglass", title: "Buscar en internet", detail: "Con fuentes actuales",
              action: .prefix("Busca en internet y respóndeme con fuentes: ", web: true, placeholder: "¿Qué quieres buscar?")),
        .init(key: "leer", icon: "globe", title: "Leer una página", detail: "Pega un enlace y Lithium lo lee",
              action: .prefix("Abre esta página y explícame lo importante: ", web: true, placeholder: "Pega el enlace")),
        .init(key: "resumir", icon: "text.alignleft", title: "Resumir", detail: "Puntos clave de un texto o archivo",
              action: .prefix("Resume en puntos clave: ", web: false, placeholder: "Pega el texto o adjunta el archivo")),
        .init(key: "traducir", icon: "character.bubble", title: "Traducir", detail: "A cualquier idioma",
              action: .prefix("Traduce esto (si no digo a qué idioma, al inglés): ", web: false, placeholder: "Escribe el texto y, si quieres, el idioma")),
        .init(key: "imagen", icon: "photo", title: "Crear imagen", detail: "1 crédito", action: .create(.image)),
        .init(key: "video", icon: "video", title: "Crear video de 5 s", detail: "5 créditos", action: .create(.video)),
        .init(key: "voz", icon: "waveform", title: "Conversación en vivo", detail: "Habla y Lithium te responde en voz alta", action: .run(.voice)),
        .init(key: "navegador", icon: "safari", title: "Navegador", detail: "Abre páginas sin salir de Kuolki", action: .run(.browser)),
        .init(key: "rapido", icon: "bolt", title: "Modo rápido", detail: "Respuestas al instante", action: .run(.fast)),
        .init(key: "avanzado", icon: "gauge.with.dots.needle.67percent", title: "Modo avanzado", detail: "Piensa antes de responder", action: .run(.advanced)),
        .init(key: "emprendedor", icon: "storefront", title: "Modo Emprendedor", detail: "Ventas, WhatsApp e Instagram", action: .mode(.emprendedor)),
        .init(key: "estudiante", icon: "book", title: "Modo Estudiante", detail: "Explicaciones paso a paso", action: .mode(.estudiante)),
        .init(key: "empleo", icon: "briefcase", title: "Modo Empleo", detail: "CV, cartas y entrevistas", action: .mode(.empleo)),
        .init(key: "diadia", icon: "house", title: "Modo Día a día", detail: "Correos, recetas y trámites", action: .mode(.diadia)),
        .init(key: "temporal", icon: "hourglass", title: "Chat temporal", detail: "No se guarda en tu historial", action: .run(.temporary)),
        .init(key: "nuevo", icon: "square.and.pencil", title: "Nuevo chat", detail: "Empieza de cero", action: .run(.newChat))
    ]

    static func find(_ key: String) -> SlashCommand? {
        let folded = fold(key)
        return all.first { $0.key == folded }
    }

    /// Commands for what is typed after "/", by name or by description.
    static func matches(_ query: String) -> [SlashCommand] {
        let q = fold(query)
        if q.isEmpty { return all }
        return all.filter { $0.key.hasPrefix(q) || fold($0.title).contains(q) }
    }

    /// The draft "/cmd rest": the command and the rest of the text, if the command exists.
    static func parse(_ draft: String) -> (command: SlashCommand, rest: String)? {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("/") else { return nil }
        let body = text.dropFirst()
        let word = body.prefix(while: { !$0.isWhitespace })
        guard !word.isEmpty, let command = find(String(word)) else { return nil }
        let rest = body.dropFirst(word.count).trimmingCharacters(in: .whitespacesAndNewlines)
        return (command, rest)
    }

    /// The text still being typed right after "/", or nil when the list should be hidden.
    static func typing(_ draft: String) -> String? {
        guard draft.hasPrefix("/"), !draft.contains(" "), !draft.contains("\n") else { return nil }
        return String(draft.dropFirst())
    }

    var prefix: String? {
        if case .prefix(let text, _, _) = action { return text }
        return nil
    }

    var placeholder: String? {
        if case .prefix(_, _, let text) = action { return text }
        return nil
    }

    var searchesWeb: Bool {
        if case .prefix(_, let web, _) = action { return web }
        return false
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es")).lowercased()
    }
}

// MARK: - Live pages and presentations (artifacts)

/// A complete HTML file (or an SVG) in an answer, shown as a live preview.
struct ArtifactDoc: Identifiable, Equatable {
    enum Kind: String, Equatable { case page, slides, svg, pdf }

    var index: Int
    var kind: Kind
    var code: String
    var title: String
    var closed: Bool
    var lines: Int
    var id: String { "\(index)-\(title)" }

    var kindName: String {
        switch kind {
        case .page: return "Página web"
        case .slides: return "Presentación"
        case .svg: return "Imagen SVG"
        case .pdf: return "PDF"
        }
    }

    var icon: String {
        switch kind {
        case .page: return "chevron.left.forwardslash.chevron.right"
        case .slides: return "play.rectangle"
        case .svg: return "photo"
        case .pdf: return "doc.richtext"
        }
    }

    var fileExtension: String { kind == .svg ? "svg" : "html" }

    /// What the preview loads. An SVG is centered on a white page.
    var html: String {
        guard kind == .svg else { return code }
        return "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"></head><body style=\"margin:0;min-height:100vh;display:grid;place-items:center;background:#fff\">\(code)</body></html>"
    }

    static func kind(lang: String, code: String) -> Kind? {
        let l = lang.lowercased()
        let lower = code.lowercased()
        if (l == "svg" || l == "xml") && lower.contains("<svg") { return .svg }
        guard l == "html" || l == "htm" || l.isEmpty else { return nil }
        guard lower.contains("<!doctype html") || lower.contains("<html>") || lower.contains("<html ") else { return nil }
        if PagePDF.isPrintDoc(code) { return .pdf }
        let pageTitle = title(in: code) ?? ""
        let titleSaysSlides = pageTitle.lowercased().range(of: #"presentaci[oó]n|\bslides?\b|diapositivas"#, options: .regularExpression) != nil
        let classSaysSlides = lower.range(of: #"class=["'][^"']*\b(slide|slides|diapositiva)\b"#, options: .regularExpression) != nil
        return titleSaysSlides || classSaysSlides ? .slides : .page
    }

    static func title(in code: String) -> String? {
        guard let start = code.range(of: "<title", options: .caseInsensitive),
              let open = code[start.upperBound...].firstIndex(of: ">"),
              let end = code.range(of: "</title>", options: .caseInsensitive, range: open..<code.endIndex) else { return nil }
        let raw = code[code.index(after: open)..<end.lowerBound]
        let text = raw.replacingOccurrences(of: "&amp;", with: "&").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text.prefix(120))
    }

    /// Every live page in a Markdown answer, in order, including one still being written.
    static func find(in markdown: String) -> [ArtifactDoc] {
        let lines = markdown.replacingOccurrences(of: "\r", with: "").components(separatedBy: "\n")
        var found: [ArtifactDoc] = []
        var i = 0
        while i < lines.count {
            guard lines[i].hasPrefix("```") else { i += 1; continue }
            let lang = String(lines[i].dropFirst(3)).trimmingCharacters(in: .whitespaces)
            var body: [String] = []
            var j = i + 1
            while j < lines.count, !lines[j].hasPrefix("```") {
                body.append(lines[j])
                j += 1
            }
            let code = body.joined(separator: "\n")
            if let kind = kind(lang: lang, code: code) {
                let name: String
                switch kind {
                case .page: name = "Página web"
                case .slides: name = "Presentación"
                case .svg: name = "Imagen SVG"
                case .pdf: name = "Documento"
                }
                found.append(ArtifactDoc(index: found.count, kind: kind, code: code, title: title(in: code) ?? name,
                                         closed: j < lines.count, lines: body.count))
            }
            i = j + 1
        }
        return found
    }
}
