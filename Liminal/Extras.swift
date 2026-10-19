import SwiftUI
import UIKit

// MARK: - Photos for the server

/// A lighter copy of each photo, kept only while it waits to be sent (never saved in the chats).
enum VisionCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storage: [UUID: String] = [:]
    static func get(_ id: UUID) -> String? { lock.lock(); defer { lock.unlock() }; return storage[id] }
    static func set(_ id: UUID, _ value: String?) { lock.lock(); storage[id] = value; lock.unlock() }

    /// At most 1,600 pixels on the longest side, as JPEG: enough to read a receipt, light on 3G.
    static func store(_ image: UIImage, for id: UUID) {
        let longest = max(image.size.width, image.size.height)
        let ratio = longest > 1600 ? 1600 / longest : 1
        let size = CGSize(width: max(1, image.size.width * ratio), height: max(1, image.size.height * ratio))
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let data = resized.jpegData(compressionQuality: 0.8) else { return }
        set(id, "data:image/jpeg;base64," + data.base64EncodedString())
    }
}

// MARK: - Usage, measured in tokens

/// Tokens of one answer, as the server reports them (photos are counted apart).
struct TokenUsage: Equatable, Sendable {
    var input = 0
    var cached = 0
    var output = 0
    var visionInput = 0
    var visionOutput = 0
}

/// One measure for the whole plan, like on the web: answers fill the 5-hour session and the week,
/// priced at the engine's real rates (half price off-peak). Both modes use V4.1 Flash; Advanced spends more because it thinks.
enum UsagePrice {
    struct Rates { let hit: Double; let miss: Double; let out: Double }
    static let advanced = Rates(hit: 0.006, miss: 0.3, out: 1.2)     // USD per 1M tokens at peak hours: V4.1 Flash, thinking more
    static let fast = Rates(hit: 0.006, miss: 0.3, out: 1.2)
    static let sessionLimit = 0.25                                     // USD of compute per 5 hours
    static let weekLimit = 1.0                                         // USD of compute per week

    static func isOffPeak(_ date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)   // 1 = Sunday
        let weekdayPeak = (2...6).contains(weekday) && ((1..<4).contains(hour) || (6..<10).contains(hour))
        return !weekdayPeak
    }

    static func cost(_ usage: TokenUsage, tier: Tier, at date: Date = Date()) -> Double {
        let rates = tier == .adv ? advanced : fast
        let hit = Double(min(usage.cached, usage.input))
        let miss = Double(usage.input) - hit
        let text = (miss * rates.miss + hit * rates.hit + Double(usage.output) * rates.out) / 1_000_000
        let photos = (Double(usage.visionInput) * 0.2 + Double(usage.visionOutput) * 1.6) / 1_000_000
        return text * (isOffPeak(date) ? 0.5 : 1) + photos
    }
}

extension AppStore {
    /// Brings the token meters up to date: a new session every 5 hours, a new week every 7 days.
    func checkTokenUsage() {
        let now = Date()
        if state.usage.sessionResetAt == nil || now > (state.usage.sessionResetAt ?? now) {
            state.usage.sessionUSD = 0
            state.usage.sessionResetAt = now.addingTimeInterval(5 * 3600)
        }
        if state.usage.weekUSD == nil || now > state.usage.weekResetAt {
            if now > state.usage.weekResetAt { state.usage.weekResetAt = now.addingTimeInterval(7 * 86400) }
            state.usage.weekUSD = 0
            state.usage.weekTokens = 0
        }
    }

    var sessionPercent: Double { checkTokenUsage(); return min(100, (state.usage.sessionUSD ?? 0) / UsagePrice.sessionLimit * 100) }
    var weekPercent: Double { checkTokenUsage(); return min(100, (state.usage.weekUSD ?? 0) / UsagePrice.weekLimit * 100) }

    /// Why a new message can't go out right now, or nil. Fast keeps working when a session runs out.
    func usageBlock(tier: Tier) -> String? {
        if weekPercent >= 100 { return "Llegaste al límite de esta semana. Se recarga \(Fmt.relative(state.usage.weekResetAt))." }
        if tier == .adv && sessionPercent >= 100 {
            return "Llegaste al límite de esta sesión. Se recarga \(Fmt.relative(state.usage.sessionResetAt ?? Date())); mientras tanto sigue con el modo rápido."
        }
        return nil
    }

    func addUsage(_ usage: TokenUsage, tier: Tier) {
        checkTokenUsage()
        if (state.usage.sessionUSD ?? 0) == 0 { state.usage.sessionResetAt = Date().addingTimeInterval(5 * 3600) }
        let cost = UsagePrice.cost(usage, tier: tier)
        state.usage.sessionUSD = (state.usage.sessionUSD ?? 0) + cost
        state.usage.weekUSD = (state.usage.weekUSD ?? 0) + cost
        state.usage.weekTokens = (state.usage.weekTokens ?? 0) + usage.input + usage.output
    }

