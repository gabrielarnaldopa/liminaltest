import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Talks to the Lithium server: the small Cloudflare Worker that holds the DeepSeek key.
/// The app never stores that key; it only knows the server's address and the app key you chose.
struct LithiumClient: Sendable {
    struct Request: Encodable, Equatable, Sendable {
        struct Rates: Encodable, Equatable, Sendable {
            var eur: Double
            var usd: Double
            var date: String
        }
        struct Line: Encodable, Equatable, Sendable {
            var role: String
            var content: String
        }
        /// Continues an answer after the person allowed (or refused) a search or a site.
        struct Resume: Encodable, Equatable, Sendable {
            var state: String
            var approved: Bool
        }
        var tier: String
        var effort: String
        var mode: String
        var lang: String
        var tone: String
        var name: String
        var custom: String
        var voice: Bool
        var memories: [String]
        var rates: Rates
        var messages: [Line]
        /// With a job id, the server keeps writing the answer even if the app closes.
        var jobId: String? = nil
        var browse: String? = nil
        var allowSearch: Bool? = nil
        var allowedHosts: [String]? = nil
        var resume: Resume? = nil
        /// Photos (light copies) for the engine that sees; deep research; the project this chat belongs to.
        struct Image: Encodable, Equatable, Sendable { var name: String; var data: String }
        struct Project: Encodable, Equatable, Sendable { var name: String; var instructions: String; var files: [String]; var shared = false; var author = "" }
        var images: [Image]? = nil
        var research: Bool? = nil
        var proyecto: Project? = nil
    }

    enum Event: Equatable, Sendable {
        case think(String)
        case text(String)
        case tool(ToolStep)
        case sources([SourceLink])
        case ask(AskRequest)
        case notice(String)
        /// Everything so far, when (re)connecting to an answer that runs on the server.
        case snapshot(JobSnapshot)
        /// What each photo shows, to keep with it.
        case vision([String])
        /// Tokens the answer used, for the usage meters.
        case usage(TokenUsage)
        case done
    }

    /// A message to show the person, already in Spanish.
    struct Failure: LocalizedError, Equatable {
        let message: String
        var status: Int = 0
        var errorDescription: String? { message }
    }

    struct DevicesReply: Decodable, Sendable {
        var token: String?
        var devices: [DeviceInfo]?
        var revoked: Bool?
        var message: String?
    }

    let base: URL
    let key: String

