import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthService.self) private var auth
    @Binding var compactColumn: NavigationSplitViewColumn
    @Binding var showSettings: Bool

    @State private var search = ""
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
        List {
            if search.isEmpty {
                Section {
                    navRow("Nuevo chat", icon: "square.and.pencil", selected: store.route == .home) {
                        store.newChat()
                    }
                    if auth.session?.isAdmin == true {
                        navRow("Administración", icon: "shield.lefthalf.filled", selected: store.route == .admin) {
                            store.route = .admin
                        }
                    }
                }

                Section("Proyectos") {
                    ForEach(store.state.projects) { project in
                        projectRow(project)
                    }
                    Button {
                        showNewProject = true
                    } label: {
                        Label("Nuevo proyecto", systemImage: "plus")
                            .foregroundStyle(Palette.ink2)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }

                if !pinnedChats.isEmpty {
                    Section("Fijados") {
                        ForEach(pinnedChats) { chat in
                            chatRow(chat)
                        }
                    }
                }

                Section("Carpetas") {
                    ForEach(store.state.folders) { folder in
                        folderRow(folder)
                    }
                    Button {
                        showNewFolder = true
                    } label: {
                        Label("Nueva carpeta", systemImage: "folder.badge.plus")
                            .foregroundStyle(Palette.ink2)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                }

                ForEach(recentGroups, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.chats) { chat in
                            chatRow(chat)
                        }
                    }
                }
            } else {
                Section("Resultados") {
                    if searchResults.isEmpty {
                        Text("No hay chats que coincidan con «\(search)».")
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink3)
                            .listRowBackground(Color.clear)
                    }
                    ForEach(searchResults) { chat in
                        chatRow(chat)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .liminalList()
        .searchable(text: $search, prompt: "Buscar chats")
        .navigationTitle("Liminal")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                LogoMark()
                    .fill(Palette.ink)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.newChat()
                    compactColumn = .detail
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("Nuevo chat")
            }
        }
        .safeAreaInset(edge: .bottom) {
            footer
        }
        .sheet(isPresented: $showNewProject) {
            ProjectEditor(projectID: nil) { _ in
                compactColumn = .detail
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

    // MARK: - Rows

    private func navRow(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            compactColumn = .detail
        } label: {
            Label(title, systemImage: icon)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(rowBackground(selected))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func projectRow(_ project: Project) -> some View {
        let selected = store.route == .project(project.id)
        let count = store.visibleChats.filter { $0.projectID == project.id }.count
        return Button {
            store.route = .project(project.id)
            compactColumn = .detail
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(hex: project.colorHex))
                    .frame(width: 14, height: 14)
                Text(project.name)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(count)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(rowBackground(selected))
        .accessibilityLabel("\(project.name), \(count) chats")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func folderRow(_ folder: Folder) -> some View {
        let chats = store.visibleChats.filter { $0.folderID == folder.id && !$0.pinned }
        return DisclosureGroup(isExpanded: expandedBinding(folder.id)) {
            if chats.isEmpty {
                Text("Vacía. Mueve un chat aquí desde su menú.")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink3)
                    .listRowBackground(Color.clear)
            }
            ForEach(chats) { chat in
                chatRow(chat)
            }
        } label: {
            Label(folder.name, systemImage: "folder")
                .foregroundStyle(Palette.ink)
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
        }
        .listRowBackground(Color.clear)
    }

    private func chatRow(_ chat: Chat) -> some View {
        let selected = store.route == .chat(chat.id)
        let working = chat.messages.last.map { $0.isPending || $0.isStreaming } ?? false
        return Button {
            store.route = .chat(chat.id)
            compactColumn = .detail
        } label: {
            HStack(spacing: 8) {
                if let projectID = chat.projectID, let project = store.project(projectID) {
                    Circle()
                        .fill(Color(hex: project.colorHex))
                        .frame(width: 7, height: 7)
                }
                Text(chat.title)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if working {
                    PulsingDot(color: Palette.yellow)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(rowBackground(selected))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                askDelete(.chat(chat.id))
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
            .tint(Palette.red)
            Button {
                moveTarget = IDBox(id: chat.id)
            } label: {
                Label("Mover", systemImage: "folder")
            }
            .tint(Color(hex: 0x636366))
        }
        .swipeActions(edge: .leading) {
            Button {
                store.togglePin(chat.id)
            } label: {
                Label(chat.pinned ? "Quitar" : "Fijar", systemImage: chat.pinned ? "pin.slash" : "pin")
            }
            .tint(Color(hex: 0x8E8E93))
        }
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

    private func rowBackground(_ selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(selected ? Palette.sel : Color.clear)
            .padding(.horizontal, 6)
    }

    // MARK: - Footer: usage and account

    private var footer: some View {
        let usage = store.state.usage
        let name = store.state.prefs.name.isEmpty ? (auth.session?.name ?? "Tú") : store.state.prefs.name
        return VStack(spacing: 12) {
            UsageMeter(title: "Avanzado, ventana de 5 h", used: usage.adv, cap: usage.advCap,
                       detail: "Se recarga \(Fmt.relative(usage.resetAt))")
            Button {
                showSettings = true
            } label: {
                HStack(spacing: 10) {
                    Avatar(name: name, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            if auth.session?.isAdmin == true {
                                RoleBadge()
                            }
                        }
                        Text("Plan \(store.state.prefs.plan.name.lowercased())")
                            .font(.caption)
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "gearshape")
                        .foregroundStyle(Palette.ink3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ajustes y cuenta de \(name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Palette.side)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.line).frame(height: 0.5)
        }
    }

    // MARK: - Data

    private var pinnedChats: [Chat] {
        store.visibleChats.filter { $0.pinned }
    }

    private var searchResults: [Chat] {
        let query = search.trimmingCharacters(in: .whitespaces)
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

    private func expandedBinding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedFolders.contains(id) },
            set: { isOpen in
                if isOpen {
                    expandedFolders.insert(id)
                } else {
                    expandedFolders.remove(id)
                }
            }
        )
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
                        ForEach(store.state.projects) { project in
                            Text(project.name).tag(UUID?.some(project.id))
                        }
                    }
                } footer: {
                    Text("Los chats de un proyecto siguen sus instrucciones y usan sus archivos.")
                }
                Section {
                    Picker("Carpeta", selection: $folderID) {
                        Text("Ninguna").tag(UUID?.none)
                        ForEach(store.state.folders) { folder in
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
