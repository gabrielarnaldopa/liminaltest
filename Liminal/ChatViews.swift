import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

// MARK: - Home (new chat)

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthService.self) private var auth

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 36)
                AssemblingLogo(size: 48)
                VStack(spacing: 6) {
                    Text("\(store.greeting), \(firstName)")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(Palette.ink3)
                }
                .multilineTextAlignment(.center)

                if store.isTemporary {
                    Label("Chat temporal: no se guarda en tu historial ni en la memoria.", systemImage: "eye.slash")
                        .font(.footnote)
                        .foregroundStyle(Palette.yellowText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Palette.yellowTint, in: Capsule())
                }

                FlowLayout(spacing: 8) {
                    ForEach(ChatMode.allCases.filter { $0 != .general }) { mode in
                        ModeChip(mode: mode, selected: store.mode == mode) {
                            store.pick(mode: mode)
                        }
                    }
                }

                if store.mode != .general {
                    Text("Modo \(store.mode.name): \(store.mode.summary)")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink3)
                        .transition(.opacity)
                }

                LimitNotice()
            }
            .animation(.easeInOut(duration: 0.2), value: store.mode)
            .frame(maxWidth: 640)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.bg)
        .safeAreaInset(edge: .bottom) {
            ComposerView(placeholder: store.mode == .general ? "Escribe tu mensaje" : "Escribe en modo \(store.mode.name)")
        }
        .liminalToolbar()
    }

    private var firstName: String {
        let name = store.state.prefs.name.isEmpty ? (auth.session?.name ?? "") : store.state.prefs.name
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    private var subtitle: String {
        "¿En qué te ayudo hoy?"
    }
}

// MARK: - Chat

struct ChatView: View {
    @Environment(AppStore.self) private var store
    let chatID: UUID

    @State private var atBottom = true
    @State private var showRename = false
    @State private var newTitle = ""
    @State private var confirmDelete = false
    @State private var moveTarget: IDBox? = nil

    private let bottomID = "bottom"

    var body: some View {
        let chat = store.chat(chatID)
        let messages = chat?.messages ?? []
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if chat?.isTemporary == true {
                        NoticeView(level: .warn, text: "Chat temporal: no se guarda en tu historial y desaparece al salir.")
                    }
                    ForEach(messages) { message in
                        MessageRow(chatID: chatID, message: message, isLast: message.id == messages.last?.id)
                    }
                    LimitNotice()
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                        .onAppear { atBottom = true }
                        .onDisappear { atBottom = false }
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .onChange(of: messages.last?.text) {
                if atBottom {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
        .background(Palette.bg)
        .environment(\.openURL, OpenURLAction { url in
            guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return .systemAction }
            store.browser = BrowserTarget(url: url)
            return .handled
        })
        .safeAreaInset(edge: .bottom) {
            ComposerView(placeholder: "Responde a Liminal")
        }
        .liminalToolbar()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let chat {
                        Button {
                            store.togglePin(chatID)
                        } label: {
                            Label(chat.pinned ? "Quitar de fijados" : "Fijar", systemImage: chat.pinned ? "pin.slash" : "pin")
                        }
                        .disabled(chat.isTemporary)
                        Button {
                            newTitle = chat.title
                            showRename = true
                        } label: {
                            Label("Renombrar", systemImage: "pencil")
                        }
                        Button {
                            moveTarget = IDBox(id: chatID)
                        } label: {
                            Label("Mover a proyecto o carpeta", systemImage: "folder")
                        }
                        .disabled(chat.isTemporary)
                        Divider()
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label("Eliminar chat", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Opciones del chat")
            }
        }
        .alert("Renombrar chat", isPresented: $showRename) {
            TextField("Título", text: $newTitle)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") { store.renameChat(chatID, to: newTitle) }
        }
        .confirmationDialog("¿Eliminar este chat?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { store.deleteChat(chatID) }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("No se puede deshacer.")
        }
        .sheet(item: $moveTarget) { target in
            MoveChatSheet(chatID: target.id)
        }
    }
}

// MARK: - One message

struct MessageRow: View {
    @Environment(AppStore.self) private var store
    let chatID: UUID
    let message: Message
    let isLast: Bool

    @State private var showThought = false
    @State private var copied = false
    @State private var shared: SharedFile? = nil
    @State private var editing: EditorTarget? = nil

