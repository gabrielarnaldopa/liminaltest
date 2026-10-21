import Foundation

// MARK: - Choices

enum ChatMode: String, Codable, CaseIterable, Identifiable, Hashable {
    case general, emprendedor, estudiante, empleo, diadia

    var id: String { rawValue }

    var name: String {
        switch self {
        case .general: return "General"
        case .emprendedor: return "Emprendedor"
        case .estudiante: return "Estudiante"
        case .empleo: return "Empleo"
        case .diadia: return "Día a día"
        }
    }

    var icon: String {
        switch self {
        case .general: return "sparkles"
        case .emprendedor: return "storefront"
        case .estudiante: return "book"
        case .empleo: return "briefcase"
        case .diadia: return "house"
        }
    }

    var summary: String {
        switch self {
        case .general: return "Para cualquier cosa."
        case .emprendedor: return "Ventas, catálogos y clientes."
        case .estudiante: return "Explicaciones, resúmenes y práctica."
        case .empleo: return "CV, cartas y entrevistas."
        case .diadia: return "Correos, organización y recetas."
        }
    }

    var example: String {
        switch self {
        case .general: return ""
        case .emprendedor: return "Escribe un mensaje para ofrecer mis productos por WhatsApp"
        case .estudiante: return "Explícame la fotosíntesis paso a paso"
        case .empleo: return "Mejora mi CV para un puesto de atención al cliente"
        case .diadia: return "Organiza mi semana con estas tareas:"
        }
    }
}

enum Tier: String, Codable, CaseIterable, Identifiable, Hashable {
    case fast, adv
    var id: String { rawValue }
    var name: String { self == .fast ? "Rápido" : "Avanzado" }
    var icon: String { self == .fast ? "bolt" : "gauge.with.dots.needle.50percent" }
}

enum Effort: String, Codable, CaseIterable, Identifiable, Hashable {
    case bajo, medio, alto
    var id: String { rawValue }

    var name: String {
        switch self {
        case .bajo: return "Bajo"
        case .medio: return "Medio"
        case .alto: return "Alto"
        }
    }

    /// Seconds the advanced model "thinks" in the demo.
    var seconds: Int {
        switch self {
        case .bajo: return 1
        case .medio: return 3
        case .alto: return 6
        }
    }

    var delayMilliseconds: Int {
        switch self {
        case .bajo: return 900
        case .medio: return 1800
        case .alto: return 3200
        }
    }

    /// Messages taken from the 5-hour window.
    var cost: Int { self == .alto ? 2 : 1 }

    var note: String {
        switch self {
        case .bajo: return "Responde más rápido y razona poco."
        case .medio: return "El equilibrio para casi todo."
        case .alto: return "Razona a fondo. Cuenta doble en tu ventana de 5 horas."
        }
    }
}

/// The one model name customers see. Change it here and it changes everywhere.
enum Brand {
    static let modelName = "Lithium 1.1"
    /// The web app, where plans are paid with Pago Móvil, USDT, USDC or card. Administración can change it.
    static let webApp = "https://gabrielarnaldopa.github.io/kuolki/"
    /// Shows «Pagar en la web» next to «Pagar con Apple». Set it to false to sell only through Apple.
    static let webPayButton = true
}

/// Engines behind Lithium 1.1. Only the admin sees them.
enum Engine: String, Codable, CaseIterable, Identifiable, Hashable {
    case deepseek, qwen, glm
    var id: String { rawValue }

    var name: String {
        switch self {
        case .deepseek: return "DeepSeek V4.1 Flash"
        case .qwen: return "Qwen 3.6"
        case .glm: return "GLM-5.2"
        }
    }

    var note: String {
        switch self {
        case .deepseek: return "Principal: razonamiento y calidad."
        case .qwen: return "Respaldo: fuerte en español."
        case .glm: return "Respaldo: razonamientos largos."
        }
    }

    /// Engines saved by older versions become DeepSeek.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Engine(rawValue: raw) ?? .deepseek
    }
}

enum Tone: String, Codable, CaseIterable, Identifiable {
    case cercano, profesional, directo
    var id: String { rawValue }
    var name: String {
        switch self {
        case .cercano: return "Cercano"
        case .profesional: return "Profesional"
        case .directo: return "Directo"
        }
    }
}

