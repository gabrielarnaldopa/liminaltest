import SwiftUI
import UIKit
import UniformTypeIdentifiers

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

    var body: some View {
        if message.role == .user {
            userMessage
        } else {
            botMessage
        }
    }

    private var userMessage: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(Array(message.files.enumerated()), id: \.offset) { _, file in
                AttachmentChip(name: file)
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
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 44)
    }

    private var botMessage: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsThinking {
                thinking
            }
            if message.isPending {
                HStack(spacing: 8) {
                    PulsingDot(color: message.tier == .adv ? Palette.yellow : Palette.ink3)
                    Text(message.tier == .adv ? "Pensando con esfuerzo \(message.effort.name.lowercased())…" : "Escribiendo…")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink3)
                }
                .accessibilityElement(children: .combine)
            } else {
                MarkdownView(text: message.text)
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
        if message.tier == .adv {
            return "Avanzado · \(message.effort.name) · \(message.engine.name)"
        }
        return "Rápido · \(message.engine.name)"
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

    var body: some View {
        @Bindable var store = store
        VStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 10) {
                if !store.attachments.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(store.attachments.enumerated()), id: \.offset) { index, name in
                                AttachmentChip(name: name) {
                                    if store.attachments.indices.contains(index) {
                                        store.attachments.remove(at: index)
                                    }
                                }
                            }
                        }
                    }
                }

                TextField(placeholder, text: $store.draft, axis: .vertical)
                    .lineLimit(1...8)
                    .focused($focused)
                    .foregroundStyle(Palette.ink)

                HStack(spacing: 10) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "paperclip")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Palette.ink2)
                            .frame(width: 34, height: 34)
                            .background(Palette.sunk, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Adjuntar archivo")

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

                    Spacer(minLength: 4)

                    if store.state.prefs.tier == .adv && store.state.prefs.effort == .alto && !store.isStreaming {
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
                store.attachments.append(contentsOf: urls.map { $0.lastPathComponent })
            case .failure:
                store.show("No se pudo adjuntar el archivo. Prueba con otro.")
            }
        }
    }

    private var canSend: Bool {
        !store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !store.attachments.isEmpty
    }
}

// MARK: - Markdown

/// Shows the subset of Markdown the replies use: headings, lists, quotes, bold and italics.
struct MarkdownView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(MarkdownBlock.parse(text).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .foregroundStyle(Palette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let line):
            Text(Self.inline(line))
                .font(.headline)
                .padding(.top, 4)
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
    case heading(String)
    case paragraph(String)
    case bullets([String])
    case numbered([NumberedItem])
    case quote([String])

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

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix(">") {
                if quote.isEmpty { flush() }
                quote.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
            } else if line.isEmpty {
                flush()
            } else if line.hasPrefix("#") {
                flush()
                let title = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(title))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
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

    /// "12. Text" → (12, "Text")
    private static func numberedItem(_ line: String) -> NumberedItem? {
        let digits = line.prefix(while: { $0.isNumber })
        guard !digits.isEmpty, digits.count <= 3, let number = Int(digits) else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") else { return nil }
        return NumberedItem(number: number, text: String(rest.dropFirst(2)))
    }
}