    var body: some View {
        Group {
            if message.role == .user {
                userMessage
            } else if let kind = message.kind {
                creationMessage(kind)
            } else {
                botMessage
            }
        }
        .sheet(item: $shared) { file in
            ShareSheet(url: file.url)
        }
        .sheet(item: $editing) { target in
            EditorView(target: target)
        }
    }

    private func creationMessage(_ kind: CreationKind) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if message.isPending {
                HStack(spacing: 8) {
                    PulsingDot(color: Palette.yellow)
                    Text(kind.pendingText)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink3)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text(message.text)
                    .foregroundStyle(Palette.ink)
                if !message.stopped {
                    GeneratedMediaView(kind: kind, seed: message.seed ?? 1, prompt: message.prompt ?? "")
                    HStack(spacing: 18) {
                        Button {
                            store.show("Demostración: en la versión real se descarga el archivo.")
                        } label: {
                            Image(systemName: "arrow.down.to.line")
                        }
                        .accessibilityLabel("Descargar")
                        Button {
                            UIPasteboard.general.string = message.prompt ?? ""
                            store.show("Descripción copiada")
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .accessibilityLabel("Copiar la descripción")
                        if isLast && !store.isStreaming {
                            Button {
                                store.regenerate(chatID: chatID)
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .accessibilityLabel("Crear otra versión")
                        }
                        Spacer(minLength: 8)
                        Text("\(Brand.modelName) · \(kind.name) · \(kind.creditsText)")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink3)
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var userMessage: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(message.files) { file in
                FileChip(attachment: file, onOpen: file.text.isEmpty ? nil : {
                    editing = EditorTarget(title: file.name, text: file.text, chatID: nil, messageID: nil)
                })
            }
            if let key = message.command, let used = SlashCommand.find(key) {
                Label(used.title, systemImage: used.icon)
                    .font(.caption2)
                    .foregroundStyle(Palette.ink3)
            }
            Text(message.text)
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Palette.bubble, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contextMenu {
                    Button {
                        copy()
                    } label: {
                        Label("Copiar", systemImage: "doc.on.doc")
                    }
                    if !store.isStreaming {
                        Button {
                            store.edit(chatID: chatID, messageID: message.id)
                        } label: {
                            Label("Editar y volver a enviar", systemImage: "pencil")
                        }
                    }
                }
            if message.spoken == true {
                Label("Dicho en voz alta", systemImage: "waveform")
                    .font(.caption2)
                    .foregroundStyle(Palette.ink3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 44)
    }

    private var botMessage: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsThinking {
                thinking
            }
            if let steps = message.tools, !steps.isEmpty {
                ToolStepsView(steps: steps) { url in store.browser = BrowserTarget(url: url) }
            }
            if message.isPending {
                HStack(spacing: 8) {
                    PulsingDot(color: message.tier == .adv ? Palette.yellow : Palette.ink3)
                    Text(pendingText)
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink3)
                }
                .accessibilityElement(children: .combine)
            } else {
                MarkdownView(text: message.text, streaming: message.isStreaming)
                if let ask = message.ask, !message.isStreaming {
                    AskCardView(ask: ask) { approved, always in
                        store.answerAsk(chatID: chatID, messageID: message.id, approved: approved, always: always)
                    } onAuto: {
                        store.browseWithoutAsking(chatID: chatID, messageID: message.id)
                    }
                }
                if let notice = message.notice, !message.isStreaming {
                    HStack(spacing: 10) {
                        Label(notice, systemImage: "arrow.clockwise")
                            .font(.footnote)
                            .foregroundStyle(Palette.ink2)
                        if isLast && !store.isStreaming {
                            Button("Continuar") {
                                store.draft = "Continúa justo donde te quedaste."
                                store.send()
                            }
                            .buttonStyle(.bordered)
                            .font(.footnote.weight(.semibold))
                        }
                    }
                }
                if let links = message.links, !links.isEmpty, !message.isStreaming {
                    LinkSourcesView(links: links) { url in store.browser = BrowserTarget(url: url) }
                }
                if !message.isStreaming && !message.sources.isEmpty {
                    sourcesView
                }
                if !message.isStreaming, let memory = message.savedMemory {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "brain")
                            .foregroundStyle(Palette.green)
                        Text("Memoria actualizada: «\(memory.text)»")
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Button("Deshacer") {
                            store.undoMemory(chatID: chatID, messageID: message.id)
                        }
                        .buttonStyle(.borderless)
                        .fontWeight(.semibold)
                    }
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .padding(10)
                    .background(Palette.sunk, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                if !message.isStreaming && !message.stopped, let document = DocExport.document(in: message.text) {
                    DocumentCard(document: document, pdfFirst: DocExport.prefersPDF(request)) { word in
                        if let url = store.exportFile(chatID: chatID, messageID: message.id, word: word) {
                            shared = SharedFile(url: url)
                        }
                    } onEdit: {
                        editing = EditorTarget(title: document.title, text: message.text, chatID: chatID, messageID: message.id)
                    }
                }
                if message.stopped {
                    Label("Respuesta detenida", systemImage: "stop.circle")
                        .font(.caption)
                        .foregroundStyle(Palette.redText)
                }
                if !message.isStreaming {
                    actions
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// What the person asked right before this answer.
    private var request: String {
        guard let messages = store.chat(chatID)?.messages,
              let index = messages.firstIndex(where: { $0.id == message.id }), index > 0 else { return "" }
        return messages[index - 1].role == .user ? messages[index - 1].text : ""
    }

    private var pendingText: String {
        if let step = message.tools?.last(where: { $0.isBusy }) { return step.label }
        if message.searchedWeb { return "Buscando en internet…" }
        if message.isReading { return "Leyendo tus archivos…" }
        if message.tier == .adv { return "Pensando con esfuerzo \(message.effort.name.lowercased())…" }
        return "Escribiendo…"
    }

    private var sourcesView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fuentes (demostración)")
                .font(.caption)
                .foregroundStyle(Palette.ink3)
            FlowLayout(spacing: 6) {
                ForEach(message.sources, id: \.self) { domain in
                    if let url = URL(string: "https://\(domain)") {
                        Link(destination: url) {
                            Label(domain, systemImage: "globe")
                                .font(.caption)
                                .foregroundStyle(Palette.ink2)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Palette.sunk, in: Capsule())
                        }
                    }
                }
            }
        }
    }

    private var showsThinking: Bool {
        message.tier == .adv && !message.thought.isEmpty && store.state.prefs.showThinking && !message.isPending
    }

    private var thinking: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.snappy) { showThought.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                    Text("Pensó \(message.thinkingSeconds) s")
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .rotationEffect(.degrees(showThought ? 90 : 0))
                }
                .font(.footnote)
                .foregroundStyle(Palette.ink3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showThought ? "Ocultar razonamiento" : "Ver razonamiento, pensó \(message.thinkingSeconds) segundos")

            if showThought {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(message.thought.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(Palette.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Palette.line2)
                        .frame(width: 2)
                }
                .transition(.opacity)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 18) {
            Button {
                copy()
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? Palette.green : Palette.ink3)
            }
            .accessibilityLabel(copied ? "Copiado" : "Copiar respuesta")

            Menu {
                Button {
                    if let url = store.exportFile(chatID: chatID, messageID: message.id, word: false) {
                        shared = SharedFile(url: url)
                    }
                } label: {
                    Label("Descargar PDF", systemImage: "doc.richtext")
                }
                Button {
                    if let url = store.exportFile(chatID: chatID, messageID: message.id, word: true) {
                        shared = SharedFile(url: url)
                    }
                } label: {
                    Label("Descargar Word", systemImage: "doc.text")
                }
                Button {
                    editing = EditorTarget(title: DocExport.document(in: message.text)?.title ?? store.chat(chatID)?.title ?? "Documento",
                                           text: message.text, chatID: chatID, messageID: message.id)
                } label: {
                    Label("Abrir en el editor", systemImage: "square.and.pencil")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Palette.ink3)
            }
            .accessibilityLabel("Exportar o editar")

            Button {
                store.setFeedback(chatID: chatID, messageID: message.id, .up)
            } label: {
                Image(systemName: message.feedback == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .foregroundStyle(message.feedback == .up ? Palette.green : Palette.ink3)
            }
            .accessibilityLabel("Buena respuesta")
            .accessibilityAddTraits(message.feedback == .up ? .isSelected : [])

            Button {
                store.setFeedback(chatID: chatID, messageID: message.id, .down)
            } label: {
                Image(systemName: message.feedback == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .foregroundStyle(message.feedback == .down ? Palette.red : Palette.ink3)
            }
            .accessibilityLabel("Mala respuesta")
            .accessibilityAddTraits(message.feedback == .down ? .isSelected : [])

            if isLast && !store.isStreaming {
                Button {
                    store.regenerate(chatID: chatID)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(Palette.ink3)
                }
                .accessibilityLabel("Volver a generar")
            }

            Spacer(minLength: 8)

            Text(meta)
                .font(.caption2)
                .foregroundStyle(Palette.ink3)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .font(.subheadline)
        .buttonStyle(.plain)
    }

    private var meta: String {
        let base = message.tier == .adv ? "\(Brand.modelName) · Avanzado · \(message.effort.name)" : "\(Brand.modelName) · Rápido"
        let spoken = message.spoken == true ? base + " · en vivo" : base
        return message.edited ? spoken + " · editado" : spoken
    }

    private func copy() {
        UIPasteboard.general.string = message.text
        copied = true
        store.show("Copiado")
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}

// MARK: - Composer

struct ComposerView: View {
    @Environment(AppStore.self) private var store
    var placeholder: String

    @FocusState private var focused: Bool
    @State private var showImporter = false
    @State private var showCamera = false
    @State private var showPhotos = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var recorder = VoiceRecorder()

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 10) {
                if !store.attachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.attachments) { attachment in
                                FileChip(attachment: attachment, onRemove: {
                                    store.removeAttachment(attachment.id)
                                })
                            }
                        }
                    }
                }