enum ThemeChoice: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var name: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }
}

/// The three typefaces for the whole app.
enum FontFamily: String, Codable, CaseIterable, Identifiable {
    case kuolki, sistema, clasica
    var id: String { rawValue }
    var name: String {
        switch self {
        case .kuolki: return "Kuolki"
        case .sistema: return "Sistema"
        case .clasica: return "Clásica"
        }
    }
    var detail: String {
        switch self {
        case .kuolki: return "Bricolage Grotesque, la de la marca"
        case .sistema: return "La letra del iPhone"
        case .clasica: return "Con serifa, para leer largo"
        }
    }
}

enum FontScale: String, Codable, CaseIterable, Identifiable {
    case pequena, normal, grande
    var id: String { rawValue }
    var name: String {
        switch self {
        case .pequena: return "Pequeña"
        case .normal: return "Normal"
        case .grande: return "Grande"
        }
    }
}

enum Network: String, Codable, CaseIterable, Identifiable {
    case tron, base, solana
    var id: String { rawValue }
    var name: String {
        switch self {
        case .tron: return "Tron"
        case .base: return "Base"
        case .solana: return "Solana"
        }
    }
}

/// The plans, in dollars with IVA included. Each one gets the Mensual limits times its factor.
enum PlanKind: String, Codable, CaseIterable, Identifiable {
    case gratis, semanal, mensual
    case x5 = "5x"
    case x20 = "20x"
    var id: String { rawValue }

    var name: String {
        switch self {
        case .gratis: return "Gratis"
        case .semanal: return "Semanal"
        case .mensual: return "Mensual"
        case .x5: return "Mensual 5×"
        case .x20: return "Mensual 20×"
        }
    }
    var isFree: Bool { self == .gratis }
    /// Plans that can also be paid for a whole year.
    var hasAnnual: Bool { self == .mensual || self == .x5 || self == .x20 }
    var unit: String { self == .semanal ? "por semana" : "al mes" }

    /// Price in dollars. Mensual and Semanal follow Administración; the yearly Mensual costs ten months.
    func price(annual: Bool, admin: AdminConfig) -> Double {
        let yearly = annual && hasAnnual
        switch self {
        case .gratis: return 0
        case .semanal: return admin.priceWeekly
        case .mensual: return yearly ? admin.priceMonthly * 10 : admin.priceMonthly
        case .x5: return yearly ? 588 : 59
        case .x20: return yearly ? 2148 : 199
        }
    }

    /// Times the Mensual limits: Gratis gets a tenth of the session and a twelfth of the week.
    var sessionFactor: Double {
        switch self {
        case .gratis: return 0.1
        case .semanal, .mensual: return 1
        case .x5: return 5
        case .x20: return 20
        }
    }
    var weekFactor: Double { self == .gratis ? 1.0 / 12 : sessionFactor }

    var research: String {
        switch self {
        case .gratis: return "1 investigación a fondo por semana"
        case .semanal, .mensual: return "10 investigaciones a fondo por semana"
        case .x5: return "50 investigaciones a fondo por semana"
        case .x20: return "Investigaciones a fondo sin un tope aparte"
        }
    }

    /// Days a payment adds.
    func days(annual: Bool) -> Double { annual && hasAnnual ? 365 : self == .semanal ? 7 : 30 }

    /// The App Store subscription for this plan; Gratis has none.
    func productID(annual: Bool) -> String? {
        let yearly = annual && hasAnnual
        switch self {
        case .gratis: return nil
        case .semanal: return "kuolki.semanal"
        case .mensual: return yearly ? "kuolki.mensual.anual" : "kuolki.mensual"
        case .x5: return yearly ? "kuolki.5x.anual" : "kuolki.5x"
        case .x20: return yearly ? "kuolki.20x.anual" : "kuolki.20x"
        }
    }

    static var productIDs: [String] {
        var ids: [String] = []
        for plan in allCases {
            for annual in [false, true] {
                if let id = plan.productID(annual: annual), !ids.contains(id) { ids.append(id) }
            }
        }
        return ids
    }

    static func from(productID: String) -> (plan: PlanKind, annual: Bool)? {
        for plan in allCases {
            for annual in [false, true] where plan.productID(annual: annual) == productID {
                return (plan, annual && plan.hasAnnual)
            }
        }
        return nil
    }
}

