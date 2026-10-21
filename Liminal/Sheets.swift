import SwiftUI
import PhotosUI

// MARK: - Opening screen

/// The first second of the app: the Kuolki mark and name, then the app fades in.
struct SplashView: View {
    var body: some View {
        ZStack {
            Palette.bg.ignoresSafeArea()
            HStack(spacing: 12) {
                LogoMark()
                    .fill(Palette.ink)
                    .frame(width: 40, height: 40)
                Text("Kuolki")
                    .font(.k(.largeTitle).weight(.bold))
                    .foregroundStyle(Palette.ink)
            }
            VStack {
                Spacer()
                Text(Brand.modelName.uppercased())
                    .font(.k(.footnote).weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Palette.ink3)
                    .padding(.bottom, 18)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Kuolki")
    }
}

// MARK: - Pieces shared by the sheets and the settings

/// A white card with large rounded corners that holds rows.
struct SheetCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// One row: an outline icon, a title (and an optional line under it), a value and a chevron.
struct SheetRow: View {
    var icon: String? = nil
    let title: String
    var detail: String? = nil
    var value: String? = nil
    var chevron = false
    var checked = false

    var body: some View {
        HStack(spacing: 14) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 26)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.k(.body))
                    .foregroundStyle(Palette.ink)
                if let detail {
                    Text(detail)
                        .font(.k(.subheadline))
                        .foregroundStyle(Palette.ink3)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.k(.body))
                    .foregroundStyle(Palette.ink3)
                    .lineLimit(1)
            }
            if checked {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.accent)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, detail == nil ? 15 : 12)
        .contentShape(Rectangle())
    }
}

/// The thin line between rows, starting after the icon.
struct SheetDivider: View {
    var inset: CGFloat = 58
    var body: some View {
        Rectangle().fill(Palette.line).frame(height: 0.5).padding(.leading, inset)
    }
}

/// The round close button at the top left of a sheet.
struct SheetClose: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 40, height: 40)
                .background(Palette.raised, in: Circle())
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(PressScale())
        .accessibilityLabel("Cerrar")
    }
}

extension View {
    /// A sheet that opens at half height and slides up to show everything.
    func pullUpSheet() -> some View {
        self
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .presentationBackground(Palette.bg)
            .presentationContentInteraction(.scrolls)
    }
}

// MARK: - Choose the model