                if recorder.isRecording {
                    recordingBar
                }

                TextField(store.creating?.placeholder ?? store.command?.placeholder ?? placeholder, text: $store.draft, axis: .vertical)
                    .lineLimit(1...8)
                    .focused($focused)
                    .foregroundStyle(Palette.ink)

                HStack(spacing: 8) {
                    plusMenu

                    Menu {
                        Picker("Modo", selection: $store.mode) {
                            ForEach(ChatMode.allCases) { mode in
                                Label(mode.name, systemImage: mode.icon).tag(mode)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: store.mode.icon)
                            Text(store.mode.name)
                                .lineLimit(1)
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Palette.ink2)
                        .padding(.horizontal, 11)
                        .frame(height: 34)
                        .background(Palette.sunk, in: Capsule())
                    }
                    .accessibilityLabel("Modo: \(store.mode.name)")

                    if store.searchWeb {
                        toolChip("Búsqueda", icon: "globe") { store.searchWeb = false }
                    }
                    if store.research {
                        toolChip("Investigación a fondo", icon: "books.vertical") { store.research = false }
                    }
                    if let creating = store.creating {
                        toolChip(creating.name, icon: creating.icon) { store.creating = nil }
                    }
                    if let command = store.command {
                        toolChip(command.title, icon: command.icon) { store.command = nil }
                    }

                    Spacer(minLength: 4)

                    if store.state.prefs.tier == .adv && store.state.prefs.effort == .alto && !store.isStreaming && store.creating == nil {
                        Text("Cuenta doble")
                            .font(.caption)
                            .foregroundStyle(Palette.yellowText)
                    }

                    if store.isStreaming {
                        Button {
                            store.stop()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Palette.red, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Detener respuesta")
                    } else if showsVoiceButton {
                        Button {
                            focused = false
                            store.startVoice()
                        } label: {
                            Image(systemName: "waveform")
                                .font(.body.weight(.bold))
                                .foregroundStyle(Palette.bg)
                                .frame(width: 34, height: 34)
                                .background(Palette.ink, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Conversación en vivo")
                        .accessibilityHint("Habla con Lithium y te responde en voz alta")
                    } else {
                        Button {
                            store.send()
                        } label: {
                            Image(systemName: "arrow.up")
                                .font(.body.weight(.bold))
                                .foregroundStyle(Palette.bg)
                                .frame(width: 34, height: 34)
                                .background(canSend ? Palette.ink : Palette.ink3.opacity(0.5), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSend)
                        .accessibilityLabel("Enviar")
                        .keyboardShortcut(.return, modifiers: .command)
                    }
                }
            }
            .padding(12)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(focused ? Palette.line2 : Palette.line, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
            .overlay(alignment: .top) {
                // Typing "/" shows the commands over the composer.
                if let query = SlashCommand.typing(store.draft) {
                    let found = SlashCommand.matches(query)
                    if !found.isEmpty {
                        SlashSuggestions(commands: found) { picked in
                            store.use(picked)
                            focused = true
                        }
                        .alignmentGuide(.top) { dimensions in dimensions.height + 8 }
                    }
                }
            }

            Text("Liminal puede equivocarse. Revisa lo importante.")
                .font(.caption2)
                .foregroundStyle(Palette.ink3)
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(Palette.bg)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                store.addFiles(urls)
            case .failure:
                store.show("No se pudo adjuntar el archivo. Prueba con otro.")
            }
        }
        .photosPicker(isPresented: $showPhotos, selection: $photoItems, maxSelectionCount: 5, matching: .images)
        .onChange(of: photoItems) { _, items in
            loadPhotos(items)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                store.addAttachment(FileReader.photoAttachment(image, name: "foto-\(Int(Date().timeIntervalSince1970)).jpg"))
            }
            .ignoresSafeArea()
        }
    }

