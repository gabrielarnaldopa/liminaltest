import SwiftUI

/// The side menu: new chat, search, projects, folders and your chats, with your usage and account at the bottom.
/// On iPhone it slides over the screen (`compact`); on iPad it is the sidebar column.
struct SideMenu: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthService.self) private var auth
    let compact: Bool

    @State private var search = ""
    @State private var searching = false
    @FocusState private var searchFocused: Bool
    @State private var expandedFolders: Set<UUID> = []
    @State private var showNewProject = false
    @State private var showNewFolder = false
    @State private var newFolderName = ""
    @State private var moveTarget: IDBox?
    @State private var rename: RenameTarget?
    @State private var renameText = ""
    @State private var showRename = false
    @State private var pendingDelete: DeleteTarget?
    @State private var showDelete = false

    private enum RenameTarget { case chat(UUID), folder(UUID) }
    private enum DeleteTarget { case chat(UUID), folder(UUID) }

    private struct ChatGroup {
        let title: String
        let chats: [Chat]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    if searching {
                        results
                    } else {
                        shortcuts
                        projectsSection
                        if !pinnedChats.isEmpty {
                            SectionTitle(text: "Fijados")
                            ForEach(pinnedChats) { chat in chatRow(chat) }
                        }
                        foldersSection
                        ForEach(recentGroups, id: \.title) { group in
                            SectionTitle(text: group.title)
                            ForEach(group.chats) { chat in chatRow(chat) }
                        }
                        if store.visibleChats.isEmpty {
                            Text("Tus chats aparecen aquí.")
                                .font(.k(.footnote))
                                .foregroundStyle(Palette.ink3)
                                .padding(.horizontal, 12)
                                .padding(.top, 14)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.immediately)
            .scrollIndicators(.hidden)
            footer
        }
        .sheet(isPresented: $showNewProject) {
            ProjectEditor(projectID: nil) { id in
                go { store.route = .project(id) }
            }
        }
        .sheet(item: $moveTarget) { target in
            MoveChatSheet(chatID: target.id)
        }
        .alert(renameTitle, isPresented: $showRename) {
            TextField("Nombre", text: $renameText)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") { applyRename() }
        }
        .alert("Nueva carpeta", isPresented: $showNewFolder) {
            TextField("Nombre de la carpeta", text: $newFolderName)
            Button("Cancelar", role: .cancel) { newFolderName = "" }
            Button("Crear") {
                store.createFolder(newFolderName)
                newFolderName = ""
            }
        }
        .confirmationDialog(deleteTitle, isPresented: $showDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { applyDelete() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
    }

    // MARK: - Header and search

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                LogoMark()
                    .fill(Palette.ink)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Text("Kuolki")
                    .font(.k(.title3).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                if searching {
                    Button("Cancelar") {
                        withAnimation(.snappy) {
                            searching = false
                            search = ""
                        }
                    }
                    .font(.k(.subheadline).weight(.medium))
                    .foregroundStyle(Palette.ink2)
                }
            }
            .padding(.horizontal, 4)

            if searching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Palette.ink3)
                    TextField("Buscar chats", text: $search)
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .foregroundStyle(Palette.ink)
                    if !search.isEmpty {
                        Button {
                            search = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Palette.ink3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Borrar la búsqueda")
                    }
                }
                .font(.k(.body))
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(Palette.sunk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, compact ? 10 : 16)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var results: some View {
        let found = searchResults
        if search.trimmingCharacters(in: .whitespaces).isEmpty {
            Text("Escribe para buscar en los títulos y en los mensajes.")
                .font(.k(.footnote))
                .foregroundStyle(Palette.ink3)
                .padding(.horizontal, 12)
                .padding(.top, 6)
        } else if found.isEmpty {
            Text("No hay chats que coincidan con «\(search)».")
                .font(.k(.footnote))
                .foregroundStyle(Palette.ink3)
                .padding(.horizontal, 12)
                .padding(.top, 6)
        } else {
            SectionTitle(text: "Resultados")
            ForEach(found) { chat in chatRow(chat) }
        }
    }

    // MARK: - Shortcuts, projects and folders

    private var shortcuts: some View {
        VStack(alignment: .leading, spacing: 1) {
            Button {
                go { store.newChat() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 16, weight: .medium))
                    Text("Nuevo chat")
                        .font(.k(.body).weight(.medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Palette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScale())
            .padding(.bottom, 6)

            MenuRow(title: "Buscar chats", icon: "magnifyingglass") {
                withAnimation(.snappy) { searching = true }
                searchFocused = true
            }
            MenuRow(title: "Kuolki Dev", icon: "chevron.left.forwardslash.chevron.right") {
                go { store.showDev = true }
            }
            if auth.session?.isAdmin == true {
                MenuRow(title: "Administración", icon: "shield.lefthalf.filled", selected: store.route == .admin) {
                    go { store.route = .admin }
                }
            }
        }
    }

    @ViewBuilder
    private var projectsSection: some View {
        SectionTitle(text: "Proyectos", addLabel: "Nuevo proyecto") { showNewProject = true }
        ForEach(store.projects) { project in
            let selected = store.route == .project(project.id)
            let count = store.visibleChats.filter { $0.projectID == project.id }.count
            Button {
                go { store.route = .project(project.id) }
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(hex: project.colorHex))
                        .frame(width: 9, height: 9)
                        .frame(width: 18)
                    Text(project.name)
                        .font(.k(.body))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(count)")
                        .font(.k(.caption))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink3)
                }
                .rowShape(selected: selected)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(project.name), \(count) chats")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
        if store.projects.isEmpty {
            MenuRow(title: "Crea tu primer proyecto", icon: "plus", muted: true) { showNewProject = true }
        }
    }

    @ViewBuilder
    private var foldersSection: some View {
        SectionTitle(text: "Carpetas", addLabel: "Nueva carpeta") { showNewFolder = true }
        ForEach(store.folders) { folder in
            let chats = store.visibleChats.filter { $0.folderID == folder.id && !$0.pinned }
            let open = expandedFolders.contains(folder.id)
            Button {
                withAnimation(.snappy) {
                    if open { expandedFolders.remove(folder.id) } else { expandedFolders.insert(folder.id) }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: open ? "folder.fill" : "folder")
                        .font(.system(size: 15))
                        .foregroundStyle(Palette.ink2)
                        .frame(width: 18)
                    Text(folder.name)
                        .font(.k(.body))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(chats.count)")
                        .font(.k(.caption))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink3)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.ink3)
                        .rotationEffect(.degrees(open ? 90 : 0))
                }
                .rowShape(selected: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Carpeta \(folder.name), \(chats.count) chats")
            .accessibilityHint(open ? "Toca para cerrarla" : "Toca para abrirla")
            .contextMenu {
                Button {
                    startRename(.folder(folder.id), current: folder.name)
                } label: {
                    Label("Renombrar", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    askDelete(.folder(folder.id))
                } label: {
                    Label("Eliminar carpeta", systemImage: "trash")
                }
            }
            if open {
                if chats.isEmpty {
                    Text("Vacía. Mueve un chat aquí desde su menú.")
                        .font(.k(.footnote))
                        .foregroundStyle(Palette.ink3)
                        .padding(.leading, 40)
                        .padding(.vertical, 6)
                }
                ForEach(chats) { chat in
                    chatRow(chat)
                        .padding(.leading, 28)
                }
            }
        }
    }

    // MARK: - A chat

    private func chatRow(_ chat: Chat) -> some View {
        let selected = store.route == .chat(chat.id)
        let working = chat.messages.last.map { $0.isPending || $0.isStreaming } ?? false
        return Button {
            go { store.route = .chat(chat.id) }
        } label: {
            HStack(spacing: 8) {
                if let projectID = chat.projectID, let project = store.project(projectID) {
                    Circle()
                        .fill(Color(hex: project.colorHex))
                        .frame(width: 7, height: 7)
                }
                Text(chat.title)
                    .font(.k(.body))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if chat.pinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.ink3)
                }
                if working {
                    TypingDots(size: 4.5)
                }
            }
            .rowShape(selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("Mantén presionado para fijar, renombrar, mover o eliminar")
        .contextMenu {
            Button {
                store.togglePin(chat.id)
            } label: {
                Label(chat.pinned ? "Quitar de fijados" : "Fijar", systemImage: chat.pinned ? "pin.slash" : "pin")
            }
            Button {
                startRename(.chat(chat.id), current: chat.title)
            } label: {
                Label("Renombrar", systemImage: "pencil")
            }
            Button {
                moveTarget = IDBox(id: chat.id)
            } label: {
                Label("Mover a proyecto o carpeta", systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) {
                askDelete(.chat(chat.id))
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    // MARK: - Footer: usage and account

    private var footer: some View {
        let name = store.prefs.name.isEmpty ? (auth.session?.name ?? "Tú") : store.prefs.name
        let percent = store.sessionPercent
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Uso · sesión actual")
                        .font(.k(.footnote).weight(.medium))
                        .foregroundStyle(Palette.ink2)
                    Spacer(minLength: 8)
                    Text(percent > 0 && percent < 1 ? "<1% usado" : "\(Int(percent))% usado")
                        .font(.k(.footnote))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink3)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Palette.sunk)
                        Capsule()
                            .fill(percent >= 90 ? Palette.red : percent >= 70 ? Palette.yellow : Palette.green)
                            .frame(width: max(4, geo.size.width * percent / 100))
                    }
                }
                .frame(height: 5)
                Text("Se recarga \(Fmt.relative(store.usage.sessionResetAt ?? Date()))")
                    .font(.k(.caption))
                    .foregroundStyle(Palette.ink3)
            }
            .accessibilityElement(children: .combine)

            Button {
                if compact {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { store.openSettings() }
                } else {
                    store.showSettings = true
                }
            } label: {
                HStack(spacing: 10) {
                    Avatar(name: name, size: 36)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(name)
                                .font(.k(.subheadline).weight(.semibold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            if auth.session?.isAdmin == true {
                                RoleBadge()
                            }
                        }
                        Text("Plan \(store.prefs.plan.name.lowercased()) · Ajustes")
                            .font(.k(.caption))
                            .foregroundStyle(Palette.ink3)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundStyle(Palette.ink2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScale())
            .accessibilityLabel("Ajustes y cuenta de \(name)")
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.line.opacity(0.7)).frame(height: 0.5).padding(.horizontal, 16)
        }
    }

    // MARK: - Data

    /// Does what was picked, then (on iPhone) slides the menu away.
    private func go(_ action: () -> Void) {
        action()
        guard compact else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { store.closeMenu() }
    }

    private var pinnedChats: [Chat] {
        store.visibleChats.filter { $0.pinned }
    }

    private var searchResults: [Chat] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return store.visibleChats.filter { chat in
            chat.title.localizedCaseInsensitiveContains(query)
                || chat.messages.contains { $0.text.localizedCaseInsensitiveContains(query) }
        }
    }

    /// Chats outside projects, folders and pins, grouped by date.
    private var recentGroups: [ChatGroup] {
        let chats = store.visibleChats.filter { !$0.pinned && $0.folderID == nil && $0.projectID == nil }
        let calendar = Calendar.current
        let weekAgo = Date().addingTimeInterval(-7 * 86400)
        var today: [Chat] = []
        var yesterday: [Chat] = []
        var week: [Chat] = []
        var older: [Chat] = []
        for chat in chats {
            if calendar.isDateInToday(chat.updated) {
                today.append(chat)
            } else if calendar.isDateInYesterday(chat.updated) {
                yesterday.append(chat)
            } else if chat.updated > weekAgo {
                week.append(chat)
            } else {
                older.append(chat)
            }
        }
        return [
            ChatGroup(title: "Hoy", chats: today),
            ChatGroup(title: "Ayer", chats: yesterday),
            ChatGroup(title: "Últimos 7 días", chats: week),
            ChatGroup(title: "Anteriores", chats: older)
        ].filter { !$0.chats.isEmpty }
    }

    // MARK: - Rename and delete

    private var renameTitle: String {
        if case .folder? = rename { return "Renombrar carpeta" }
        return "Renombrar chat"
    }

    private func startRename(_ target: RenameTarget, current: String) {
        rename = target
        renameText = current
        showRename = true
    }

    private func applyRename() {
        switch rename {
        case .chat(let id)?: store.renameChat(id, to: renameText)
        case .folder(let id)?: store.renameFolder(id, to: renameText)
        case nil: break
        }
        rename = nil
    }

    private var deleteTitle: String {
        if case .folder? = pendingDelete { return "¿Eliminar esta carpeta?" }
        return "¿Eliminar este chat?"
    }

    private var deleteMessage: String {
        if case .folder? = pendingDelete { return "Los chats que tiene no se borran: vuelven a Recientes." }
        return "No se puede deshacer."
    }

    private func askDelete(_ target: DeleteTarget) {
        pendingDelete = target
        showDelete = true
    }

    private func applyDelete() {
        switch pendingDelete {
        case .chat(let id)?: store.deleteChat(id)
        case .folder(let id)?: store.deleteFolder(id)
        case nil: break
        }
        pendingDelete = nil
    }
}