/// Opens from the model button at the top: Rápido or Avanzado and the effort first;
/// slide it up for the mode, the reasoning, browsing and a temporary chat.
struct ModelSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SheetCard {
                        ForEach(Array(Tier.allCases.enumerated()), id: \.element) { index, tier in
                            if index > 0 { SheetDivider(inset: 18) }
                            Button {
                                store.prefs.tier = tier
                            } label: {
                                tierRow(tier)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("\(Brand.modelName) combina varios motores y elige el mejor para cada mensaje.")
                        .font(.k(.footnote))
                        .foregroundStyle(Palette.ink3)
                        .padding(.horizontal, 18)
                        .padding(.top, 10)

                    SheetCard {
                        NavigationLink {
                            EffortPicker()
                        } label: {
                            SheetRow(title: "Esfuerzo", value: store.prefs.tier == .adv ? store.prefs.effort.name : "Solo en Avanzado", chevron: true)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.prefs.tier != .adv)
                    }
                    .padding(.top, 22)

                    // Slide the sheet up to see these.
                    SheetCard {
                        NavigationLink {
                            ModePicker()
                        } label: {
                            SheetRow(icon: store.mode.icon, title: "Modo", value: store.mode.name, chevron: true)
                        }
                        .buttonStyle(.plain)
                        SheetDivider()
                        Toggle(isOn: $store.prefs.showThinking) {
                            Label { Text("Mostrar razonamiento").font(.k(.body)) } icon: { Image(systemName: "brain") }
                        }
                        .tint(Palette.accent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        SheetDivider()
                        Toggle(isOn: Binding(get: { store.isTemporary }, set: { store.isTemporary = $0 })) {
                            Label { Text("Chat temporal").font(.k(.body)) } icon: { Image(systemName: "hourglass") }
                        }
                        .tint(Palette.accent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 22)

                    SheetCard {
                        Button {
                            dismiss()
                            store.openSettings()
                        } label: {
                            SheetRow(icon: "slider.horizontal.3", title: "Más ajustes del modelo", chevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 22)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle("Elige el modelo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetClose { dismiss() }
                }
            }
        }
    }

    private func tierRow(_ tier: Tier) -> some View {
        let locked = tier == .adv && store.prefs.plan.isFree
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("\(Brand.modelName) \(tier.name)")
                        .font(.k(.body).weight(.medium))
                        .foregroundStyle(Palette.ink)
                    if locked {
                        Text("Planes de pago")
                            .font(.k(.caption).weight(.semibold))
                            .foregroundStyle(Palette.ink2)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Palette.sunk, in: Capsule())
                    }
                }
                Text(tier == .fast ? "Responde al instante, para el día a día" : "Piensa antes de responder, para lo difícil")
                    .font(.k(.subheadline))
                    .foregroundStyle(Palette.ink3)
            }
            Spacer(minLength: 8)
            if store.prefs.tier == tier {
                Image(systemName: "checkmark")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Palette.accent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
    }
}

private struct EffortPicker: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            SheetCard {
                ForEach(Array(Effort.allCases.enumerated()), id: \.element) { index, effort in
                    if index > 0 { SheetDivider(inset: 18) }
                    Button {
                        store.prefs.effort = effort
                    } label: {
                        SheetRow(title: effort.name, detail: detail(effort), checked: store.prefs.effort == effort)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Palette.bg)
        .navigationTitle("Esfuerzo")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detail(_ effort: Effort) -> String {
        switch effort {
        case .bajo: return "Más rápido, piensa lo justo"
        case .medio: return "El equilibrio para casi todo"
        case .alto: return "Piensa más a fondo · cuenta doble"
        }
    }
}

private struct ModePicker: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            SheetCard {
                ForEach(Array(ChatMode.allCases.enumerated()), id: \.element) { index, mode in
                    if index > 0 { SheetDivider() }
                    Button {
                        store.pick(mode: mode)
                        dismiss()
                    } label: {
                        SheetRow(icon: mode.icon, title: mode.name, checked: store.mode == mode)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(Palette.bg)
        .navigationTitle("Modo")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Add to the chat

/// What the + button opens: camera, photos and files first, recent photos, and the tools;
/// slide it up for everything else.
struct AddSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var photoItems: [PhotosPickerItem]
    var recording: Bool
    /// Runs after the sheet closes, so the camera or the file picker can open.
    var then: (AddAction) -> Void
    @State private var showRecent = false

    enum AddAction { case camera, photos, files, record, voice, browser, commands }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        tile("Cámara", icon: "camera", action: .camera)
                        tile("Fotos", icon: "photo.on.rectangle", action: .photos)
                        tile("Archivos", icon: "doc.badge.arrow.up", action: .files)
                    }

                    SheetCard {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showRecent.toggle() }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "photo.stack")
                                    .font(.system(size: 19))
                                    .frame(width: 26)
                                Text(showRecent ? "Ocultar fotos recientes" : "Mostrar fotos recientes")
                                    .font(.k(.body))
                                Spacer()
                            }
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 15)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if showRecent {
                            PhotosPicker(selection: $photoItems, maxSelectionCount: 5, selectionBehavior: .continuous,
                                         matching: .images) {
                                Text("Fotos")
                            }
                            .photosPickerStyle(.compact)
                            .photosPickerAccessoryVisibility(.hidden, edges: .all)
                            .frame(height: 96)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 12)
                        }
                    }
                    .padding(.top, 14)

                    SheetCard {
                        actionRow(recording ? "Detener la grabación" : "Grabar una nota de voz", icon: "mic", action: .record)
                        SheetDivider()
                        actionRow("Conversación en vivo", icon: "waveform", action: .voice)
                    }
                    .padding(.top, 14)

                    // Slide the sheet up to see these.
                    SheetCard {
                        Toggle(isOn: Binding(get: { store.searchWeb }, set: { store.searchWeb = $0; if $0 { store.research = false } })) {
                            Label { Text("Buscar en internet").font(.k(.body)) } icon: { Image(systemName: "globe") }
                        }
                        .tint(Palette.accent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        SheetDivider()
                        Toggle(isOn: Binding(get: { store.research }, set: { store.research = $0; if $0 { store.searchWeb = false } })) {
                            Label { Text("Investigación a fondo").font(.k(.body)) } icon: { Image(systemName: "books.vertical") }
                        }
                        .tint(Palette.accent)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        SheetDivider()
                        actionRow("Navegador", icon: "safari", action: .browser)
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.top, 14)

                    SheetCard {
                        Button {
                            store.creating = .image
                            dismiss()
                        } label: {
                            SheetRow(icon: "photo", title: "Crear imagen", value: "1 crédito")
                        }
                        .buttonStyle(.plain)
                        SheetDivider()
                        Button {
                            store.creating = .video
                            dismiss()
                        } label: {
                            SheetRow(icon: "video", title: "Crear video de 5 s", value: "5 créditos")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 14)

                    SheetCard {
                        Button {
                            dismiss()
                            store.showConnectors = true
                        } label: {
                            SheetRow(icon: "puzzlepiece.extension", title: "Conectores", chevron: true)
                        }
                        .buttonStyle(.plain)
                        SheetDivider()
                        actionRow("Comandos (escribe /)", icon: "command", action: .commands)
                    }
                    .padding(.top, 14)

                    Text("Te quedan \(store.creditsLeft) de \(store.usage.creditsCap) créditos este mes")
                        .font(.k(.footnote))
                        .foregroundStyle(Palette.ink3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, 10)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle("Añadir al chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetClose { dismiss() }
                }
            }
            .onChange(of: photoItems) { _, items in
                if !items.isEmpty && showRecent { dismiss() }
            }
        }
    }

    private func tile(_ title: String, icon: String, action: AddAction) -> some View {
        Button {
            run(action)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(title)
                    .font(.k(.subheadline).weight(.medium))
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 92)
            .background(Palette.sunk, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressScale())
    }

    private func actionRow(_ title: String, icon: String, action: AddAction) -> some View {
        Button {
            run(action)
        } label: {
            SheetRow(icon: icon, title: title)
        }
        .buttonStyle(.plain)
    }

    private func run(_ action: AddAction) {
        dismiss()
        then(action)
    }
}

// MARK: - Settings rows in the new design

/// A row of the settings home: outline icon, title and chevron, opening its page.
struct SettingsNavRow<Destination: View>: View {
    let title: String
    let icon: String
    var accent = false
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(accent ? AnyShapeStyle(Palette.accentGradient) : AnyShapeStyle(Palette.ink2))
                    .frame(width: 26)
                Text(title)
                    .font(.k(.body))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