    private var plusMenu: some View {
        Menu {
            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("Subir archivos", systemImage: "paperclip")
                }
                Button {
                    showPhotos = true
                } label: {
                    Label("Fotos", systemImage: "photo.on.rectangle")
                }
                Button {
                    showCamera = true
                } label: {
                    Label("Tomar una foto", systemImage: "camera")
                }
                Button {
                    toggleRecording()
                } label: {
                    Label(recorder.isRecording ? "Detener la grabación" : "Grabar una nota de voz", systemImage: "mic")
                }
                Button {
                    focused = false
                    store.startVoice()
                } label: {
                    Label("Conversación en vivo", systemImage: "waveform")
                }
                .disabled(recorder.isRecording)
                Button {
                    store.browser = BrowserTarget(url: nil)
                } label: {
                    Label("Navegador", systemImage: "safari")
                }
                Button {
                    store.draft = "/"
                    focused = true
                } label: {
                    Label("Comandos (escribe /)", systemImage: "command")
                }
            }
            Section {
                Toggle(isOn: Binding(get: { store.searchWeb }, set: { store.searchWeb = $0 })) {
                    Label("Buscar en internet", systemImage: "globe")
                }
                Toggle(isOn: Binding(get: { store.research }, set: { store.research = $0; if $0 { store.searchWeb = false } })) {
                    Label("Investigación a fondo", systemImage: "books.vertical")
                }
                Button {
                    store.creating = .image
                } label: {
                    Label("Crear imagen · 1 crédito", systemImage: "photo")
                }
                Button {
                    store.creating = .video
                } label: {
                    Label("Crear video de 5 s · 5 créditos", systemImage: "video")
                }
            }
            Section {
                Button {
                    store.showConnectors = true
                } label: {
                    Label("Conectores", systemImage: "puzzlepiece.extension")
                }
                Text("Te quedan \(store.creditsLeft) de \(store.state.usage.creditsCap) créditos este mes")
            }
        } label: {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .frame(width: 34, height: 34)
                .background(Palette.sunk, in: Circle())
        }
        .accessibilityLabel("Agregar archivos y herramientas")
    }

    private func toolChip(_ title: String, icon: String, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Quitar \(title)")
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 11)
        .frame(height: 34)
        .background(Palette.sel, in: Capsule())
    }

    private var recordingBar: some View {
        HStack(spacing: 10) {
            PulsingDot(color: Palette.red)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text("Grabando \(Attachment.clock(context.date.timeIntervalSince(recorder.startedAt ?? context.date)))")
                    .monospacedDigit()
            }
            Spacer(minLength: 4)
            Button("Detener") {
                toggleRecording()
            }
            .buttonStyle(.bordered)
        }
        .font(.subheadline)
        .foregroundStyle(Palette.ink)
        .padding(8)
        .background(Palette.redTint, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func toggleRecording() {
        if recorder.isRecording {
            if let note = recorder.stop() {
                store.addAttachment(note)
            }
        } else {
            Task {
                if !(await recorder.start()) {
                    store.show("No se pudo usar el micrófono. Revisa el permiso en Ajustes.")
                }
            }
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        photoItems = []
        for (offset, item) in items.enumerated() {
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    store.addAttachment(FileReader.photoAttachment(image, name: "foto-\(offset + 1).jpg"))
                }
            }
        }
    }

    /// With nothing written, the send button becomes the live conversation button.
    private var showsVoiceButton: Bool {
        store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.attachments.isEmpty
            && store.creating == nil && store.command == nil && !recorder.isRecording
    }

    private var canSend: Bool {
        let hasContent = !store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.attachments.isEmpty
        return hasContent && !store.attachments.contains(where: { $0.isReading })
    }
}