// MARK: - Pieces of the menu

/// A small gray title over a group of rows, with an optional + on the right.
private struct SectionTitle: View {
    let text: String
    var addLabel: String? = nil
    var onAdd: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(text)
                .font(.k(.footnote).weight(.medium))
                .foregroundStyle(Palette.ink3)
            Spacer(minLength: 8)
            if let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.ink3)
                        .frame(width: 30, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(addLabel ?? "Agregar")
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.top, 18)
        .padding(.bottom, 4)
        .accessibilityAddTraits(.isHeader)
    }
}

/// An action row with an icon (Buscar chats, Kuolki Dev, Administración).
private struct MenuRow: View {
    let title: String
    let icon: String
    var selected = false
    var muted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 18)
                Text(title)
                    .font(.k(.body))
                    .foregroundStyle(muted ? Palette.ink3 : Palette.ink2)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .rowShape(selected: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private extension View {
    /// A plain menu row: no box, just a soft highlight when it is the screen you are on.
    func rowShape(selected: Bool) -> some View {
        self
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? Palette.sel : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
    }
}

// MARK: - Move a chat

struct MoveChatSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let chatID: UUID
    @State private var projectID: UUID?
    @State private var folderID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Proyecto", selection: $projectID) {
                        Text("Ninguno").tag(UUID?.none)
                        ForEach(store.projects) { project in
                            Text(project.name).tag(UUID?.some(project.id))
                        }
                    }
                } footer: {
                    Text("Los chats de un proyecto siguen sus instrucciones y usan sus archivos.")
                }
                Section {
                    Picker("Carpeta", selection: $folderID) {
                        Text("Ninguna").tag(UUID?.none)
                        ForEach(store.folders) { folder in
                            Text(folder.name).tag(UUID?.some(folder.id))
                        }
                    }
                }
            }
            .liminalList()
            .navigationTitle("Mover chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mover") {
                        store.move(chat: chatID, projectID: projectID, folderID: folderID)
                        dismiss()
                    }
                }
            }
            .onAppear {
                let chat = store.chat(chatID)
                projectID = chat?.projectID
                folderID = chat?.folderID
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Create or edit a project

struct ProjectEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// `nil` creates a new project.
    let projectID: UUID?
    var onSaved: ((UUID) -> Void)? = nil

    @State private var name = ""
    @State private var desc = ""
    @State private var color: UInt32 = Palette.projectColors[0]

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Por ejemplo, Tienda Cami", text: $name)
                }
                Section("Descripción") {
                    TextField("Para qué es este proyecto", text: $desc, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Color") {
                    HStack(spacing: 14) {
                        ForEach(Palette.projectColors, id: \.self) { hex in
                            Button {
                                color = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 28, height: 28)
                                    .padding(4)
                                    .overlay(
                                        Circle().stroke(Palette.ink, lineWidth: color == hex ? 2 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(colorName(hex))
                            .accessibilityAddTraits(color == hex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .liminalList()
            .navigationTitle(projectID == nil ? "Nuevo proyecto" : "Editar proyecto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(projectID == nil ? "Crear" : "Guardar") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                if let projectID, let project = store.project(projectID) {
                    name = project.name
                    desc = project.desc
                    color = project.colorHex
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let cleanDesc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        if let projectID {
            store.updateProject(projectID, name: trimmedName, desc: cleanDesc, colorHex: color)
            onSaved?(projectID)
        } else {
            let id = store.createProject(name: trimmedName, desc: cleanDesc, colorHex: color)
            onSaved?(id)
        }
        dismiss()
    }

    private func colorName(_ hex: UInt32) -> String {
        switch hex {
        case 0x28C840: return "Verde"
        case 0xFEBC2E: return "Amarillo"
        case 0xFF5F57: return "Rojo"
        case 0x8E8E93: return "Gris"
        case 0x636366: return "Gris oscuro"
        default: return "Gris claro"
        }
    }
}
