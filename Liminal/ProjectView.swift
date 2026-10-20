import SwiftUI
import UniformTypeIdentifiers

struct ProjectView: View {
    @Environment(AppStore.self) private var store
    let projectID: UUID

    @State private var showEditor = false
    @State private var confirmDelete = false
    @State private var importing = false

    var body: some View {
        if let project = store.project(projectID) {
            content(project)
                .sheet(isPresented: $showEditor) {
                    ProjectEditor(projectID: projectID)
                }
                .confirmationDialog("¿Eliminar «\(project.name)»?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Eliminar proyecto", role: .destructive) { store.deleteProject(projectID) }
                    Button("Cancelar", role: .cancel) {}
                } message: {
                    Text("Sus chats no se borran: pasan a Recientes. Las instrucciones y los archivos sí se borran.")
                }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                    switch result {
                    case .success(let urls):
                        let granted = urls.map { $0.startAccessingSecurityScopedResource() }
                        store.addFiles(urls, to: projectID)
                        for (url, ok) in zip(urls, granted) where ok {
                            url.stopAccessingSecurityScopedResource()
                        }
                    case .failure:
                        store.show("No se pudo agregar el archivo. Prueba con otro.")
                    }
                }
        } else {
            ContentUnavailableView("Proyecto no encontrado", systemImage: "folder.badge.questionmark",
                                   description: Text("Puede que lo hayas eliminado."))
        }
    }

    private func content(_ project: Project) -> some View {
        let chats = store.visibleChats.filter { $0.projectID == projectID }
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: project.colorHex))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.white)
                        )
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.k(.title2).weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        if !project.desc.isEmpty {
                            Text(project.desc)
                                .font(.k(.subheadline))
                                .foregroundStyle(Palette.ink3)
                        }
                        Text("Creado \(Fmt.relative(project.created))")
                            .font(.k(.caption))
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer(minLength: 0)
                }

                // Instructions
                Card(title: "Instrucciones") {
                    Text("Kuolki las sigue en todos los chats de este proyecto.")
                        .font(.k(.footnote))
                        .foregroundStyle(Palette.ink3)
                    TextEditor(text: instructionsBinding)
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(Palette.sunk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(Palette.ink)
                        .accessibilityLabel("Instrucciones del proyecto")
                }

                // Files
                Card(title: "Archivos") {
                    if project.files.isEmpty {
                        Text("Agrega catálogos, apuntes o listas de precios. Kuolki los usa como contexto.")
                            .font(.k(.footnote))
                            .foregroundStyle(Palette.ink3)
                    }
                    ForEach(project.files) { file in
                        HStack(spacing: 10) {
                            AttachmentChip(name: file.name)
                            Text(file.size)
                                .font(.k(.caption))
                                .foregroundStyle(Palette.ink3)
                            Spacer(minLength: 0)
                            Button {
                                store.removeFile(projectID: projectID, fileID: file.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(Palette.redText)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Quitar \(file.name)")
                        }
                    }
                    Button {
                        importing = true
                    } label: {
                        Label("Agregar archivo", systemImage: "plus")
                            .font(.k(.subheadline).weight(.medium))
                            .foregroundStyle(Palette.ink)
                    }
                    .buttonStyle(.plain)
                }

                // Chats
                Card(title: chats.isEmpty ? "Chats" : "Chats (\(chats.count))") {
                    if chats.isEmpty {
                        Text("Todavía no hay chats. Escribe abajo para empezar el primero.")
                            .font(.k(.footnote))
                            .foregroundStyle(Palette.ink3)
                    }
                    ForEach(chats) { chat in
                        Button {
                            store.route = .chat(chat.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: chat.mode.icon)
                                    .foregroundStyle(Palette.ink3)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chat.title)
                                        .foregroundStyle(Palette.ink)
                                        .lineLimit(1)
                                    Text("\(Fmt.relative(chat.updated)) · \(chat.messages.count) mensajes")
                                        .font(.k(.caption))
                                        .foregroundStyle(Palette.ink3)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.k(.caption).weight(.semibold))
                                    .foregroundStyle(Palette.ink3)
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if chat.id != chats.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.bg)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ComposerView(placeholder: "Nuevo chat en \(project.name)")
        }
        .topBar {
            ModelMenu()
        } trailing: {
            Menu {
                Button {
                    showEditor = true
                } label: {
                    Label("Editar proyecto", systemImage: "pencil")
                }
                Button {
                    importing = true
                } label: {
                    Label("Agregar archivo", systemImage: "doc.badge.plus")
                }
                Divider()
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Eliminar proyecto", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 46, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Opciones del proyecto")
            BarDivider()
            BarButton(icon: "square.and.pencil", label: "Nuevo chat") { store.newChat() }
        }
    }

    private var instructionsBinding: Binding<String> {
        Binding(
            get: { store.project(projectID)?.instructions ?? "" },
            set: { newValue in
                if let index = store.state.projects.firstIndex(where: { $0.id == projectID }) {
                    store.state.projects[index].instructions = newValue
                }
            }
        )
    }
}