// MARK: - Editor

struct EditorTarget: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let chatID: UUID?
    let messageID: UUID?
}

/// Edit an answer or a file's text, then save it or export it as PDF or Word.
struct EditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let target: EditorTarget

    @State private var text = ""
    @State private var shared: SharedFile? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .background(Palette.raised)
                    .accessibilityLabel("Documento")
                Text("Usa ### para títulos y - al inicio de la línea para listas.")
                    .font(.caption)
                    .foregroundStyle(Palette.ink3)
                    .padding(8)
            }
            .background(Palette.raised)
            .navigationTitle(target.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            share(word: false)
                        } label: {
                            Label("Descargar PDF", systemImage: "doc.richtext")
                        }
                        Button {
                            share(word: true)
                        } label: {
                            Label("Descargar Word", systemImage: "doc.text")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Exportar")
                    if let chatID = target.chatID, let messageID = target.messageID {
                        Button("Guardar") {
                            store.saveEdited(chatID: chatID, messageID: messageID, text: text)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear { text = target.text }
            .sheet(item: $shared) { file in
                ShareSheet(url: file.url)
            }
        }
    }

    private func share(word: Bool) {
        if let url = store.exportFile(markdown: text, title: target.title, word: word) {
            shared = SharedFile(url: url)
        }
    }
}

