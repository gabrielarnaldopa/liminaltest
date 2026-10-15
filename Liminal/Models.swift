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

enum Engine: String, Codable, CaseIterable, Identifiable, Hashable {
    case deepseek, qwen, glm
    var id: String { rawValue }

    var name: String {
        switch self {
        case .deepseek: return "DeepSeek V4 Pro"
        case .qwen: return "Qwen 3.6"
        case .glm: return "GLM-5.2"
        }
    }

    var note: String {
        switch self {
        case .deepseek: return "Recomendado. Buen equilibrio entre calidad y velocidad."
        case .qwen: return "Fuerte en español y en varios idiomas."
        case .glm: return "Para razonamientos largos y paso a paso."
        }
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

enum PlanKind: String, Codable, CaseIterable, Identifiable {
    case mensual, semanal
    var id: String { rawValue }
    var name: String { self == .mensual ? "Mensual" : "Semanal" }
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
    var files: [String]
    var feedback: Feedback?
    var stopped: Bool
    var isPending: Bool
    var isStreaming: Bool
    var date: Date

    init(role: Role, text: String, tier: Tier = .fast, effort: Effort = .medio, engine: Engine = .deepseek,
         mode: ChatMode = .general, thinkingSeconds: Int = 0, thought: [String] = [], files: [String] = []) {
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
        self.stopped = false
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
}

struct AdminConfig: Codable, Equatable {
    var priceMonthly: Double
    var priceWeekly: Double
    var advCap: Int
    var weekCap: Int
    var fastCap: Int
    var margin: Double
    var enabledEngines: Set<Engine>

    static let defaults = AdminConfig(priceMonthly: 11, priceWeekly: 3, advCap: 65, weekCap: 450, fastCap: 200,
                                      margin: 60, enabledEngines: Set(Engine.allCases))

    /// Dollars per million tokens for DeepSeek V4 Pro, mixing input and output.
    static let costPerMillionTokens = 0.56

    var computeBudget: Double { max(0, priceMonthly * (1 - margin / 100)) }
    var millionTokens: Double { computeBudget / Self.costPerMillionTokens }
    /// True when someone using the whole weekly cap still fits the budget (2,000 tokens per message).
    var weeklyCapFits: Bool { Double(weekCap * 4 * 2000) / 1_000_000 <= millionTokens }
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
    var network: Network
    var status: PaymentStatus
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
    var telegramLinked: Bool
}
