import Foundation
import Observation

/// All app data and actions. Saved as JSON in Application Support.
@MainActor
@Observable
final class AppStore {
    var state: AppState
    var route: Route? = .home
    var draft = ""
    var mode: ChatMode
    var isTemporary: Bool
    var isStreaming = false
    var attachments: [String] = []
    /// Short message shown at the bottom of the screen.
    var notice: String? = nil

    @ObservationIgnored private var streamTask: Task<Void, Never>? = nil
    @ObservationIgnored private var saveTask: Task<Void, Never>? = nil
    @ObservationIgnored private var streamingChatID: UUID? = nil
    @ObservationIgnored private let fileURL: URL

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("liminal-state.json")
        var loaded: AppState?
        if let data = try? Data(contentsOf: url) {
            loaded = try? JSONDecoder().decode(AppState.self, from: data)
        }
        var initial = loaded ?? Seed.state(name: AuthService.adminName, adminEmail: AuthService.adminEmail)
        // Finish any answer that was cut off when the app closed.
        for c in initial.chats.indices {
            for m in initial.chats[c].messages.indices
            where initial.chats[c].messages[m].isPending || initial.chats[c].messages[m].isStreaming {
                initial.chats[c].messages[m].isPending = false
                initial.chats[c].messages[m].isStreaming = false
                if initial.chats[c].messages[m].text.isEmpty {
                    initial.chats[c].messages[m].text = "La respuesta se interrumpió."
                }
            }
        }
        fileURL = url
        state = initial
        mode = initial.prefs.defaultMode
        isTemporary = initial.prefs.tempDefault
        checkUsage()
    }

    // MARK: - Saving

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard let self, !Task.isCancelled else { return }
            self.saveNow()
        }
    }

    func saveNow() {
        var copy = state
        copy.chats.removeAll { $0.isTemporary }
        guard let data = try? JSONEncoder().encode(copy) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func resetDemo() {
        stop()
        state = Seed.state(name: AuthService.adminName, adminEmail: AuthService.adminEmail)
        route = .home
        draft = ""
        mode = .general
        isTemporary = false
        saveNow()
        show("Demostración restablecida")
    }

    // MARK: - Reading

    var visibleChats: [Chat] {
        state.chats.filter { !$0.isTemporary }.sorted { $0.updated > $1.updated }
    }

    func chat(_ id: UUID) -> Chat? { state.chats.first { $0.id == id } }
    func project(_ id: UUID) -> Project? { state.projects.first { $0.id == id } }

    var advLeft: Int { max(0, state.usage.advCap - state.usage.adv) }
    var fastLeft: Int { max(0, state.usage.fastCap - state.usage.fast) }

    var enabledEngines: [Engine] {
        Engine.allCases.filter { state.admin.enabledEngines.contains($0) }
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Buenos días" }
        if hour < 19 { return "Buenas tardes" }
        return "Buenas noches"
    }

    nonisolated static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    func checkUsage() {
        let now = Date()
        if now > state.usage.resetAt {
            state.usage.adv = 0
            state.usage.resetAt = now.addingTimeInterval(5 * 3600)
        }
        if now > state.usage.weekResetAt {
            state.usage.week = 0
            state.usage.weekResetAt = now.addingTimeInterval(7 * 86400)
        }
        let today = Self.dayKey(now)
        if state.usage.fastDay != today {
            state.usage.fast = 0
            state.usage.fastDay = today
        }
    }

    func show(_ text: String) {
        notice = text
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            guard let self, self.notice == text else { return }
            self.notice = nil
        }
    }

    // MARK: - Navigation

    func newChat() {
        stop()
        draft = ""
        attachments = []
        mode = state.prefs.defaultMode
        isTemporary = state.prefs.tempDefault
        route = .home
        removeTemporaryChats()
    }

    /// Call when the screen changes: temporary chats disappear as soon as you leave them.
    func routeChanged() {
        var current: UUID?
        if case .chat(let id)? = route { current = id }
        if let streamingChatID, streamingChatID != current, chat(streamingChatID)?.isTemporary == true {
            stop()
        }
        removeTemporaryChats()
    }

    func toggleTemporary() {
        isTemporary.toggle()
        if case .chat(let id)? = route, let current = chat(id), current.isTemporary != isTemporary {
            route = .home
            routeChanged()
        }
        show(isTemporary ? "Chat temporal activado: no se guardará" : "Chat temporal desactivado")
    }

    private func removeTemporaryChats() {
        var keep: UUID?
        if case .chat(let id)? = route { keep = id }
        state.chats.removeAll { $0.isTemporary && $0.id != keep }
    }

    func pick(mode newMode: ChatMode) {
        mode = (mode == newMode) ? .general : newMode
        if mode != .general && draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            draft = mode.example
        }
    }

    // MARK: - Sending

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isStreaming, !(text.isEmpty && attachments.isEmpty) else { return }
        checkUsage()
        let prefs = state.prefs
        let cost = prefs.tier == .adv ? prefs.effort.cost : 0

        if prefs.tier == .adv && advLeft < cost {
            show(advLeft > 0
                 ? "El esfuerzo alto necesita 2 mensajes de tu ventana. Baja el esfuerzo o usa Rápido."
                 : "Llegaste al límite del modo avanzado. Usa el modo rápido.")
            return
        }
        if prefs.tier == .fast && fastLeft == 0 {
            show("Llegaste al uso diario del modo rápido. Se recarga a medianoche.")
            return
        }

        let chatID: UUID
        if case .chat(let id)? = route, chat(id) != nil {
            chatID = id
        } else {
            var projectID: UUID?
            if case .project(let id)? = route { projectID = id }
            let titleSource = text.isEmpty ? (attachments.first ?? "Archivo adjunto") : text
            let newChat = Chat(title: Replies.title(from: titleSource), mode: mode, projectID: projectID,
                               isTemporary: isTemporary || !prefs.saveHistory)
            state.chats.insert(newChat, at: 0)
            chatID = newChat.id
        }
        guard let index = state.chats.firstIndex(where: { $0.id == chatID }) else { return }

        let project = state.chats[index].projectID.flatMap { id in state.projects.first { $0.id == id } }
        let userText = text.isEmpty ? "Revisa el archivo adjunto." : text
        state.chats[index].messages.append(Message(role: .user, text: userText, files: attachments))

        var bot = Message(role: .bot, text: "", tier: prefs.tier, effort: prefs.effort, engine: prefs.engine, mode: mode)
        bot.isPending = true
        if prefs.tier == .adv {
            bot.thinkingSeconds = prefs.effort.seconds
            bot.thought = Replies.thought(for: userText, mode: mode, project: project,
                                          hasCustomInstructions: !prefs.custom.isEmpty)
        }
        let botID = bot.id
        state.chats[index].messages.append(bot)
        state.chats[index].updated = Date()

        if prefs.tier == .adv {
            state.usage.adv += cost
            state.usage.week += cost
        } else {
            state.usage.fast += 1
        }

        let full = Replies.reply(for: userText, mode: mode, project: project)
        let delay = prefs.tier == .adv ? prefs.effort.delayMilliseconds : 450
        draft = ""
        attachments = []
        isStreaming = true
        streamingChatID = chatID
        route = .chat(chatID)

        streamTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.updateMessage(chatID: chatID, messageID: botID) { message in
                message.isPending = false
                message.isStreaming = true
            }
            var position = full.startIndex
            while position < full.endIndex {
                if Task.isCancelled { return }
                position = full.index(position, offsetBy: Int.random(in: 3...7), limitedBy: full.endIndex) ?? full.endIndex
                let partial = String(full[..<position])
                self.updateMessage(chatID: chatID, messageID: botID) { message in message.text = partial }
                try? await Task.sleep(for: .milliseconds(22))
            }
            self.updateMessage(chatID: chatID, messageID: botID) { message in message.isStreaming = false }
            self.isStreaming = false
            self.streamingChatID = nil
            self.scheduleSave()
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        streamingChatID = nil
        guard isStreaming else { return }
        isStreaming = false
        for c in state.chats.indices {
            for m in state.chats[c].messages.indices
            where state.chats[c].messages[m].isPending || state.chats[c].messages[m].isStreaming {
                state.chats[c].messages[m].isPending = false
                state.chats[c].messages[m].isStreaming = false
                state.chats[c].messages[m].stopped = true
                if state.chats[c].messages[m].text.isEmpty {
                    state.chats[c].messages[m].text = "Respuesta detenida antes de empezar."
                }
            }
        }
        scheduleSave()
    }

    func regenerate(chatID: UUID) {
        guard !isStreaming, let index = state.chats.firstIndex(where: { $0.id == chatID }) else { return }
        if state.chats[index].messages.last?.role == .bot { state.chats[index].messages.removeLast() }
        guard let lastUser = state.chats[index].messages.popLast() else { return }
        draft = lastUser.text
        attachments = lastUser.files
        mode = state.chats[index].mode
        route = .chat(chatID)
        send()
    }

    func edit(chatID: UUID, messageID: UUID) {
        guard let c = state.chats.firstIndex(where: { $0.id == chatID }),
              let m = state.chats[c].messages.firstIndex(where: { $0.id == messageID }) else { return }
        draft = state.chats[c].messages[m].text
        state.chats[c].messages.removeSubrange(m...)
        show("Edita tu mensaje y vuelve a enviarlo")
    }

    func setFeedback(chatID: UUID, messageID: UUID, _ value: Feedback) {
        updateMessage(chatID: chatID, messageID: messageID) { message in
            message.feedback = (message.feedback == value) ? nil : value
        }
        if let message = chat(chatID)?.messages.first(where: { $0.id == messageID }), message.feedback != nil {
            show(value == .up ? "Gracias, nos ayuda a mejorar" : "Gracias. Puedes volver a generar la respuesta")
        }
    }

    private func updateMessage(chatID: UUID, messageID: UUID, _ change: (inout Message) -> Void) {
        guard let c = state.chats.firstIndex(where: { $0.id == chatID }),
              let m = state.chats[c].messages.firstIndex(where: { $0.id == messageID }) else { return }
        change(&state.chats[c].messages[m])
    }

    /// Your chats, projects, folders, memories and settings as readable JSON.
    func exportText() -> String {
        struct Export: Encodable {
            let prefs: Prefs
            let projects: [Project]
            let folders: [Folder]
            let chats: [Chat]
            let memories: [Memory]
        }
        let export = Export(prefs: state.prefs, projects: state.projects, folders: state.folders,
                            chats: state.chats.filter { !$0.isTemporary }, memories: state.memories)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(export) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - Chats

    func togglePin(_ id: UUID) {
        guard let i = state.chats.firstIndex(where: { $0.id == id }) else { return }
        state.chats[i].pinned.toggle()
        show(state.chats[i].pinned ? "Chat fijado" : "Chat quitado de fijados")
    }

    func renameChat(_ id: UUID, to title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let i = state.chats.firstIndex(where: { $0.id == id }) else { return }
        state.chats[i].title = clean
        show("Chat renombrado")
    }

    func move(chat id: UUID, projectID: UUID?, folderID: UUID?) {
        guard let i = state.chats.firstIndex(where: { $0.id == id }) else { return }
        state.chats[i].projectID = projectID
        state.chats[i].folderID = folderID
        show("Chat movido")
    }

    func deleteChat(_ id: UUID) {
        state.chats.removeAll { $0.id == id }
        if case .chat(let current)? = route, current == id { route = .home }
        show("Chat eliminado")
    }

    func deleteAllChats() {
        stop()
        state.chats.removeAll()
        route = .home
        show("Borraste todos tus chats")
    }

    // MARK: - Projects and folders

    @discardableResult
    func createProject(name: String, desc: String, colorHex: UInt32) -> UUID {
        let project = Project(name: name, desc: desc, colorHex: colorHex, instructions: "", files: [], created: Date())
        state.projects.append(project)
        route = .project(project.id)
        show("Proyecto creado")
        return project.id
    }

    func updateProject(_ id: UUID, name: String, desc: String, colorHex: UInt32) {
        guard let i = state.projects.firstIndex(where: { $0.id == id }) else { return }
        state.projects[i].name = name
        state.projects[i].desc = desc
        state.projects[i].colorHex = colorHex
        show("Proyecto actualizado")
    }

    func deleteProject(_ id: UUID) {
        for i in state.chats.indices where state.chats[i].projectID == id { state.chats[i].projectID = nil }
        state.projects.removeAll { $0.id == id }
        route = .home
        show("Proyecto eliminado")
    }

    func addFiles(_ urls: [URL], to projectID: UUID) {
        guard let i = state.projects.firstIndex(where: { $0.id == projectID }) else { return }
        for url in urls {
            let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            state.projects[i].files.append(ProjectFile(name: url.lastPathComponent, size: Self.sizeText(bytes)))
        }
        show(urls.count == 1 ? "Agregaste \(urls[0].lastPathComponent)" : "Agregaste \(urls.count) archivos")
    }

    func removeFile(projectID: UUID, fileID: UUID) {
        guard let i = state.projects.firstIndex(where: { $0.id == projectID }) else { return }
        state.projects[i].files.removeAll { $0.id == fileID }
    }

    func createFolder(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        state.folders.append(Folder(name: clean))
        show("Carpeta creada")
    }

    func renameFolder(_ id: UUID, to name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let i = state.folders.firstIndex(where: { $0.id == id }) else { return }
        state.folders[i].name = clean
        show("Carpeta renombrada")
    }

    func deleteFolder(_ id: UUID) {
        for i in state.chats.indices where state.chats[i].folderID == id { state.chats[i].folderID = nil }
        state.folders.removeAll { $0.id == id }
        show("Carpeta eliminada")
    }

    nonisolated static func sizeText(_ bytes: Int) -> String {
        if bytes >= 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576).replacingOccurrences(of: ".", with: ",")
        }
        return "\(max(1, bytes / 1024)) KB"
    }

    // MARK: - Admin

    func toggleSuspension(_ userID: UUID) {
        guard let i = state.users.firstIndex(where: { $0.id == userID }), !state.users[i].isAdmin else { return }
        if state.users[i].status == .suspendido {
            state.users[i].status = .activo
            show("\(state.users[i].name) puede volver a usar Liminal")
        } else {
            state.users[i].status = .suspendido
            show("Suspendiste a \(state.users[i].name)")
        }
    }

    func saveAdmin(_ config: AdminConfig) {
        state.admin = config
        state.usage.advCap = config.advCap
        state.usage.weekCap = config.weekCap
        state.usage.fastCap = config.fastCap
        if !config.enabledEngines.contains(state.prefs.engine), let first = enabledEngines.first {
            state.prefs.engine = first
        }
        show("Cambios guardados. Se aplican a todos los planes desde ahora.")
    }
}