    /// Nil until the admin panel has a server address (https://…) and an app key.
    init?(address: String?, key: String?) {
        var text = (address ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("/") { text.removeLast() }
        let secret = (key ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !secret.isEmpty, let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http", let host = url.host, !host.isEmpty else { return nil }
        base = url
        self.key = secret
    }

    init?(admin: AdminConfig) {
        self.init(address: admin.serverURL, key: admin.serverKey)
    }

    /// The answer as it arrives: reasoning, browsing steps, text pieces, then done.
    func stream(_ body: Request) -> AsyncThrowingStream<Event, Error> {
        events(for: urlRequest(for: body))
    }

    /// Picks up an answer that kept running on the server: first a snapshot, then what is still coming.
    func jobStream(_ jobId: String) -> AsyncThrowingStream<Event, Error> {
        events(for: getRequest("jobs/\(jobId)/stream"))
    }

    /// Waits (up to about 8 minutes) until the answer finishes and returns it as JSON.
    /// Used by the background download that keeps working while the app is closed.
    func jobResultRequest(_ jobId: String) -> URLRequest {
        var request = getRequest("jobs/\(jobId)")
        request.url = URL(string: base.appendingPathComponent("jobs/\(jobId)").absoluteString + "?wait=1")
        request.timeoutInterval = 9 * 60
        return request
    }

    /// The whole answer at once, for the live conversation.
    func complete(_ body: Request) async throws -> String {
        var text = ""
        for try await event in stream(body) {
            if case .text(let piece) = event { text += piece }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func health() async -> ServerInfo? {
        var request = URLRequest(url: base.appendingPathComponent("health"))
        request.timeoutInterval = 15
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return Self.serverInfo(from: data)
    }

    /// Stops an answer on the server, so it stops using tokens.
    func cancel(jobId: String) async {
        var request = getRequest("jobs/\(jobId)/cancel")
        request.httpMethod = "POST"
        _ = try? await URLSession.shared.data(for: request)
    }

    /// register, list or revoke, for the account's device list.
    func devices(_ action: String, body: [String: String]) async throws -> DevicesReply {
        var request = URLRequest(url: base.appendingPathComponent("devices/\(action)"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-Liminal-Key")
        request.httpBody = try? JSONEncoder().encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let reply = (try? JSONDecoder().decode(DevicesReply.self, from: data)) ?? DevicesReply()
        if status != 200 && reply.revoked != true && reply.devices == nil {
            throw Failure(message: reply.message ?? "El servidor respondió con un error (\(status)).", status: status)
        }
        return reply
    }

    func urlRequest(for body: Request) -> URLRequest {
        var request = URLRequest(url: base.appendingPathComponent("chat"))
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "X-Liminal-Key")
        request.httpBody = try? JSONEncoder().encode(body)
        return request
    }

    private func getRequest(_ path: String) -> URLRequest {
        var request = URLRequest(url: base.appendingPathComponent(path))
        request.timeoutInterval = 300
        request.setValue(key, forHTTPHeaderField: "X-Liminal-Key")
        return request
    }

    private func events(for request: URLRequest) -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if status != 200 {
                        var data = Data()
                        for try await byte in bytes {
                            data.append(byte)
                            if data.count > 8_000 { break }
                        }
                        throw Self.failure(status: status, body: data)
                    }
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if let event = try Self.parse(line: line) {
                            if case .done = event, let usage = Self.usage(line: line) { continuation.yield(.usage(usage)) }
                            continuation.yield(event)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Reading the server's events

    private struct WireItem: Decodable {
        let id: String?
        let name: String?
        let query: String?
        let url: String?
        let host: String?
        let status: String?
        let title: String?
        let text: String?

        var step: ToolStep {
            ToolStep(id: id ?? UUID().uuidString, name: name ?? "", query: query ?? "", url: url ?? "",
                     host: host ?? "", status: status ?? "", title: title ?? "")
        }
        var link: SourceLink? {
            guard let url, !url.isEmpty else { return nil }
            return SourceLink(title: title ?? Browsing.host(of: url), url: url)
        }
    }

    private struct WireAsk: Decodable {
        let items: [WireItem]?
        let state: String?
    }

    private struct WireNotice: Decodable {
        let message: String?
    }

    private struct Wire: Decodable {
        let t: String
        let d: String?
        let message: String?
        // a browsing step
        let id: String?
        let name: String?
        let query: String?
        let url: String?
        let host: String?
        let status: String?
        let title: String?
        // sources and permission requests
        let items: [WireItem]?
        let state: String?
        // a snapshot of an answer on the server
        let text: String?
        let think: String?
        let tools: [WireItem]?
        let sources: [WireItem]?
        let ask: WireAsk?
        let notice: WireNotice?
        let error: String?
        let usage: WireUsage?
    }

    private struct WireUsage: Decodable {
        let input: Int?
        let cached: Int?
        let out: Int?
        let vin: Int?
        let vout: Int?
        enum CodingKeys: String, CodingKey { case input = "in", cached, out, vin, vout }
    }

    private struct ErrorBody: Decodable {
        let message: String?
    }

    /// The tokens reported on the stream's last line.
    static func usage(line: String) -> TokenUsage? {
        let payload = line.trimmingCharacters(in: .whitespaces).dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard let data = payload.data(using: .utf8), let wire = try? JSONDecoder().decode(Wire.self, from: data), let u = wire.usage else { return nil }
        return TokenUsage(input: u.input ?? 0, cached: u.cached ?? 0, output: u.out ?? 0, visionInput: u.vin ?? 0, visionOutput: u.vout ?? 0)
    }

    /// One line of the stream: `data: {"t":"text","d":"Hola"}`. Other lines are ignored.
    static func parse(line: String) throws -> Event? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("data:") else { return nil }
        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard let data = payload.data(using: .utf8), let wire = try? JSONDecoder().decode(Wire.self, from: data) else { return nil }
        switch wire.t {
        case "think": return .think(wire.d ?? "")
        case "text": return .text(wire.d ?? "")
        case "done": return .done
        case "vision": return .vision((wire.items ?? []).map { $0.text ?? "" })
        case "tool":
            return .tool(ToolStep(id: wire.id ?? UUID().uuidString, name: wire.name ?? "", query: wire.query ?? "",
                                  url: wire.url ?? "", host: wire.host ?? "", status: wire.status ?? "start", title: wire.title ?? ""))
        case "sources": return .sources((wire.items ?? []).compactMap(\.link))
        case "ask": return .ask(AskRequest(items: (wire.items ?? []).map(\.step), state: wire.state ?? ""))
        case "notice": return .notice(wire.message ?? "La respuesta se cortó.")
        case "snapshot":
            var ask: AskRequest?
            if let wireAsk = wire.ask, let state = wireAsk.state {
                ask = AskRequest(items: (wireAsk.items ?? []).map(\.step), state: state)
            }
            return .snapshot(JobSnapshot(status: wire.status ?? "running", text: wire.text ?? "", think: wire.think ?? "",
                                         tools: (wire.tools ?? []).map(\.step), sources: (wire.sources ?? []).compactMap(\.link),
                                         ask: ask, notice: wire.notice?.message, error: wire.error))
        case "error": throw Failure(message: wire.message ?? "El servidor tuvo un problema.")
        default: return nil
        }
    }

    /// The answer of `GET /jobs/<id>`: a snapshot without the "t" field.
    static func snapshot(from data: Data) -> JobSnapshot? {
        guard var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], object["status"] != nil else { return nil }
        object["t"] = "snapshot"
        guard let json = try? JSONSerialization.data(withJSONObject: object), let text = String(data: json, encoding: .utf8),
              case .snapshot(let snap)? = try? parse(line: "data: " + text) else { return nil }
        return snap
    }

    static func serverInfo(from data: Data) -> ServerInfo? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], object["ok"] as? Bool == true else { return nil }
        return ServerInfo(ready: object["ready"] as? Bool ?? false, search: object["search"] as? Bool ?? false,
                          background: object["background"] as? Bool ?? false, country: object["country"] as? String)
    }

    static func failure(status: Int, body: Data) -> Failure {
        if let message = (try? JSONDecoder().decode(ErrorBody.self, from: body))?.message, !message.isEmpty {
            return Failure(message: message, status: status)
        }
        switch status {
        case 401: return Failure(message: "La clave de la app no coincide con la del servidor.", status: status)
        case 404: return Failure(message: "Esa dirección no es un servidor de Lithium.", status: status)
        case 429: return Failure(message: "Demasiados mensajes seguidos. Espera un minuto.", status: status)
        default: return Failure(message: "El servidor respondió con un error (\(status)).", status: status)
        }
    }
}