// MARK: - Created image or video (demo preview)

/// Stand-in for a created image or video until the real engines are connected.
struct GeneratedMediaView: View {
    let kind: CreationKind
    let seed: UInt32
    let prompt: String

    @State private var moving = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                art
                    .aspectRatio(kind == .video ? 16.0 / 9.0 : 1, contentMode: .fit)
                    .clipped()
                    .overlay {
                        if kind == .video {
                            Image(systemName: "play.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 52, height: 52)
                                .background(Color.black.opacity(0.45), in: Circle())
                        }
                    }
                Text(kind == .video ? "0:05 · 720p" : "1024 × 1024")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .padding(10)
            }
            Text("Vista previa de demostración")
                .font(.caption)
                .foregroundStyle(Palette.ink3)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(Palette.sunk)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .frame(maxWidth: 420, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind == .video ? "Video creado a partir de: \(prompt)" : "Imagen creada a partir de: \(prompt)")
        .onAppear {
            guard kind == .video, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { moving = true }
        }
    }

    private var art: some View {
        let hue1 = Double(seed % 360) / 360
        let hue2 = Double((seed % 360 + 40 + (seed >> 9) % 120) % 360) / 360
        let hue3 = Double((seed % 360 + 180) % 360) / 360
        let x = 0.2 + Double((seed >> 3) % 60) / 100
        let y = 0.15 + Double((seed >> 7) % 40) / 100
        let radius = 0.14 + Double((seed >> 11) % 20) / 100
        return GeometryReader { geo in
            let size = geo.size
            ZStack {
                LinearGradient(colors: [Color(hue: hue1, saturation: 0.6, brightness: 0.92),
                                        Color(hue: hue2, saturation: 0.7, brightness: 0.5)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(Color(hue: hue3, saturation: 0.45, brightness: 1).opacity(0.55))
                    .frame(width: size.width * radius * 2, height: size.width * radius * 2)
                    .position(x: size.width * x, y: size.height * y)
                WaveShape()
                    .fill(Color(hue: hue2, saturation: 0.5, brightness: 0.22).opacity(0.55))
            }
            .scaleEffect(moving ? 1.12 : 1)
        }
    }
}

/// A soft hill along the bottom of the preview.
struct WaveShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        let base = rect.height * 0.72
        path.move(to: CGPoint(x: rect.minX, y: base))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.55, y: base - rect.height * 0.03),
                          control: CGPoint(x: rect.width * 0.3, y: base - rect.height * 0.14))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: base - rect.height * 0.09),
                          control: CGPoint(x: rect.width * 0.8, y: base + rect.height * 0.08))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Markdown