enum UserStatus: String, Codable, CaseIterable, Identifiable {
    case activo, vence, suspendido
    var id: String { rawValue }
    var label: String {
        switch self {
        case .activo: return "Activo"
        case .vence: return "Por vencer"
        case .suspendido: return "Suspendido"
        }
    }
    var level: StatusLevel {
        switch self {
        case .activo: return .good
        case .vence: return .warn
        case .suspendido: return .bad
        }
    }
}

enum PaymentStatus: String, Codable, CaseIterable, Identifiable {
    case confirmado, pendiente, fallido
    var id: String { rawValue }
    var label: String {
        switch self {
        case .confirmado: return "Confirmado"
        case .pendiente: return "Pendiente"
        case .fallido: return "Fallido"
        }
    }
    var level: StatusLevel {
        switch self {
        case .confirmado: return .good
        case .pendiente: return .warn
        case .fallido: return .bad
        }
    }
}

/// Images and videos are paid with monthly credits. One credit costs about $0.02 with the provider.
enum CreationKind: String, Codable, CaseIterable, Identifiable {
    case image, video
    var id: String { rawValue }

    var name: String { self == .image ? "Imagen" : "Video de 5 s" }
    var icon: String { self == .image ? "photo" : "video" }
    var credits: Int { self == .image ? 1 : 5 }
    var creditsText: String { credits == 1 ? "1 crédito" : "\(credits) créditos" }
    var placeholder: String { self == .image ? "Describe la imagen que quieres crear" : "Describe el video que quieres crear" }
    var pendingText: String {
        self == .image ? "Creando tu imagen…" : "Creando tu video de 5 segundos… tarda un poco más que una imagen."
    }
    var doneText: String { self == .image ? "Aquí está tu imagen." : "Aquí está tu video de 5 segundos." }
    /// What the Dynamic Island says while it is being made, and when it is ready.
    var activityTitle: String { self == .image ? "Creando tu imagen" : "Creando tu video" }
    var readyTitle: String { self == .image ? "Tu imagen está lista" : "Tu video está listo" }
    var delayMilliseconds: Int { self == .image ? 2600 : 4800 }
}

/// Extra credits people can buy when they run out.
enum ExtraPack {
    static let credits = 100
    static let price = 6.0
}

// MARK: - Files

enum FileKind: String, Codable {
    case pdf, word, audio, image, text, sheet, other

    var label: String {
        switch self {
        case .pdf: return "PDF"
        case .word: return "Word"
        case .audio: return "Audio"
        case .image: return "Imagen"
        case .text: return "Texto"
        case .sheet: return "Hoja de cálculo"
        case .other: return "Archivo"
        }
    }

    var icon: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .word: return "doc.text"
        case .audio: return "waveform"
        case .image: return "photo"
        case .text: return "doc.plaintext"
        case .sheet: return "tablecells"
        case .other: return "doc"
        }
    }
}

/// A file attached to a message, with what Lithium could read from it.
struct Attachment: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var size: Int
    var kind: FileKind
    var pages: Int? = nil
    var duration: Double? = nil
    var width: Int? = nil
    var height: Int? = nil
    /// JPEG thumbnail for images.
    var thumbnail: Data? = nil
    /// Text read from PDFs and text files (up to 8,000 characters).
    var text: String = ""
    var isReading = false
    var failed = false

    var detail: String {
        if isReading { return "Leyendo…" }
        if failed { return "No se pudo leer" }
        switch kind {
        case .pdf:
            if let pages { return pages == 1 ? "PDF · 1 página" : "PDF · \(pages) páginas" }
        case .audio:
            if let duration, duration > 0 { return "Audio · \(Attachment.clock(duration))" }
        case .image:
            if let width, let height { return "Imagen · \(width)×\(height)" }
        default:
            break
        }
        return size > 0 ? "\(kind.label) · \(AppStore.sizeText(size))" : kind.label
    }

    static func clock(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return "\(total / 60):" + String(format: "%02d", total % 60)
    }
}

// MARK: - Memory, connectors and payments

enum MemoryCategory: String, Codable, CaseIterable, Identifiable {
    case perfil, negocio, preferencias
    var id: String { rawValue }
    var name: String {
        switch self {
        case .perfil: return "Sobre ti"
        case .negocio: return "Tu negocio"
        case .preferencias: return "Cómo te gusta que responda"
        }
    }
}