    /// Without a server (demonstration), tokens are estimated from the text: about 4 characters per token.
    func countDemoUsage(characters: Int, tier: Tier) {
        guard LithiumClient(admin: state.admin) == nil else { return }
        addUsage(TokenUsage(input: (4000 + characters * 3) / 4, cached: 600, output: 450), tier: tier)
    }
}

/// A usage meter as a percentage.
struct PercentMeter: View {
    let title: String
    let percent: Double
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                Text(percent > 0 && percent < 1 ? "<1% usado" : "\(Int(percent))% usado")
                    .font(.subheadline).foregroundStyle(Palette.ink2)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.sunk)
                    Capsule().fill(percent >= 90 ? Palette.red : percent >= 70 ? Palette.yellow : Palette.green)
                        .frame(width: max(4, geo.size.width * percent / 100))
                }
            }
            .frame(height: 6)
            Text(detail).font(.caption).foregroundStyle(Palette.ink3)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Charts and calculators inside an answer

/// Draws a ```grafico or ```calculadora block with the same page the web app uses.
struct WidgetBlockView: View {
    let lang: String
    let code: String

    var isCalculator: Bool { lang.lowercased().hasPrefix("calc") }

    var html: String {
        let spec: [String: String] = ["kind": isCalculator ? "calc" : "chart", "code": code]
        let data = (try? JSONSerialization.data(withJSONObject: spec)) ?? Data("{}".utf8)
        let json = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "</", with: "<\\/")
        return WidgetPage.template.replacingOccurrences(of: "__SPEC__", with: json)
    }

    /// The web view can't size itself inside a list, so the height comes from what the block holds.
    var height: CGFloat {
        guard let data = code.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return 120 }
        if isCalculator {
            let fields = (json["campos"] as? [Any])?.count ?? 1
            let results = (json["resultados"] as? [Any])?.count ?? 1
            return 96 + CGFloat((fields + 1) / 2) * 66 + CGFloat(results) * 30
        }
        let kind = (json["tipo"] as? String ?? "").lowercased()
        if ["torta", "pie", "dona", "donut", "pastel"].contains(kind) {
            let parts = min(6, (json["etiquetas"] as? [Any])?.count ?? 3)
            return 330 + CGFloat(parts) * 24
        }
        let series = (json["series"] as? [Any])?.count ?? 1
        return 300 + (series > 1 ? 24 : 0)
    }

    var body: some View {
        WebView(content: .html(html))
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Liminal Dev on the iPhone

/// Liminal Dev runs as the web app does (projects, editor, preview, the agent), opened here with this
/// account and this server, so nothing has to be typed again.
struct DevWebSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""

    var target: URL? {
        guard let base = store.state.admin.webAppURL, var parts = URLComponents(string: base), parts.scheme?.hasPrefix("http") == true else { return nil }
        parts.queryItems = [URLQueryItem(name: "dev", value: "1")]
        var handoff: [String: Any] = ["email": store.accountEmail ?? "", "name": store.state.prefs.name]
        if let url = store.state.admin.serverURL, let key = store.state.admin.serverKey { handoff["api"] = ["url": url, "key": key] }
        if let data = try? JSONSerialization.data(withJSONObject: handoff) {
            parts.fragment = "lm=" + data.base64EncodedString()
        }
        return parts.url
    }

    var body: some View {
        NavigationStack {
            Group {
                if let target {
                    WebView(content: .url(target))
                        .ignoresSafeArea()
                } else {
                    Form {
                        Section {
                            Text("Liminal Dev usa la app web que publicaste en GitHub Pages. Pega su dirección una vez y se abre aquí con tu cuenta y tu servidor.")
                                .foregroundStyle(Palette.ink2)
                            TextField("https://tuusuario.github.io/liminal/", text: $address)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                            Button("Guardar y abrir") {
                                let clean = address.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard clean.hasPrefix("http") else { store.show("Escribe la dirección completa, con https://"); return }
                                store.state.admin.webAppURL = clean
                                store.scheduleSave()
                            }
                        } header: {
                            Text("Dirección de la app web")
                        }
                    }
                }
            }
            .navigationTitle("Liminal Dev")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                }
                if store.state.admin.webAppURL != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cambiar dirección") { store.state.admin.webAppURL = nil }
                    }
                }
            }
        }
    }
}

extension Fmt {
    /// 764800 → «764,8 K»; 1250000 → «1,3 M».
    static func tokens(_ n: Int) -> String {
        let value = Double(n)
        func short(_ v: Double) -> String { String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",").replacingOccurrences(of: ",0", with: "") }
        if value >= 1_000_000 { return short(value / 1_000_000) + " M" }
        if value >= 1_000 { return short(value / 1_000) + " K" }
        return String(n)
    }
}
