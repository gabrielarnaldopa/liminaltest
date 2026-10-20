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
    var attachments: [Attachment] = []
    /// Set while the composer creates an image or a video instead of a text answer.
    var creating: CreationKind? = nil
    /// The next message searches the web and shows sources.
    var searchWeb = false
    /// Deep research for the next message.
    var research = false
    /// Kuolki Dev (the web version, inside the app).
    var showDev = false
    /// Opens the connectors screen from the + menu.
    var showConnectors = false
    /// Shows the live conversation screen.
    var showVoice = false
    /// The side menu on iPhone (on iPad, a request to show or hide the sidebar column).
    var drawerOpen = false
    /// The settings sheet.
    var showSettings = false
    /// Short message shown at the bottom of the screen.
    var notice: String? = nil
    /// A slash command waiting in the composer: it adds its instruction to the next message.
    var command: SlashCommand? = nil
    /// The sent message being edited in place, and its text while you edit it.
    var editingMessage: UUID? = nil
    var editText = ""
    /// A page open in the built-in browser.
    var browser: BrowserTarget? = nil
    /// What the connected server can do: answers in the background, search, the country.
    var server: ServerInfo? = nil
    /// Devices where the account is signed in.
    var devices: [DeviceInfo]? = nil
    /// The signed-in account's email, set by the root view, for the device list.
    var accountEmail: String? = nil
    /// Another device signed this one out: the root view signs out.
    var signedOutRemotely = false
    /// How this device appears in the device list (set by the app with the real model name).
    static var deviceName = "iPhone · app de Kuolki"

    @ObservationIgnored private var streamTask: Task<Void, Never>? = nil
    @ObservationIgnored private var saveTask: Task<Void, Never>? = nil
    @ObservationIgnored private var streamingChatID: UUID? = nil
    /// The chat a live conversation writes to.
    @ObservationIgnored private var voiceChatID: UUID? = nil
    @ObservationIgnored private let live = LiveActivityController.shared
    @ObservationIgnored private let fileURL: URL
    /// Answers that run on the server and must be picked up when the app is back on screen.
    @ObservationIgnored private var resumeQueue: [(chatID: UUID, botID: UUID, tries: Int)] = []
    @ObservationIgnored private var isActive = true

    init() {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("liminal-state.json")
        var loaded: AppState?
        if let data = try? Data(contentsOf: url) {
            loaded = try? JSONDecoder().decode(AppState.self, from: data)
        }
        var initial = loaded ?? Seed.state(name: AuthService.adminName, adminEmail: AuthService.adminEmail)
        // Finish any answer that was cut off when the app closed. Answers that run on the server
        // keep going there, so they are picked up again instead (see appBecameActive).
        var queue: [(chatID: UUID, botID: UUID, tries: Int)] = []
        for c in initial.chats.indices {
            for m in initial.chats[c].messages.indices
            where initial.chats[c].messages[m].isPending || initial.chats[c].messages[m].isStreaming {
                if initial.chats[c].messages[m].jobID != nil && initial.chats[c].messages[m].kind == nil {
                    queue.append((initial.chats[c].id, initial.chats[c].messages[m].id, 0))
                    continue
                }
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
        live.isOn = initial.prefs.liveActivities ?? true
        live.removeLeftovers()
        resumeQueue = queue
        BackgroundJobs.shared.onFinished = { [weak self] jobID, snapshot in
            self?.applyFinishedJob(jobID, snapshot)
        }
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

    // Limits come from the token meters (see Extras.swift): one measure for the whole plan.
    var advLeft: Int { usageBlock(tier: .adv) == nil ? 99 : 0 }
    var fastLeft: Int { usageBlock(tier: .fast) == nil ? 99 : 0 }
    var creditsLeft: Int { max(0, state.usage.creditsCap - state.usage.credits) }

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
        if now > state.usage.creditsResetAt {
            state.usage.credits = 0
            state.usage.creditsResetAt = now.addingTimeInterval(30 * 86400)
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

    /// Opens the side menu, or on iPad shows or hides the sidebar.
    func openMenu() { drawerOpen = true }

    /// Closes the side menu before going somewhere else.
    func closeMenu() { drawerOpen = false }

    /// Opens settings from the side menu: the menu closes first so the sheet slides up over the chat.
    func openSettings() {
        drawerOpen = false
        showSettings = true
    }

    func newChat() {
        stop()
        draft = ""
        attachments = []
        creating = nil
        searchWeb = false
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
        var text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        // "/pagina una tienda" typed in one go, or a bare command like "/voz".
        if let parsed = SlashCommand.parse(text) {
            if parsed.rest.isEmpty {
                use(parsed.command)
                return
            }
            if parsed.command.prefix != nil {
                command = parsed.command
                text = parsed.rest
            }
        }
        guard !isStreaming, !(text.isEmpty && attachments.isEmpty) else { return }
        if attachments.contains(where: { $0.isReading }) {
            show("Espera a que termine de leer tus archivos.")
            return
        }
        checkUsage()
        if let creating {
            create(creating, from: text)
            return
        }
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
            let titleSource = text.isEmpty ? (attachments.first?.name ?? "Archivo adjunto") : text
            let newChat = Chat(title: Replies.title(from: titleSource), mode: mode, projectID: projectID,
                               isTemporary: isTemporary || !prefs.saveHistory)
            state.chats.insert(newChat, at: 0)
            chatID = newChat.id
        }
        guard let index = state.chats.firstIndex(where: { $0.id == chatID }) else { return }

        let project = state.chats[index].projectID.flatMap { id in state.projects.first { $0.id == id } }
        let userText = text.isEmpty ? "Revisa el archivo adjunto." : text
        let files = attachments
        let photos = files.filter { $0.kind == .image }.compactMap { file in VisionCache.get(file.id).map { LithiumClient.Request.Image(name: file.name, data: $0) } }
        let wantsResearch = research
        research = false
        let isTemporaryChat = state.chats[index].isTemporary
        var userMessage = Message(role: .user, text: userText, files: files)
        let usedCommand = command
        if let usedCommand, let prefix = usedCommand.prefix, !text.isEmpty {
            userMessage.prompt = prefix + text
            userMessage.command = usedCommand.key
        } else if searchWeb, !text.isEmpty {
            userMessage.prompt = "Busca en internet y respóndeme con fuentes: " + text
        }
        let wantsWeb = searchWeb || (usedCommand?.searchesWeb ?? false)
        let modelText = userMessage.prompt ?? userText
        state.chats[index].messages.append(userMessage)
        command = nil

        var bot = Message(role: .bot, text: "", tier: prefs.tier, effort: prefs.effort, engine: prefs.engine, mode: mode)
        bot.isPending = true
        if prefs.tier == .adv {
            bot.thinkingSeconds = prefs.effort.seconds
            bot.thought = Replies.thought(for: userText, mode: mode, project: project,
                                          hasCustomInstructions: !prefs.custom.isEmpty)
            if prefs.memory, !isTemporaryChat, let last = state.memories.last {
                bot.thought.insert("Tener en cuenta lo que recuerdo: \(last.text)", at: 1)
            }
        }
        bot.isReading = !files.isEmpty
        if searchWeb {
            bot.searchedWeb = true
            bot.sources = Replies.sources(for: text, mode: mode)
        }
        if !isTemporaryChat, !text.isEmpty, let memory = captureMemory(from: text) {
            bot.savedMemory = memory
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
        countDemoUsage(characters: text.count, tier: prefs.tier)

        var parts: [String] = []
        if bot.searchedWeb { parts.append("Busqué en internet y esto es lo más reciente:") }
        if state.connectors.contains(.drive), text.range(of: "drive", options: .caseInsensitive) != nil {
            parts.append("Busqué en tu **Google Drive** y encontré 2 documentos relacionados (demostración).")
        }
        if !files.isEmpty { parts.append(Replies.fileReply(files)) }
        if !text.isEmpty { parts.append(Replies.demoArtifact(for: modelText) ?? Replies.reply(for: userText, mode: mode, project: project)) }
        let full = parts.joined(separator: "\n\n")
        let delay = prefs.tier == .adv ? prefs.effort.delayMilliseconds : 450
        draft = ""
        attachments = []
        isStreaming = true
        streamingChatID = chatID
        route = .chat(chatID)

        // Long answers show in the Dynamic Island, so you can leave the app while Lithium thinks.
        let started = Date()
        let tracked = prefs.tier == .adv
        if tracked {
            let typing = Double(full.count) / 5 * 0.022
            live.start(.answer, chatID: chatID, state: .init(
                phase: .working, title: "Lithium está pensando", detail: userText.clipped(), startedAt: started,
                endsAt: started.addingTimeInterval(Double(delay) / 1000 + typing)))
        }
        live.beginBackgroundWork()

        if let client = LithiumClient(admin: state.admin) {
            // The answer runs on the server with this id, so it keeps going if the app closes.
            let jobID = Self.newJobID()
            updateMessage(chatID: chatID, messageID: botID) { message in
                message.searchedWeb = false
                message.sources = []
                message.thought = []
                message.thinkingSeconds = 0
                message.jobID = jobID
                message.jobBase = ""
            }
            var request = serverRequest(chatID: chatID, before: botID, voice: false)
            request.jobId = jobID
            if wantsWeb { request.allowSearch = true }
            if wantsResearch { request.research = true }
            if !photos.isEmpty {
                // photos go straight to the server (too big to keep as a background job)
                request.images = photos
                request.jobId = nil
                updateMessage(chatID: chatID, messageID: botID) { $0.jobID = nil }
            }
            files.forEach { VisionCache.set($0.id, nil) }
            saveNow()
            if server?.background == true && state.prefs.notify != false {
                Task { await Notifier.requestIfNeeded() }
            }
            streamTask = Task { [weak self] in
                await self?.runServerAnswer(client: client, events: client.stream(request), chatID: chatID, botID: botID,
                                            tracked: tracked, started: started, tries: 0)
            }
            return
        }

        streamTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            guard let self, !Task.isCancelled else { return }
            self.updateMessage(chatID: chatID, messageID: botID) { message in
                message.isPending = false
                message.isReading = false
                message.isStreaming = true
            }
            if tracked, self.live.kind == .answer, let state = self.live.current {
                var writing = state
                writing.title = "Escribiendo la respuesta"
                self.live.update(writing)
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
            if tracked, self.live.kind == .answer {
                self.live.finish(.init(phase: .done, title: "Respuesta lista", detail: Replies.preview(of: full),
                                       startedAt: started, endsAt: nil))
            }
            self.live.endBackgroundWork()
        }
    }

    /// Creates an image or a video and charges its credits.
    private func create(_ kind: CreationKind, from text: String) {
        guard !text.isEmpty else {
            show("Describe lo que quieres crear.")
            return
        }
        guard creditsLeft >= kind.credits else {
            show(creditsLeft > 0
                 ? "Te quedan \(creditsLeft) créditos y \(kind.name.lowercased()) usa \(kind.credits). Puedes sumar un paquete en Ajustes › Plan y pagos."
                 : "Usaste todos tus créditos del mes. Puedes sumar un paquete en Ajustes › Plan y pagos.")
            return
        }
        let chatID: UUID
        if case .chat(let id)? = route, chat(id) != nil {
            chatID = id
        } else {
            var projectID: UUID?
            if case .project(let id)? = route { projectID = id }
            let newChat = Chat(title: Replies.title(from: text), mode: mode, projectID: projectID,
                               isTemporary: isTemporary || !state.prefs.saveHistory)
            state.chats.insert(newChat, at: 0)
            chatID = newChat.id
        }
        guard let index = state.chats.firstIndex(where: { $0.id == chatID }) else { return }
        state.chats[index].messages.append(Message(role: .user, text: text))
        var bot = Message(role: .bot, text: "", tier: state.prefs.tier, effort: state.prefs.effort,
                          engine: state.prefs.engine, mode: mode)
        bot.kind = kind
        bot.prompt = text
        bot.seed = Self.seed(for: text + "\(Date().timeIntervalSince1970)")
        bot.isPending = true
        let botID = bot.id
        state.chats[index].messages.append(bot)
        state.chats[index].updated = Date()
        state.usage.credits += kind.credits

        draft = ""
        attachments = []
        isStreaming = true
        streamingChatID = chatID
        route = .chat(chatID)

        let started = Date()
        live.start(kind == .image ? .image : .video, chatID: chatID, state: .init(
            phase: .working, title: kind.activityTitle, detail: text.clipped(), startedAt: started,
            endsAt: started.addingTimeInterval(Double(kind.delayMilliseconds) / 1000)))
        live.beginBackgroundWork()

        streamTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(kind.delayMilliseconds))
            guard let self, !Task.isCancelled else { return }
            self.updateMessage(chatID: chatID, messageID: botID) { message in
                message.isPending = false
                message.text = kind.doneText
            }
            self.isStreaming = false
            self.streamingChatID = nil
            self.scheduleSave()
            self.live.finish(.init(phase: .done, title: kind.readyTitle, detail: text.clipped(), startedAt: started, endsAt: nil))
            self.live.endBackgroundWork()
        }
    }

    /// Same text, same picture: a small hash so each creation looks different.
    nonisolated static func seed(for text: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for byte in text.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return hash
    }

    func stop() {
        if let job = runningJobID, server?.background == true, let client = LithiumClient(admin: state.admin) {
            Task { await client.cancel(jobId: job) }
        }
        resumeQueue.removeAll()
        streamTask?.cancel()
        streamTask = nil
        streamingChatID = nil
        live.endBackgroundWork()
        guard isStreaming else { return }
        isStreaming = false
        if let kind = live.kind, kind != .voice {
            live.finish(.init(phase: .cancelled, title: kind == .answer ? "Respuesta detenida" : "Creación cancelada",
                              detail: kind == .answer ? "" : "No se usaron créditos.", startedAt: Date(), endsAt: nil),
                        keepFor: 0)
        }
        for c in state.chats.indices {
            for m in state.chats[c].messages.indices
            where state.chats[c].messages[m].isPending || state.chats[c].messages[m].isStreaming {
                state.chats[c].messages[m].isPending = false
                state.chats[c].messages[m].isStreaming = false
                state.chats[c].messages[m].stopped = true
                if let kind = state.chats[c].messages[m].kind {
                    // Nothing was created, so the credits go back.
                    state.usage.credits = max(0, state.usage.credits - kind.credits)
                    state.chats[c].messages[m].text = "Creación cancelada. No se usaron créditos."
                } else if state.chats[c].messages[m].text.isEmpty {
                    state.chats[c].messages[m].text = "Respuesta detenida antes de empezar."
                }
            }
        }
        scheduleSave()
    }

    func regenerate(chatID: UUID) {
        guard !isStreaming, let index = state.chats.firstIndex(where: { $0.id == chatID }) else { return }
        if let last = state.chats[index].messages.last, last.role == .bot {
            creating = last.kind
            state.chats[index].messages.removeLast()
        }
        guard let lastUser = state.chats[index].messages.popLast() else { return }
        draft = lastUser.text
        attachments = lastUser.files
        mode = state.chats[index].mode
        route = .chat(chatID)
        send()
    }

    /// Opens a message you sent so you can change it right there.
    func edit(chatID: UUID, messageID: UUID) {
        guard let message = chat(chatID)?.messages.first(where: { $0.id == messageID }) else { return }
        if isStreaming { stop() }
        editText = message.text
        editingMessage = messageID
    }

    func cancelEdit() {
        editingMessage = nil
        editText = ""
    }

    /// Sends the edited message. What followed the old one is kept as an earlier version.
    func resendEdit(chatID: UUID, messageID: UUID) {
        let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { show("Escribe tu mensaje antes de enviarlo."); return }
        if isStreaming { stop() }
        guard let c = state.chats.firstIndex(where: { $0.id == chatID }),
              let m = state.chats[c].messages.firstIndex(where: { $0.id == messageID }) else { return }
        let old = state.chats[c].messages[m]
        let after = Array(state.chats[c].messages[(m + 1)...])
        var versions = old.versions ?? []
        let current = MessageVersion(text: old.text, files: old.files, command: old.command, after: after)
        if versions.isEmpty { versions = [current] } else { versions[min(old.versionIndex ?? 0, versions.count - 1)] = current }
        let keep = (draft, attachments, searchWeb, research, creating, command)
        state.chats[c].messages.removeSubrange(m...)
        editingMessage = nil
        draft = text
        attachments = old.files
        searchWeb = old.prompt?.hasPrefix("Busca en internet") ?? false
        research = false
        creating = nil
        command = old.command.flatMap { SlashCommand.find($0) }
        route = .chat(chatID)
        send()
        if let c2 = state.chats.firstIndex(where: { $0.id == chatID }) {
            if m < state.chats[c2].messages.count, state.chats[c2].messages[m].role == .user {
                let sent = state.chats[c2].messages[m]
                versions.append(MessageVersion(text: sent.text, files: sent.files, command: sent.command, after: []))
                state.chats[c2].messages[m].versions = versions
                state.chats[c2].messages[m].versionIndex = versions.count - 1
            } else {
                // It could not be sent (for example, a usage limit): put the conversation back as it was.
                state.chats[c2].messages.append(old)
                state.chats[c2].messages.append(contentsOf: after)
            }
        }
        (draft, attachments, searchWeb, research, creating, command) = keep
    }

    /// Shows the previous or next version of an edited message, with the conversation that followed it.
    func showVersion(chatID: UUID, messageID: UUID, step: Int) {
        guard !isStreaming else { show("Espera a que termine la respuesta para cambiar de versión."); return }
        guard let c = state.chats.firstIndex(where: { $0.id == chatID }),
              let m = state.chats[c].messages.firstIndex(where: { $0.id == messageID }),
              var versions = state.chats[c].messages[m].versions else { return }
        let current = min(state.chats[c].messages[m].versionIndex ?? 0, versions.count - 1)
        let next = current + step
        guard versions.indices.contains(next) else { return }
        let message = state.chats[c].messages[m]
        versions[current] = MessageVersion(text: message.text, files: message.files, command: message.command,
                                           after: Array(state.chats[c].messages[(m + 1)...]))
        let shown = versions[next]
        state.chats[c].messages[m].text = shown.text
        state.chats[c].messages[m].files = shown.files
        state.chats[c].messages[m].command = shown.command
        state.chats[c].messages[m].versions = versions
        state.chats[c].messages[m].versionIndex = next
        state.chats[c].messages.removeSubrange((m + 1)...)
        state.chats[c].messages.append(contentsOf: shown.after)
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

    // MARK: - Live conversation

    var voiceSpeed: VoiceSpeed {
        get { state.prefs.voiceSpeed ?? .normal }
        set { state.prefs.voiceSpeed = newValue }
    }

    var liveActivitiesOn: Bool {
        get { state.prefs.liveActivities ?? true }
        set {
            state.prefs.liveActivities = newValue
            live.isOn = newValue
            if !newValue { live.endNow() }
        }
    }

    /// Opens the live conversation. Inside a chat, it continues that chat.
    func startVoice() {
        guard !isStreaming else {
            show("Espera a que Lithium termine de responder.")
            return
        }
        voiceChatID = nil
        if case .chat(let id)? = route, let current = chat(id) {
            voiceChatID = current.id
            mode = current.mode
        }
        showVoice = true
    }

    /// What a live-conversation turn needs between saving what you said and saving the answer.
    struct VoiceTurn {
        var chatID: UUID
        var answer: VoiceAnswer
        var memory: Memory?
        var mode: ChatMode
    }

    /// One turn of a live conversation: saves what you said and Lithium's answer, and returns what to say.
    /// The rate, the time, the date and memory are answered on the phone; the rest goes to the server when it is set.
    func voiceTurn(_ said: String) async -> VoiceAnswer {
        guard var turn = beginVoiceTurn(said) else { return voiceRefusal(said) }
        if turn.answer.generic, let client = LithiumClient(admin: state.admin) {
            let request = serverRequest(chatID: turn.chatID, before: nil, voice: true)
            do {
                let reply = try await client.complete(request)
                turn.answer = VoiceAnswer(text: reply.isEmpty ? "No te entendí bien. ¿Me lo repites?" : Replies.speakable(reply))
            } catch {
                turn.answer = VoiceAnswer(text: "No pude conectarme con el servidor de Lithium. Intenta de nuevo en un momento.")
            }
        }
        return finishVoiceTurn(turn)
    }

    /// Why a turn could not start: nothing heard, or a limit reached.
    private func voiceRefusal(_ said: String) -> VoiceAnswer {
        if said.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return VoiceAnswer(text: "No te escuché bien. ¿Me lo repites?")
        }
        if state.prefs.tier == .adv {
            return VoiceAnswer(text: "Llegaste al límite del modo avanzado por ahora. Cambia al modo rápido y seguimos hablando.", ends: true)
        }
        return VoiceAnswer(text: "Llegaste al uso de hoy del modo rápido. Se recarga a medianoche.", ends: true)
    }

    /// Checks the limits, saves what you said and counts the message. Nil when the turn cannot happen.
    private func beginVoiceTurn(_ said: String) -> VoiceTurn? {
        let text = said.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        checkUsage()
        let prefs = state.prefs
        let cost = prefs.tier == .adv ? prefs.effort.cost : 0
        if prefs.tier == .adv && advLeft < cost { return nil }
        if prefs.tier == .fast && fastLeft == 0 { return nil }

        let chatID: UUID
        if let id = voiceChatID, chat(id) != nil {
            chatID = id
        } else {
            var projectID: UUID?
            if case .project(let id)? = route { projectID = id }
            let newChat = Chat(title: Replies.title(from: text), mode: mode, projectID: projectID,
                               isTemporary: isTemporary || !prefs.saveHistory)
            state.chats.insert(newChat, at: 0)
            chatID = newChat.id
            voiceChatID = chatID
        }
        guard let index = state.chats.firstIndex(where: { $0.id == chatID }) else { return nil }
        var userMessage = Message(role: .user, text: text, mode: mode)
        userMessage.spoken = true
        state.chats[index].messages.append(userMessage)
        let memory = state.chats[index].isTemporary ? nil : captureMemory(from: text)
        if prefs.tier == .adv {
            state.usage.adv += cost
            state.usage.week += cost
        } else {
            state.usage.fast += 1
        }
        let answer = Replies.spoken(for: text, mode: mode, memory: memory, pay: state.pay, name: prefs.name)
        return VoiceTurn(chatID: chatID, answer: answer, memory: memory, mode: mode)
    }

    /// Saves Lithium's answer in the conversation's chat.
    private func finishVoiceTurn(_ turn: VoiceTurn) -> VoiceAnswer {
        guard let index = state.chats.firstIndex(where: { $0.id == turn.chatID }) else { return turn.answer }
        let prefs = state.prefs
        var bot = Message(role: .bot, text: turn.answer.text, tier: prefs.tier, effort: prefs.effort, engine: prefs.engine, mode: turn.mode)
        bot.spoken = true
        bot.savedMemory = turn.memory
        state.chats[index].messages.append(bot)
        state.chats[index].updated = Date()
        scheduleSave()
        return turn.answer
    }

    // MARK: - Lithium server

    /// True when the admin panel has the server's address and app key: answers are real.
    var serverReady: Bool { LithiumClient(admin: state.admin) != nil }

    /// The conversation as the server needs it, with Lithium's settings for this person.
    func serverRequest(chatID: UUID, before messageID: UUID?, voice: Bool) -> LithiumClient.Request {
        let prefs = state.prefs
        let current = chat(chatID)
        var lines: [LithiumClient.Request.Line] = []
        for message in current?.messages ?? [] {
            if let messageID, message.id == messageID { break }
            if message.kind != nil || message.isPending { continue }
            var content = message.role == .user ? (message.prompt ?? message.text) : message.text
            if message.role == .user { content += Replies.filesForModel(message.files) }
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
            lines.append(.init(role: message.role == .user ? "user" : "assistant", content: String(content.prefix(24_000))))
        }
        let year = Calendar.current.component(.year, from: state.pay.rateDate)
        let usesMemory = prefs.memory && current?.isTemporary != true
        return LithiumClient.Request(
            tier: prefs.tier.rawValue, effort: prefs.effort.rawValue, mode: (current?.mode ?? mode).rawValue,
            lang: prefs.language, tone: prefs.tone.rawValue, name: prefs.name, custom: prefs.custom, voice: voice,
            memories: usesMemory ? state.memories.suffix(30).map(\.text) : [],
            rates: .init(eur: state.pay.rateEur, usd: state.pay.rateUsd, date: "\(Replies.dayMonth(state.pay.rateDate)) de \(year)"),
            messages: Array(lines.suffix(24)),
            browse: voice ? BrowseMode.off.rawValue : (prefs.browse ?? .ask).rawValue,
            allowSearch: prefs.allowSearch ?? false,
            allowedHosts: prefs.allowedHosts ?? [])
    }

    /// Checks the address and key typed in the admin panel with a one-word question.
    func testServer(address: String, key: String) async -> String {
        guard let client = LithiumClient(address: address, key: key) else {
            return "Escribe la dirección completa del servidor (https://…) y la clave de la app."
        }
        let probe = LithiumClient.Request(
            tier: "fast", effort: "medio", mode: "general", lang: state.prefs.language, tone: "directo", name: "", custom: "",
            voice: false, memories: [], rates: .init(eur: state.pay.rateEur, usd: state.pay.rateUsd, date: ""),
            messages: [.init(role: "user", content: "Responde solo con la palabra: listo")])
        do {
            let reply = try await client.complete(probe)
            server = await client.health()
            return reply.isEmpty ? "El servidor respondió vacío." : "Conexión lista. \(Brand.modelName) respondió: «\(reply.prefix(40))». Guarda los cambios."
        } catch let failure as LithiumClient.Failure {
            return failure.message
        } catch {
            return "No pude llegar al servidor. Revisa la dirección y tu conexión."
        }
    }

    /// What an answer from the server has written so far.
    private final class AnswerProgress {
        let base: String
        var text: String
        var reasoning = ""
        var writing: Bool
        var lastPaint = Date.distantPast
        var lastSave = Date()
        var failure: String?

        init(base: String, writing: Bool) {
            self.base = base
            text = base
            self.writing = writing
        }
    }

    nonisolated static func newJobID() -> String {
        "i" + UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }

    private func message(_ chatID: UUID, _ messageID: UUID) -> Message? {
        chat(chatID)?.messages.first { $0.id == messageID }
    }

    /// The job id of the answer being written right now, if it runs on the server.
    private var runningJobID: String? {
        for chat in state.chats {
            for message in chat.messages where (message.isPending || message.isStreaming) && message.jobID != nil {
                return message.jobID
            }
        }
        return nil
    }

    /// A real answer from the server, shown as it arrives. Also picks up an answer that kept running on the server.
    private func runServerAnswer(client: LithiumClient, events: AsyncThrowingStream<LithiumClient.Event, Error>,
                                 chatID: UUID, botID: UUID, tracked: Bool, started: Date, tries: Int) async {
        let current = message(chatID, botID)
        let progress = AnswerProgress(base: current?.jobBase ?? "", writing: current?.isPending == false)
        do {
            for try await event in events {
                if Task.isCancelled { return }
                apply(event, progress: progress, chatID: chatID, botID: botID, tracked: tracked, started: started)
            }
            if Task.isCancelled { return }
            finishServerAnswer(progress, chatID: chatID, botID: botID, tracked: tracked, started: started)
        } catch {
            if Task.isCancelled { return }
            if scheduleResume(after: error, chatID: chatID, botID: botID, tries: tries) { return }
            failServerAnswer(error, progress: progress, chatID: chatID, botID: botID)
        }
    }

    private func apply(_ event: LithiumClient.Event, progress: AnswerProgress, chatID: UUID, botID: UUID,
                       tracked: Bool, started: Date) {
        let advanced = message(chatID, botID)?.tier == .adv
        switch event {
        case .think(let piece):
            progress.reasoning += piece
            if advanced, Date().timeIntervalSince(progress.lastPaint) > 0.15 {
                progress.lastPaint = Date()
                let lines = Replies.thoughtLines(progress.reasoning)
                updateMessage(chatID: chatID, messageID: botID) { message in message.thought = lines }
            }
        case .text(let piece):
            beginWriting(progress, chatID: chatID, botID: botID, advanced: advanced, tracked: tracked, started: started)
            progress.text += piece
            if Date().timeIntervalSince(progress.lastPaint) > 0.05 {
                progress.lastPaint = Date()
                let partial = progress.text
                updateMessage(chatID: chatID, messageID: botID) { message in message.text = partial }
            }
        case .tool(let step):
            updateMessage(chatID: chatID, messageID: botID) { message in
                message.tools = Self.merged(message.tools ?? [], [step])
            }
            if tracked, step.isBusy, live.kind == .answer, var state = live.current {
                state.title = step.isSearch ? "Buscando en internet" : "Leyendo \(step.siteHost)"
                live.update(state)
            }
        case .sources(let links):
            updateMessage(chatID: chatID, messageID: botID) { message in
                message.links = Self.merged(message.links ?? [], links)
            }
        case .ask(let ask):
            updateMessage(chatID: chatID, messageID: botID) { message in message.ask = ask }
        case .notice(let text):
            updateMessage(chatID: chatID, messageID: botID) { message in message.notice = text }
        case .snapshot(let snapshot):
            if let error = snapshot.error { progress.failure = error }
            if !snapshot.think.isEmpty { progress.reasoning = snapshot.think }
            if !snapshot.text.isEmpty {
                beginWriting(progress, chatID: chatID, botID: botID, advanced: advanced, tracked: tracked, started: started)
                progress.text = progress.base + snapshot.text
            }
            let text = progress.text
            let lines = advanced ? Replies.thoughtLines(progress.reasoning) : []
            updateMessage(chatID: chatID, messageID: botID) { message in
                if !snapshot.text.isEmpty { message.text = text }
                if !lines.isEmpty { message.thought = lines }
                if !snapshot.tools.isEmpty { message.tools = Self.merged(message.tools ?? [], snapshot.tools) }
                if !snapshot.sources.isEmpty { message.links = Self.merged(message.links ?? [], snapshot.sources) }
                if let ask = snapshot.ask { message.ask = ask }
                if let notice = snapshot.notice { message.notice = notice }
            }
        case .vision(let texts):
            if let ci = state.chats.firstIndex(where: { $0.id == chatID }),
               let bi = state.chats[ci].messages.firstIndex(where: { $0.id == botID }), bi > 0 {
                var k = 0
                for f in state.chats[ci].messages[bi - 1].files.indices where state.chats[ci].messages[bi - 1].files[f].kind == .image {
                    if k < texts.count { state.chats[ci].messages[bi - 1].files[f].text = String(texts[k].prefix(8000)) }
                    k += 1
                }
            }
        case .usage(let used):
            addUsage(used, tier: message(chatID, botID)?.tier ?? .fast)
        case .done:
            break
        }
        if Date().timeIntervalSince(progress.lastSave) > 3 {
            progress.lastSave = Date()
            scheduleSave()
        }
    }

    private func beginWriting(_ progress: AnswerProgress, chatID: UUID, botID: UUID, advanced: Bool, tracked: Bool, started: Date) {
        guard !progress.writing else { return }
        progress.writing = true
        let seconds = advanced && !progress.reasoning.isEmpty ? max(1, Int(Date().timeIntervalSince(started).rounded())) : 0
        let lines = advanced ? Replies.thoughtLines(progress.reasoning) : []
        updateMessage(chatID: chatID, messageID: botID) { message in
            message.isPending = false
            message.isReading = false
            message.isStreaming = true
            if seconds > 0 { message.thinkingSeconds = seconds }
            if !lines.isEmpty { message.thought = lines }
        }
        if tracked, live.kind == .answer, var state = live.current {
            state.title = "Escribiendo la respuesta"
            live.update(state)
        }
    }

    private func finishServerAnswer(_ progress: AnswerProgress, chatID: UUID, botID: UUID, tracked: Bool, started: Date) {
        let ask = message(chatID, botID)?.ask
        var final = progress.text
        var stopped = false
        if let failure = progress.failure {
            final = (final.isEmpty ? "" : final + "\n\n") + "**No se pudo completar la respuesta.** " + failure
            stopped = ask == nil
        } else if final.isEmpty && ask == nil {
            final = "No llegó respuesta. Intenta de nuevo."
        }
        let text = final
        updateMessage(chatID: chatID, messageID: botID) { message in
            message.text = text
            message.isPending = false
            message.isReading = false
            message.isStreaming = false
            if stopped { message.stopped = true }
        }
        if tracked, live.kind == .answer {
            live.finish(.init(phase: .done, title: ask == nil ? "Respuesta lista" : "\(Brand.modelName) necesita tu permiso",
                              detail: ask?.summary ?? Replies.preview(of: text), startedAt: started, endsAt: nil))
        }
        endStreaming()
        notifyIfAway(chatID: chatID, botID: botID)
    }

    private func failServerAnswer(_ error: Error, progress: AnswerProgress, chatID: UUID, botID: UUID) {
        let reason = (error as? LithiumClient.Failure)?.message ?? "Revisa tu conexión a internet o la dirección del servidor."
        let partial = progress.text
        updateMessage(chatID: chatID, messageID: botID) { message in
            message.text = (partial.isEmpty ? "" : partial + "\n\n") + "**No se pudo completar la respuesta.** " + reason
            message.isPending = false
            message.isReading = false
            message.isStreaming = false
            message.stopped = true
        }
        if live.kind == .answer { live.endNow() }
        endStreaming()
    }

    private func endStreaming() {
        isStreaming = false
        streamingChatID = nil
        streamTask = nil
        scheduleSave()
        live.endBackgroundWork()
    }

    /// The connection dropped (the app went to the background, the network blinked), but the server
    /// kept writing: pick the answer up again now, or as soon as the app is back on screen.
    private func scheduleResume(after error: Error, chatID: UUID, botID: UUID, tries: Int) -> Bool {
        guard server?.background == true, tries < 4, message(chatID, botID)?.jobID != nil else { return false }
        if error is LithiumClient.Failure { return false }
        if isActive {
            streamTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(tries == 0 ? 400 : 1500))
                guard let self, !Task.isCancelled else { return }
                self.resume(chatID: chatID, botID: botID, tries: tries + 1)
            }
        } else {
            resumeQueue.append((chatID, botID, tries + 1))
        }
        return true
    }

    private func resume(chatID: UUID, botID: UUID, tries: Int) {
        guard let client = LithiumClient(admin: state.admin), let job = message(chatID, botID)?.jobID else {
            interrupt(chatID: chatID, botID: botID)
            return
        }
        isStreaming = true
        streamingChatID = chatID
        streamTask = Task { [weak self] in
            await self?.runServerAnswer(client: client, events: client.jobStream(job), chatID: chatID, botID: botID,
                                        tracked: false, started: Date(), tries: tries)
        }
    }

    private func interrupt(chatID: UUID, botID: UUID) {
        updateMessage(chatID: chatID, messageID: botID) { message in
            message.isPending = false
            message.isStreaming = false
            if message.text.isEmpty { message.text = "La respuesta se interrumpió." }
        }
        if streamingChatID == chatID { endStreaming() }
    }

    nonisolated static func merged(_ old: [ToolStep], _ new: [ToolStep]) -> [ToolStep] {
        var steps = old
        for step in new {
            if let i = steps.firstIndex(where: { $0.id == step.id }) {
                steps[i].merge(step)
            } else {
                steps.append(step)
            }
        }
        return steps
    }

    nonisolated static func merged(_ old: [SourceLink], _ new: [SourceLink]) -> [SourceLink] {
        var links = old
        for link in new where !links.contains(where: { $0.url == link.url }) {
            links.append(link)
        }
        return Array(links.prefix(12))
    }

    // MARK: - The app comes and goes

    /// The app is on screen again: pick up answers that kept running on the server and refresh the device list.
    func appBecameActive() {
        isActive = true
        Task { [weak self] in
            guard let self else { return }
            await self.refreshServer()
            self.resumeWaitingAnswers()
            await self.registerDevice()
        }
    }

    /// The app leaves the screen: while it is closed, a background download waits for running answers.
    func appWentToBackground() {
        isActive = false
        saveNow()
        guard server?.background == true, let client = LithiumClient(admin: state.admin) else { return }
        for chat in state.chats {
            for message in chat.messages where message.isPending || message.isStreaming {
                if let job = message.jobID {
                    BackgroundJobs.shared.watch(client.jobResultRequest(job), jobID: job)
                }
            }
        }
    }

    func refreshServer() async {
        guard let client = LithiumClient(admin: state.admin) else {
            server = nil
            return
        }
        if let info = await client.health() { server = info }
    }

    private func resumeWaitingAnswers() {
        let queue = resumeQueue
        resumeQueue = []
        for (offset, item) in queue.enumerated() {
            guard let current = message(item.chatID, item.botID), current.isPending || current.isStreaming else {
                if streamingChatID == item.chatID && streamTask == nil { endStreaming() }
                continue
            }
            if server?.background == true && offset == queue.count - 1 && (streamTask == nil || streamingChatID == item.chatID) {
                resume(chatID: item.chatID, botID: item.botID, tries: item.tries)
            } else {
                interrupt(chatID: item.chatID, botID: item.botID)
            }
        }
    }

    /// An answer finished on the server while the app was closed (from the background download).
    func applyFinishedJob(_ jobID: String, _ snapshot: JobSnapshot) {
        guard !snapshot.isRunning,
              let c = state.chats.firstIndex(where: { $0.messages.contains { $0.jobID == jobID } }),
              let m = state.chats[c].messages.firstIndex(where: { $0.jobID == jobID }) else { return }
        let current = state.chats[c].messages[m]
        guard current.isPending || current.isStreaming else { return }
        let chatID = state.chats[c].id
        let botID = current.id
        // When the app is on screen, the live stream takes care of it.
        if isActive && streamingChatID == chatID && streamTask != nil { return }
        resumeQueue.removeAll { $0.botID == botID }
        let base = current.jobBase ?? ""
        updateMessage(chatID: chatID, messageID: botID) { message in
            message.text = base + snapshot.text
            if !snapshot.tools.isEmpty { message.tools = Self.merged(message.tools ?? [], snapshot.tools) }
            if !snapshot.sources.isEmpty { message.links = Self.merged(message.links ?? [], snapshot.sources) }
            message.ask = snapshot.ask
            message.notice = snapshot.notice
            if let error = snapshot.error {
                message.text += (message.text.isEmpty ? "" : "\n\n") + "**No se pudo completar la respuesta.** " + error
                message.stopped = snapshot.ask == nil
            } else if message.text.isEmpty && snapshot.ask == nil {
                message.text = "No llegó respuesta. Intenta de nuevo."
            }
            message.isPending = false
            message.isReading = false
            message.isStreaming = false
        }
        if streamingChatID == chatID {
            streamTask?.cancel()
            endStreaming()
        }
        notifyIfAway(chatID: chatID, botID: botID)
        saveNow()
    }

    private func notifyIfAway(chatID: UUID, botID: UUID) {
        guard !isActive, state.prefs.notify != false, let message = message(chatID, botID) else { return }
        let title = message.ask != nil ? "\(Brand.modelName) necesita tu permiso" : "\(Brand.modelName) terminó tu respuesta"
        let body = message.ask?.summary ?? Replies.preview(of: message.text)
        let id = message.jobID ?? botID.uuidString
        Task { await Notifier.post(title: title, body: body, id: id) }
    }

    // MARK: - Browsing permission

    /// The person answered «¿Puedo entrar a este sitio?»: continue the answer on the server.
    func answerAsk(chatID: UUID, messageID: UUID, approved: Bool, always: Bool) {
        if isStreaming {
            show("Espera a que termine la respuesta que está en curso.")
            return
        }
        guard let current = message(chatID, messageID), let ask = current.ask,
              let client = LithiumClient(admin: state.admin) else { return }
        if approved && always {
            var hosts = state.prefs.allowedHosts ?? []
            for host in ask.hosts where !hosts.contains(host) { hosts.append(host) }
            state.prefs.allowedHosts = hosts
            if ask.wantsSearch { state.prefs.allowSearch = true }
            show(ask.hosts.isEmpty ? "Listo: Lithium buscará sin preguntarte." : "Listo: Lithium entrará a ese sitio sin preguntarte.")
        }
        let jobID = Self.newJobID()
        let base = current.text
        updateMessage(chatID: chatID, messageID: messageID) { message in
            message.ask = nil
            message.stopped = false
            message.isStreaming = true
            message.jobID = jobID
            message.jobBase = base
        }
        var request = serverRequest(chatID: chatID, before: messageID, voice: false)
        request.tier = current.tier.rawValue
        request.effort = current.effort.rawValue
        request.jobId = jobID
        request.resume = .init(state: ask.state, approved: approved)
        isStreaming = true
        streamingChatID = chatID
        live.beginBackgroundWork()
        saveNow()
        streamTask = Task { [weak self] in
            await self?.runServerAnswer(client: client, events: client.stream(request), chatID: chatID, botID: messageID,
                                        tracked: false, started: Date(), tries: 0)
        }
    }

    /// «Navegar siempre sin preguntar».
    func browseWithoutAsking(chatID: UUID, messageID: UUID) {
        state.prefs.browse = .auto
        show("Lithium navegará sin preguntarte. Puedes cambiarlo en Ajustes › Navegación.")
        answerAsk(chatID: chatID, messageID: messageID, approved: true, always: false)
    }

    // MARK: - Slash commands

    /// Runs or prepares a command picked in the composer.
    func use(_ picked: SlashCommand) {
        draft = ""
        switch picked.action {
        case .prefix:
            command = picked
            creating = nil
        case .create(let kind):
            creating = kind
            command = nil
        case .mode(let newMode):
            mode = newMode
            show("Modo \(newMode.name)")
        case .run(let run):
            switch run {
            case .voice: startVoice()
            case .browser: browser = BrowserTarget(url: nil)
            case .fast:
                state.prefs.tier = .fast
                show("Modo rápido")
            case .advanced:
                state.prefs.tier = .adv
                show("Modo avanzado")
            case .temporary: toggleTemporary()
            case .research:
                research = true
                searchWeb = false
                show("Investigación a fondo: Lithium buscará en muchas fuentes y te dará un informe con citas.")
            case .dev: showDev = true
            case .newChat: newChat()
            }
        }
    }

    // MARK: - Devices

    /// The country used to show payment methods.
    var paymentRegion: String {
        state.prefs.region ?? Region.detect(timeZone: TimeZone.current.identifier, serverCountry: server?.country,
                                            phoneRegion: Region.code(fromLocale: Locale.current.identifier))
    }

    /// Registers this device in the account's list, and learns if another device signed it out.
    func registerDevice() async {
        guard let email = accountEmail, server?.background == true, let client = LithiumClient(admin: state.admin) else { return }
        var record = Keychain.loadDevice()
        if record == nil || record?.email != email {
            let fresh = DeviceRecord(id: Self.newJobID(), email: email, token: nil)
            Keychain.saveDevice(fresh)
            record = fresh
        }
        guard var current = record else { return }
        let body = ["email": email, "deviceId": current.id, "token": current.token ?? "", "name": Self.deviceName, "platform": "iOS"]
        guard let reply = try? await client.devices("register", body: body) else { return }
        if reply.revoked == true {
            Keychain.deleteDevice()
            devices = nil
            signedOutRemotely = true
            return
        }
        if let token = reply.token {
            current.token = token
            Keychain.saveDevice(current)
        }
        if let list = reply.devices { devices = list }
    }

    /// Signs out another device (or all the others with "others"). Returns a message when it fails.
    func revokeDevice(_ target: String) async -> String? {
        guard let email = accountEmail, let client = LithiumClient(admin: state.admin), let record = Keychain.loadDevice() else {
            return "Conecta el servidor para ver tus dispositivos."
        }
        do {
            let reply = try await client.devices("revoke", body: ["email": email, "deviceId": record.id, "token": record.token ?? "", "target": target])
            if let list = reply.devices { devices = list }
            return nil
        } catch {
            return (error as? LithiumClient.Failure)?.message ?? "No se pudo. Revisa tu conexión."
        }
    }

    /// Signing out here also closes this device in the account's list.
    func forgetDevice() async {
        if let record = Keychain.loadDevice(), record.token != nil, let email = accountEmail,
           let client = LithiumClient(admin: state.admin) {
            _ = try? await client.devices("revoke", body: ["email": email, "deviceId": record.id, "token": record.token ?? "", "target": record.id])
        }
        Keychain.deleteDevice()
        devices = nil
    }

    /// Closes the live conversation and shows its transcript.
    func endVoice() {
        showVoice = false
        if let id = voiceChatID, chat(id) != nil {
            route = .chat(id)
        }
        voiceChatID = nil
        scheduleSave()
    }

    /// Links from the Dynamic Island: liminal://chat/<id> and liminal://voice.
    func open(_ url: URL) {
        guard url.scheme == "liminal" else { return }
        if url.host == "chat", let id = UUID(uuidString: url.lastPathComponent), chat(id) != nil {
            if !showVoice { route = .chat(id) }
        }
    }

    // MARK: - Files

    /// Adds files picked in the Files app and reads them in the background.
    func addFiles(_ urls: [URL]) {
        let room = max(0, 10 - attachments.count)
        if urls.count > room { show("Puedes adjuntar hasta 10 archivos por mensaje.") }
        for url in urls.prefix(room) {
            let attachment = Attachment(name: url.lastPathComponent, size: 0, kind: FileReader.kind(of: url), isReading: true)
            attachments.append(attachment)
            Task { [weak self] in
                let result = await Task.detached { await FileReader.read(url: url, into: attachment) }.value
                guard let self, let i = self.attachments.firstIndex(where: { $0.id == attachment.id }) else { return }
                self.attachments[i] = result
            }
        }
    }

    func addAttachment(_ attachment: Attachment) {
        guard attachments.count < 10 else {
            show("Puedes adjuntar hasta 10 archivos por mensaje.")
            return
        }
        attachments.append(attachment)
    }

    func removeAttachment(_ id: UUID) {
        attachments.removeAll { $0.id == id }
    }

    // MARK: - Memory

    /// Saves facts like "me llamo…", "mi tienda…" or "recuerda que…".
    private func captureMemory(from text: String) -> Memory? {
        guard state.prefs.memory, let found = Replies.memoryFact(in: text) else { return nil }
        guard !state.memories.contains(where: { $0.text.lowercased() == found.text.lowercased() }) else { return nil }
        state.memories.append(found)
        return found
    }

    func undoMemory(chatID: UUID, messageID: UUID) {
        guard let memory = chat(chatID)?.messages.first(where: { $0.id == messageID })?.savedMemory else { return }
        state.memories.removeAll { $0.id == memory.id }
        updateMessage(chatID: chatID, messageID: messageID) { message in message.savedMemory = nil }
        show("Lithium no recordará ese dato")
    }

    func addMemory(_ text: String, category: MemoryCategory) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        state.memories.append(Memory(text: clean.prefix(1).uppercased() + clean.dropFirst(), category: category))
        show("Lithium lo recordará")
    }

    func updateMemory(_ id: UUID, text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let i = state.memories.firstIndex(where: { $0.id == id }) else { return }
        state.memories[i].text = clean
        show("Recuerdo actualizado")
    }

    func deleteMemory(_ id: UUID) {
        state.memories.removeAll { $0.id == id }
    }

    func forgetAll() {
        state.memories.removeAll()
        show("Lithium olvidó todo lo que recordaba")
    }

    // MARK: - Connectors

    func toggleConnector(_ kind: ConnectorKind) {
        if state.connectors.contains(kind) {
            state.connectors.remove(kind)
            show("Desconectaste \(kind.name)")
        } else {
            state.connectors.insert(kind)
            show("Demostración: con el servidor, aquí autorizarías \(kind.name)")
        }
    }

    /// Returns an error message, or nil when it was added.
    func addCustomConnector(name: String, url: String) -> String? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return "Ponle un nombre al conector." }
        guard cleanURL.hasPrefix("https://"), URL(string: cleanURL)?.host?.contains(".") == true else {
            return "La dirección tiene que empezar por https://"
        }
        state.customConnectors.append(CustomConnector(name: cleanName, url: cleanURL))
        show("Agregaste \(cleanName)")
        return nil
    }

    func removeCustomConnector(_ id: UUID) {
        state.customConnectors.removeAll { $0.id == id }
    }

    // MARK: - Export and editor

    /// Writes a message as a PDF or Word file and returns where it is.
    func exportFile(chatID: UUID, messageID: UUID, word: Bool) -> URL? {
        guard let chat = chat(chatID), let message = chat.messages.first(where: { $0.id == messageID }) else { return nil }
        return exportFile(markdown: String(DocExport.source(of: message.text) ?? Substring(message.text)), title: chat.title, word: word)
    }

    func exportFile(markdown: String, title: String, word: Bool) -> URL? {
        let blocks = DocExport.blocks(fromMarkdown: markdown)
        guard !blocks.isEmpty else {
            show("El documento está vacío.")
            return nil
        }
        let data = word ? DocExport.docx(blocks: blocks, title: title) : DocExport.pdf(blocks: blocks, title: title)
        // A document is named after its own title, not after the chat.
        let name = DocExport.split(blocks, fallback: title).title
        do {
            return try DocExport.temporaryFile(data, title: name, ext: word ? "docx" : "pdf")
        } catch {
            show("No se pudo crear el archivo.")
            return nil
        }
    }

    func saveEdited(chatID: UUID, messageID: UUID, text: String) {
        updateMessage(chatID: chatID, messageID: messageID) { message in
            message.text = text
            message.edited = true
        }
        show("Cambios guardados")
    }

    // MARK: - Payments

    var planPrice: Double {
        state.prefs.plan == .mensual ? state.admin.priceMonthly : state.admin.priceWeekly
    }

    var amountInBolivares: Double {
        (planPrice * state.pay.rate * 100).rounded() / 100
    }

    func submitPagoMovil(reference: String, bank: String) -> Bool {
        let digits = reference.filter(\.isNumber)
        guard digits.count >= 4 else {
            show("Escribe el número de referencia: al menos los últimos 4 dígitos.")
            return false
        }
        addPayment(method: "Pago Móvil · \(bank)", amount: Fmt.bolivares(amountInBolivares), reference: digits)
        show("Recibimos tu comprobante. Lo verificamos en minutos y activamos tu plan.")
        return true
    }

    func submitCrypto(coin: String, network: Network, hash: String) {
        addPayment(method: "\(coin) · \(network.name)", amount: "\(Fmt.decimal2(planPrice)) \(coin)",
                   reference: String(hash.trimmingCharacters(in: .whitespaces).prefix(16)))
        show("Gracias. En cuanto la red confirme el pago, activamos tu plan.")
    }

    private func addPayment(method: String, amount: String, reference: String) {
        let email = state.users.first(where: { $0.isAdmin })?.email ?? ""
        state.payments.insert(Payment(date: Date(), email: email, plan: state.prefs.plan, amount: amount,
                                      method: method, status: .pendiente, reference: reference), at: 0)
    }

    func review(paymentID: UUID, approve: Bool) {
        guard let i = state.payments.firstIndex(where: { $0.id == paymentID }) else { return }
        state.payments[i].status = approve ? .confirmado : .fallido
        if approve, state.users.contains(where: { $0.isAdmin && $0.email == state.payments[i].email }) {
            let days: Double = state.payments[i].plan == .semanal ? 7 : 30
            state.paidUntil = max(state.paidUntil, Date()).addingTimeInterval(days * 86400)
        }
        show(approve ? "Pago aprobado. El plan quedó activo." : "Pago rechazado. Avísale al cliente qué falló.")
    }

    func savePaySettings(_ settings: PaymentSettings) {
        var updated = settings
        if settings.rateEur != state.pay.rateEur || settings.rateUsd != state.pay.rateUsd {
            updated.rateDate = Date()
        }
        state.pay = updated
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
            show("\(state.users[i].name) puede volver a usar Kuolki")
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
        state.usage.creditsCap = config.creditsCap
        if !config.enabledEngines.contains(state.prefs.engine), let first = enabledEngines.first {
            state.prefs.engine = first
        }
        show("Cambios guardados. Se aplican a todos los planes desde ahora.")
    }
}