/// Apps Lithium can work with through MCP.
enum ConnectorKind: String, Codable, CaseIterable, Identifiable {
    case drive, gmail, calendar, notion, whatsapp, instagram
    var id: String { rawValue }

    var name: String {
        switch self {
        case .drive: return "Google Drive"
        case .gmail: return "Gmail"
        case .calendar: return "Google Calendar"
        case .notion: return "Notion"
        case .whatsapp: return "WhatsApp Business"
        case .instagram: return "Instagram"
        }
    }

    var note: String {
        switch self {
        case .drive: return "Busca y lee tus documentos."
        case .gmail: return "Resume y redacta correos."
        case .calendar: return "Crea eventos y recordatorios."
        case .notion: return "Consulta y edita tus páginas."
        case .whatsapp: return "Responde a tus clientes desde Lithium."
        case .instagram: return "Programa publicaciones y lee mensajes."
        }
    }

    var icon: String {
        switch self {
        case .drive: return "externaldrive"
        case .gmail: return "envelope"
        case .calendar: return "calendar"
        case .notion: return "book.closed"
        case .whatsapp: return "message"
        case .instagram: return "camera"
        }
    }
}

/// A person's own MCP server, for example their inventory system.
struct CustomConnector: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var url: String
}

enum PayMethod: String, CaseIterable, Identifiable {
    case pagoMovil, usdt, usdc, card
    var id: String { rawValue }
    var name: String {
        switch self {
        case .pagoMovil: return "Pago Móvil"
        case .usdt: return "USDT"
        case .usdc: return "USDC"
        case .card: return "Tarjeta"
        }
    }
    var icon: String {
        switch self {
        case .pagoMovil: return "iphone"
        case .usdt, .usdc: return "dollarsign.circle"
        case .card: return "creditcard"
        }
    }
    /// Networks each stablecoin can be sent on.
    var networks: [Network] {
        switch self {
        case .usdt: return [.tron, .solana]
        case .usdc: return [.base, .solana]
        default: return []
        }
    }
}

/// How Kuolki gets paid. The server updates the BCV rates every day.
struct PaymentSettings: Codable, Equatable {
    var rateEur: Double
    var rateUsd: Double
    var rateDate: Date
    /// Pago Móvil uses the euro rate when true, the dollar rate when false.
    var useEuroRate: Bool
    var mobileBank: String
    var mobilePhone: String
    var mobileID: String
    var walletTron: String
    var walletBase: String
    var walletSolana: String

    static var defaults: PaymentSettings {
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 10
        parts.day = 14
        return PaymentSettings(rateEur: 982.76, rateUsd: 877.90, rateDate: Calendar.current.date(from: parts) ?? Date(),
                               useEuroRate: true, mobileBank: "0102 · Banco de Venezuela", mobilePhone: "0414-000-0000",
                               mobileID: "J-00000000-0", walletTron: "", walletBase: "", walletSolana: "")
    }

    var rate: Double { useEuroRate ? rateEur : rateUsd }

    func wallet(for network: Network) -> String {
        switch network {
        case .tron: return walletTron
        case .base: return walletBase
        case .solana: return walletSolana
        }
    }
}

enum Role: String, Codable { case user, bot }
enum Feedback: String, Codable { case up, down }

enum Route: Hashable {
    case home
    case chat(UUID)
    case project(UUID)
    case admin
}

struct IDBox: Identifiable { let id: UUID }

// MARK: - Content

/// One version of a message you edited: its text and files, and the conversation that followed it.
struct MessageVersion: Codable, Equatable {
    var text: String
    var files: [Attachment]
    var command: String?
    var after: [Message]
}