/// Shows the Markdown the replies use: headings, lists, quotes, tables, code, and live pages.
struct MarkdownView: View {
    let text: String
    var streaming: Bool = false
    @State private var openDoc: ArtifactDoc? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(MarkdownBlock.parse(text).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .fullScreenCover(item: $openDoc) { doc in
            ArtifactView(doc: doc)
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .title(let line):
            Text(Self.inline(line))
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
        case .heading(let line):
            Text(Self.inline(line))
                .font(.headline)
                .padding(.top, 4)
        case .rule:
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
                .padding(.vertical, 4)
        case .table(let rows):
            MarkdownTable(rows: rows)
        case .code(let lang, let code):
            if ["grafico", "gráfico", "chart", "calculadora", "calculator"].contains(lang.lowercased()) {
                WidgetBlockView(lang: lang, code: code)
            } else {
                CodeBlockView(lang: lang, code: code)
            }
        case .artifact(let doc):
            ArtifactCard(doc: doc, writing: streaming && !doc.closed) {
                openDoc = doc
            }
        case .paragraph(let line):
            Text(Self.inline(line))
                .fixedSize(horizontal: false, vertical: true)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .foregroundStyle(Palette.ink3)
                        Text(Self.inline(item))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .numbered(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(item.number).")
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink3)
                        Text(Self.inline(item.text))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .quote(let lines):
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Palette.line2)
                    .frame(width: 3)
                Text(Self.inline(lines.joined(separator: "\n")))
                    .foregroundStyle(Palette.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

struct NumberedItem {
    let number: Int
    let text: String
}

enum MarkdownBlock {
    case title(String)
    case heading(String)
    case paragraph(String)
    case bullets([String])
    case numbered([NumberedItem])
    case quote([String])
    case table([[String]])
    case rule
    case code(String, String)
    case artifact(ArtifactDoc)

    static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var numbered: [NumberedItem] = []
        var quote: [String] = []

        func flush() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: "\n")))
                paragraph = []
            }
            if !bullets.isEmpty {
                blocks.append(.bullets(bullets))
                bullets = []
            }
            if !numbered.isEmpty {
                blocks.append(.numbered(numbered))
                numbered = []
            }
            if !quote.isEmpty {
                blocks.append(.quote(quote))
                quote = []
            }
        }

        let lines = text.components(separatedBy: "\n")
        var index = 0
        var pages = 0
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            index += 1
            if lines[index - 1].hasPrefix("```") {
                // A fenced code block; a complete HTML file becomes a live page.
                flush()
                let lang = String(lines[index - 1].dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                while index < lines.count, !lines[index].hasPrefix("```") {
                    body.append(lines[index])
                    index += 1
                }
                let closed = index < lines.count
                if closed { index += 1 }
                let code = body.joined(separator: "\n")
                if let kind = ArtifactDoc.kind(lang: lang, code: code) {
                    let fallback: String
                    switch kind {
                    case .page: fallback = "Página web"
                    case .slides: fallback = "Presentación"
                    case .svg: fallback = "Imagen SVG"
                    }
                    blocks.append(.artifact(ArtifactDoc(index: pages, kind: kind, code: code, title: ArtifactDoc.title(in: code) ?? fallback,
                                                        closed: closed, lines: body.count)))
                    pages += 1
                } else {
                    blocks.append(.code(lang, code))
                }
            } else if isRow(line), index < lines.count, isSeparator(lines[index].trimmingCharacters(in: .whitespaces)) {
                flush()
                var rows = [cells(line)]
                index += 1
                while index < lines.count, isRow(lines[index].trimmingCharacters(in: .whitespaces)) {
                    rows.append(cells(lines[index].trimmingCharacters(in: .whitespaces)))
                    index += 1
                }
                blocks.append(.table(rows))
            } else if isRule(line) {
                flush()
                blocks.append(.rule)
            } else if line.hasPrefix(">") {
                if quote.isEmpty { flush() }
                quote.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
            } else if line.isEmpty {
                flush()
            } else if line.hasPrefix("#") {
                flush()
                let hashes = line.prefix(while: { $0 == "#" }).count
                let title = line.dropFirst(hashes).trimmingCharacters(in: .whitespaces)
                blocks.append(hashes == 1 ? .title(title) : .heading(title))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                if bullets.isEmpty { flush() }
                bullets.append(String(line.dropFirst(2)))
            } else if let item = numberedItem(line) {
                if numbered.isEmpty { flush() }
                numbered.append(item)
            } else {
                if !bullets.isEmpty || !numbered.isEmpty || !quote.isEmpty { flush() }
                paragraph.append(line)
            }
        }
        flush()
        return blocks
    }

    private static func isRule(_ line: String) -> Bool {
        guard line.count >= 3, let first = line.first, "-*_".contains(first) else { return false }
        return line.allSatisfy { $0 == first }
    }

    private static func isRow(_ line: String) -> Bool {
        line.count >= 2 && line.hasPrefix("|") && line.hasSuffix("|")
    }

    private static func isSeparator(_ line: String) -> Bool {
        line.contains("--") && line.allSatisfy { "|-: ".contains($0) }
    }

    private static func cells(_ line: String) -> [String] {
        var inner = Substring(line)
        if inner.hasPrefix("|") { inner = inner.dropFirst() }
        if inner.hasSuffix("|") { inner = inner.dropLast() }
        return String(inner).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// "12. Text" → (12, "Text")
    private static func numberedItem(_ line: String) -> NumberedItem? {
        let digits = line.prefix(while: { $0.isNumber })
        guard !digits.isEmpty, digits.count <= 3, let number = Int(digits) else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") else { return nil }
        return NumberedItem(number: number, text: String(rest.dropFirst(2)))
    }
}