struct Message: Codable, Identifiable, Equatable {
    var id: UUID
    var role: Role
    var text: String
    var tier: Tier
    var effort: Effort
    var engine: Engine
    var mode: ChatMode
    var thinkingSeconds: Int
    var thought: [String]
    var files: [Attachment]
    var feedback: Feedback?
    var searchedWeb: Bool
    var sources: [String]
    /// A memory saved from this message, shown with an undo button.
    var savedMemory: Memory?
    var edited: Bool
    var isReading: Bool
    var stopped: Bool
    /// Set when the answer is a created image or video.
    var kind: CreationKind?
    var prompt: String?
    var seed: UInt32?
    var isPending: Bool
    var isStreaming: Bool
    var date: Date
    /// Said out loud in a live conversation.
    var spoken: Bool? = nil
    /// The slash command used to write this message (for example "pagina").
    var command: String? = nil
    /// The answer's id on the server: it keeps running there if the app closes.
    var jobID: String? = nil
    /// Text written before this job started (an answer continued after a permission question).
    var jobBase: String? = nil
    /// Searches and pages Lithium used, and the pages it cites.
    var tools: [ToolStep]? = nil
    var links: [SourceLink]? = nil
    /// Lithium waits for permission to search or open a site.
    var ask: AskRequest? = nil
    /// For example: the answer was cut because it was too long.
    var notice: String? = nil
    /// Earlier versions of a message you edited and sent again; versionIndex is the one on screen.
    var versions: [MessageVersion]? = nil
    var versionIndex: Int? = nil

    init(role: Role, text: String, tier: Tier = .fast, effort: Effort = .medio, engine: Engine = .deepseek,
         mode: ChatMode = .general, thinkingSeconds: Int = 0, thought: [String] = [], files: [Attachment] = []) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.tier = tier
        self.effort = effort
        self.engine = engine
        self.mode = mode
        self.thinkingSeconds = thinkingSeconds
        self.thought = thought
        self.files = files
        self.feedback = nil
        self.searchedWeb = false
        self.sources = []
        self.savedMemory = nil
        self.edited = false
        self.isReading = false
        self.stopped = false
        self.kind = nil
        self.prompt = nil
        self.seed = nil
        self.isPending = false
        self.isStreaming = false
        self.date = Date()
    }
}

struct Chat: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var mode: ChatMode
    var projectID: UUID?
    var folderID: UUID?
    var pinned: Bool
    var updated: Date
    var messages: [Message]
    var isTemporary: Bool

    init(title: String, mode: ChatMode, projectID: UUID? = nil, folderID: UUID? = nil, pinned: Bool = false,
         updated: Date = Date(), messages: [Message] = [], isTemporary: Bool = false) {
        self.id = UUID()
        self.title = title
        self.mode = mode
        self.projectID = projectID
        self.folderID = folderID
        self.pinned = pinned
        self.updated = updated
        self.messages = messages
        self.isTemporary = isTemporary
    }
}

struct ProjectFile: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var size: String
}

struct Project: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var desc: String
    var colorHex: UInt32
    var instructions: String
    var files: [ProjectFile]
    var created: Date
}

struct Folder: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
}

struct Memory: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var category: MemoryCategory = .perfil
}

struct PointsEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var month: String
    var reason: String
    var points: Int
}

// MARK: - Settings, usage and admin

struct Usage: Codable, Equatable {
    var adv: Int
    var advCap: Int
    var week: Int
    var weekCap: Int
    var fast: Int
    var fastCap: Int
    var fastDay: String
    var resetAt: Date
    var weekResetAt: Date
    var credits: Int
    var creditsCap: Int
    var creditsResetAt: Date
    // Usage measured in tokens (dollars of compute), shared by the chat and Kuolki Dev.
    var sessionUSD: Double? = nil
    var sessionResetAt: Date? = nil
    var weekUSD: Double? = nil
    var weekTokens: Int? = nil
}

struct Prefs: Codable, Equatable {
    var name: String
    var language: String
    var tone: Tone
    var custom: String
    var theme: ThemeChoice
    var fontScale: FontScale
    var tier: Tier
    var effort: Effort
    var engine: Engine
    var defaultMode: ChatMode
    var showThinking: Bool
    var saveHistory: Bool
    var tempDefault: Bool
    var memory: Bool
    var network: Network
    var plan: PlanKind
    /// Show Lithium's progress in the Dynamic Island and on the Lock Screen. `nil` means on.
    var liveActivities: Bool? = nil
    /// How fast Lithium speaks in a live conversation. `nil` means normal.
    var voiceSpeed: VoiceSpeed? = nil
    /// Before entering a site Lithium asks (`nil`), goes ahead, or does not browse.
    var browse: BrowseMode? = nil
    /// Search without asking first.
    var allowSearch: Bool? = nil
    /// Sites Lithium can open without asking.
    var allowedHosts: [String]? = nil
    /// Notify when an answer finishes while the app is closed. `nil` means on.
    var notify: Bool? = nil
    /// The country chosen for paying; `nil` means detected.
    var region: String? = nil
    /// Pay the chosen plan for a year. `nil` means monthly.
    var annual: Bool? = nil
    /// The typeface. `nil` means Kuolki's own.
    var fontFamily: FontFamily? = nil
}