/// A Markdown table: header in bold, rows separated by thin lines, scrolls sideways when it is wide.
struct MarkdownTable: View {
    let rows: [[String]]

    var body: some View {
        let columns = rows.map(\.count).max() ?? 0
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    GridRow(alignment: .top) {
                        ForEach(0..<columns, id: \.self) { column in
                            Text(MarkdownView.inline(column < row.count ? row[column] : ""))
                                .font(index == 0 ? .subheadline.weight(.semibold) : .subheadline)
                                .foregroundStyle(index == 0 ? Palette.ink2 : Palette.ink)
                                .frame(minWidth: 80, maxWidth: 220, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.vertical, 8)
                        }
                    }
                    Rectangle()
                        .fill(Palette.line)
                        .frame(height: 1)
                        .gridCellUnsizedAxes(.horizontal)
                }
            }
        }
    }
}

// MARK: - Document card

/// Shown under an answer that is a document: download it as Word or PDF, or open it in the editor.
struct DocumentCard: View {
    let document: DocumentInfo
    let pdfFirst: Bool
    let onDownload: (_ word: Bool) -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 40, height: 48)
                    .background(Palette.sunk, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                    Text("Documento · \(Fmt.int(document.words)) palabras")
                        .font(.caption)
                        .foregroundStyle(Palette.ink3)
                }
            }
            HStack(spacing: 8) {
                if pdfFirst {
                    download("PDF", primary: true) { onDownload(false) }
                    download("Word", primary: false) { onDownload(true) }
                } else {
                    download("Word", primary: true) { onDownload(true) }
                    download("PDF", primary: false) { onDownload(false) }
                }
                Button(action: onEdit) {
                    Label("Editar", systemImage: "square.and.pencil")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Palette.line2, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Abrir en el editor")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.line, lineWidth: 1))
    }

    private func download(_ format: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(format, systemImage: "arrow.down.to.line")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(primary ? Palette.bg : Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(primary ? Palette.ink : Palette.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(primary ? Color.clear : Palette.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Descargar en \(format)")
    }
}

/// A code block: dark, monospaced, scrolls sideways, with a copy button.
struct CodeBlockView: View {
    let lang: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(lang.isEmpty ? "código" : lang)
                    .font(.caption)
                    .foregroundStyle(Palette.codeMuted)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copiado" : "Copiar", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(Palette.codeMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Palette.codeHead)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(verbatim: code)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Palette.codeInk)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(12)
            }
        }
        .background(Palette.codeBg)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