/// How fast Lithium speaks in a live conversation.
enum VoiceSpeed: String, Codable, CaseIterable, Identifiable {
    case calmada, normal, rapida
    var id: String { rawValue }

    var name: String {
        switch self {
        case .calmada: return "Calmada"
        case .normal: return "Normal"
        case .rapida: return "Rápida"
        }
    }

    /// Speech rate for AVSpeechUtterance, where 0.5 is the iPhone's normal speed.
    var rate: Float {
        switch self {
        case .calmada: return 0.44
        case .normal: return 0.5
        case .rapida: return 0.56
        }
    }
}

/// What Lithium says in a live conversation, and whether the conversation ends after it.
struct VoiceAnswer: Equatable {
    var text: String
    var ends: Bool = false
    /// A demo answer that the server should replace when it is connected.
    var generic: Bool = false
}

struct AdminConfig: Codable, Equatable {
    var priceMonthly: Double
    var priceWeekly: Double
    var advCap: Int
    var weekCap: Int
    var fastCap: Int
    var margin: Double
    var enabledEngines: Set<Engine>
    /// Image and video credits per month, and what one credit costs with the provider.
    var creditsCap: Int
    var creditCost: Double
    /// The Lithium server: its address and the app key chosen when it was created. Empty means demo answers.
    var serverURL: String? = nil
    var serverKey: String? = nil
    /// The web app on GitHub Pages, where Kuolki Dev runs.
    var webAppURL: String? = nil

    static let defaults = AdminConfig(priceMonthly: 12, priceWeekly: 4, advCap: 65, weekCap: 450, fastCap: 200,
                                      margin: 60, enabledEngines: Set(Engine.allCases), creditsCap: 100, creditCost: 0.021)

    /// Dollars per million tokens for DeepSeek V4.1 Flash (October 2026),
    /// with 60% of the input cached and 85% of use off-peak in Venezuela.
    static let costPerMillionTokens = 0.25

    var computeBudget: Double { max(0, priceMonthly * (1 - margin / 100)) }
    var millionTokens: Double { computeBudget / Self.costPerMillionTokens }
    /// True when someone using the whole weekly cap still fits the budget (2,000 tokens per message).
    var weeklyCapFits: Bool { Double(weekCap * 4 * 2000) / 1_000_000 <= millionTokens }

    /// Text cost if someone uses the whole weekly limit every week.
    var maxTextCost: Double { Double(weekCap * 4 * 2000) / 1_000_000 * Self.costPerMillionTokens }
    /// Image and video cost if someone uses all their credits.
    var maxMediaCost: Double { Double(creditsCap) * creditCost }
    var maxTotalCost: Double { maxTextCost + maxMediaCost }
    /// True when even a subscriber who uses everything stays within the budget.
    var worstCaseFits: Bool { maxTotalCost <= computeBudget + 0.000_001 }
}

struct AdminUser: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var email: String
    var plan: PlanKind
    var status: UserStatus
    var advThisWeek: Int
    var points: Int
    var lastSeen: Date
    var isAdmin: Bool
}

struct Payment: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var email: String
    var plan: PlanKind
    var amount: String
    /// For example "USDT · Tron" or "Pago Móvil · Banesco".
    var method: String
    var status: PaymentStatus
    var reference: String = ""
    /// Paid for a whole year.
    var annual: Bool? = nil
}

struct AppState: Codable, Equatable {
    var version: Int
    var prefs: Prefs
    var usage: Usage
    var points: Int
    var referralCode: String
    var pointsHistory: [PointsEntry]
    var memories: [Memory]
    var projects: [Project]
    var folders: [Folder]
    var chats: [Chat]
    var admin: AdminConfig
    var users: [AdminUser]
    var payments: [Payment]
    var paidUntil: Date
    var connectors: Set<ConnectorKind>
    var customConnectors: [CustomConnector]
    var pay: PaymentSettings
}
