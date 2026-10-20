import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Avatar(name: displayName, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(displayName)
                                    .font(.k(.headline))
                                    .foregroundStyle(Palette.ink)
                                if auth.session?.isAdmin == true {
                                    RoleBadge()
                                }
                            }
                            Text(auth.session?.email ?? "")
                                .font(.k(.subheadline))
                                .foregroundStyle(Palette.ink3)
                            StatusChip(text: "Plan \(store.state.prefs.plan.name.lowercased()) activo", level: .good)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    settingsLink("General", icon: "gearshape") { GeneralSettings() }
                    settingsLink("Apariencia", icon: "circle.lefthalf.filled") { AppearanceSettings() }
                    settingsLink("Modelos y modos", icon: "cpu") { ModelSettings() }
                    settingsLink("Navegación", icon: "globe") { NavigationSettings() }
                    settingsLink("Voz e Isla Dinámica", icon: "waveform") { VoiceSettings() }
                    settingsLink("Memoria", icon: "brain") { MemorySettings() }
                    settingsLink("Conectores", icon: "puzzlepiece.extension") { ConnectorsSettings() }
                    settingsLink("Privacidad", icon: "lock") { PrivacySettings() }
                }

                Section {
                    settingsLink("Plan y pagos", icon: "creditcard") { PlanSettings() }
                    settingsLink("Puntos de fundador", icon: "star") { PointsSettings() }
                }

                Section {
                    settingsLink("Cuenta", icon: "person.crop.circle") { AccountSettings() }
                }
            }
            .liminalList()
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private var displayName: String {
        store.state.prefs.name.isEmpty ? (auth.session?.name ?? "Tú") : store.state.prefs.name
    }

    private func settingsLink<Destination: View>(_ title: String, icon: String,
                                                 @ViewBuilder destination: () -> Destination) -> some View {
        let page = destination()
        return NavigationLink {
            page
        } label: {
            Label(title, systemImage: icon)
                .foregroundStyle(Palette.ink)
        }
    }
}

// MARK: - General

struct GeneralSettings: View {
    @Environment(AppStore.self) private var store
    private let customLimit = 600

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Cómo te llamamos") {
                TextField("Tu nombre", text: $store.state.prefs.name)
                    .textContentType(.givenName)
            }
            Section("Idioma de las respuestas") {
                Picker("Idioma", selection: $store.state.prefs.language) {
                    Text("Español (Latinoamérica)").tag("es-419")
                    Text("Español (España)").tag("es-ES")
                    Text("Português (Brasil)").tag("pt-BR")
                    Text("English").tag("en")
                }
            }
            Section {
                Picker("Tono", selection: $store.state.prefs.tone) {
                    ForEach(Tone.allCases) { tone in
                        Text(tone.name).tag(tone)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Tono")
            } footer: {
                Text(toneNote)
            }
            Section {
                TextEditor(text: $store.state.prefs.custom)
                    .frame(minHeight: 130)
            } header: {
                Text("Instrucciones personalizadas")
            } footer: {
                let count = store.state.prefs.custom.count
                Text("Kuolki las tiene en cuenta en todos tus chats. \(count) de \(customLimit) caracteres.")
                    .foregroundStyle(count >= customLimit ? Palette.yellowText : Palette.ink3)
            }
        }
        .liminalList()
        .navigationTitle("General")
        .onChange(of: store.state.prefs.custom) { _, newValue in
            if newValue.count > customLimit {
                store.state.prefs.custom = String(newValue.prefix(customLimit))
            }
        }
    }

    private var toneNote: String {
        switch store.state.prefs.tone {
        case .cercano: return "Como un amigo que sabe del tema."
        case .profesional: return "Formal y ordenado, para trabajo y estudios."
        case .directo: return "Respuestas cortas, sin rodeos."
        }
    }
}

// MARK: - Voice and Dynamic Island

struct VoiceSettings: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Picker("Velocidad de la voz", selection: $store.voiceSpeed) {
                    ForEach(VoiceSpeed.allCases) { speed in
                        Text(speed.name).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Conversación en vivo")
            } footer: {
                Text("Con el chat vacío, toca el botón de ondas y habla. Cuando haces una pausa, Lithium responde en voz alta; tócalo para interrumpirlo. Cada respuesta cuenta como un mensaje de tu plan: escuchar y hablar no gastan nada más.")
            }

            Section {
                Toggle("Mostrar el avance de Lithium", isOn: $store.liveActivitiesOn)
                    .tint(Palette.green)
            } header: {
                Text("Isla Dinámica y pantalla bloqueada")
            } footer: {
                Text(liveFooter)
            }

            Section {
                Toggle("Avisarme cuando termine una respuesta", isOn: Binding(get: { store.state.prefs.notify ?? true }, set: { on in
                    store.state.prefs.notify = on
                    if on { Task { await Notifier.requestIfNeeded() } }
                }))
                .tint(Palette.green)
            } header: {
                Text("Con la app cerrada")
            } footer: {
                Text("Con el servidor nuevo, Lithium sigue escribiendo aunque cierres la app, y te avisa cuando termina o cuando necesita tu permiso para entrar a un sitio.")
            }

            Section("Privacidad de tu voz") {
                Label {
                    Text("Si tu iPhone lo permite, tu voz se convierte en texto dentro del teléfono y el audio no sale de él: lo verás con un candado durante la conversación. Si no, se usa el dictado del iPhone. Lithium solo recibe el texto.")
                        .font(.k(.footnote))
                        .foregroundStyle(Palette.ink2)
                } icon: {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Palette.ink3)
                }
            }
        }
        .liminalList()
        .navigationTitle("Voz e Isla Dinámica")
    }

    private var liveFooter: String {
        var text = "Ves cuándo está lista una imagen, un video o una respuesta larga, y pausas o terminas la conversación en vivo sin abrir la app. En iPhone con Isla Dinámica (14 Pro y más nuevos) aparece arriba; en los demás, en la pantalla bloqueada."
        if store.liveActivitiesOn && !LiveActivityController.shared.systemAllows {
            text += " Ahora están apagadas en Ajustes del iPhone › Kuolki › Actividades en vivo."
        }
        return text
    }
}

// MARK: - Appearance

struct AppearanceSettings: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Tema") {
                Picker("Tema", selection: $store.state.prefs.theme) {
                    ForEach(ThemeChoice.allCases) { theme in
                        Text(theme.name).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Tamaño del texto") {
                Picker("Tamaño", selection: $store.state.prefs.fontScale) {
                    ForEach(FontScale.allCases) { scale in
                        Text(scale.name).tag(scale)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Vista previa") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Spacer(minLength: 40)
                        Text("¿Me ayudas con un mensaje para mis clientes?")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Palette.bubble, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    Text("Claro. Cuéntame qué vendes y te propongo tres versiones.")
                }
                .foregroundStyle(Palette.ink)
                .padding(.vertical, 6)
            }
            Section {
                colorRow(.good, "Verde", "Activo, pagado y todo en orden.")
                colorRow(.warn, "Amarillo", "En curso, cerca de un límite y puntos.")
                colorRow(.bad, "Rojo", "Errores, detener y borrar.")
            } header: {
                Text("Colores de estado")
            } footer: {
                Text("La interfaz es gris claro u oscuro. Los colores del semáforo de macOS solo aparecen cuando dicen algo.")
            }
        }
        .liminalList()
        .navigationTitle("Apariencia")
    }

    private func colorRow(_ level: StatusLevel, _ name: String, _ meaning: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(level.color)
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .foregroundStyle(Palette.ink)
                Text(meaning)
                    .font(.k(.footnote))
                    .foregroundStyle(Palette.ink3)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Models and modes

struct ModelSettings: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Picker("Modelo", selection: $store.state.prefs.tier) {
                    ForEach(Tier.allCases) { tier in
                        Text(tier.name).tag(tier)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Modelo")
            } footer: {
                Text(store.state.prefs.tier == .adv
                     ? "Razona antes de responder. Usa tu ventana de 5 horas."
                     : "Responde al instante. Tiene su propio límite diario.")
            }

            if store.state.prefs.tier == .adv {
                Section {
                    Picker("Esfuerzo", selection: $store.state.prefs.effort) {
                        ForEach(Effort.allCases) { effort in
                            Text(effort.name).tag(effort)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Esfuerzo")
                } footer: {
                    Text(store.state.prefs.effort.note)
                        .foregroundStyle(store.state.prefs.effort == .alto ? Palette.yellowText : Palette.ink3)
                }
            }

            Section {
                LabeledContent("Modelo", value: Brand.modelName)
            } footer: {
                Text("\(Brand.modelName) combina varios motores abiertos y elige el mejor para cada mensaje. Si uno se satura, pasa al siguiente sin que lo notes.")
            }

            Section {
                Picker("Modo al empezar", selection: $store.state.prefs.defaultMode) {
                    ForEach(ChatMode.allCases) { mode in
                        Label(mode.name, systemImage: mode.icon).tag(mode)
                    }
                }
                Toggle("Mostrar el razonamiento", isOn: $store.state.prefs.showThinking)
                    .tint(Palette.green)
            } header: {
                Text("Modos")
            } footer: {
                Text("Los modos ajustan el tono y el formato: ventas, estudio, empleo o el día a día.")
            }
        }
        .liminalList()
        .navigationTitle("Modelos y modos")
    }
}

// MARK: - Privacy

struct PrivacySettings: View {
    @Environment(AppStore.self) private var store
    @State private var confirmDeleteAll = false

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Toggle("Guardar el historial de chats", isOn: $store.state.prefs.saveHistory)
                    .tint(Palette.green)
                Toggle("Empezar siempre en chat temporal", isOn: $store.state.prefs.tempDefault)
                    .tint(Palette.green)
            } header: {
                Text("Historial")
            } footer: {
                Text("Los chats temporales no se guardan y desaparecen al salir de ellos.")
            }

            Section("Memoria") {
                NavigationLink {
                    MemorySettings()
                } label: {
                    LabeledContent("Memoria", value: store.state.prefs.memory
                                   ? "Activa · \(store.state.memories.count) datos" : "Apagada")
                }
            }

            Section("Dónde se procesan tus mensajes") {
                Text("\(Brand.modelName) funciona en servidores de proveedores contratados por Kuolki.")
                    .font(.k(.footnote))
                    .foregroundStyle(Palette.ink2)
            }

            Section("Tus datos") {
                ShareLink(item: store.exportText(), subject: Text("Mis datos de Kuolki")) {
                    Label("Exportar mis datos", systemImage: "square.and.arrow.up")
                        .foregroundStyle(Palette.ink)
                }
                Button {
                    confirmDeleteAll = true
                } label: {
                    Label("Borrar todos los chats", systemImage: "trash")
                        .foregroundStyle(Palette.redText)
                }
            }

            Section("Nuestro compromiso") {
                promise("Sin anuncios y sin vender tus datos.")
                promise("No entrenamos modelos con tus chats.")
                promise("Pagas con USDT o USDC, sin tarjeta.")
            }
        }
        .liminalList()
        .navigationTitle("Privacidad")
        .confirmationDialog("¿Borrar todos tus chats?", isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button("Borrar todo", role: .destructive) { store.deleteAllChats() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se borran de este dispositivo y de tu cuenta. No se puede deshacer.")
        }
    }

    private func promise(_ text: String) -> some View {
        Label {
            Text(text)
                .foregroundStyle(Palette.ink)
        } icon: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.green)
        }
    }
}

// MARK: - Plan and payments

struct PlanSettings: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthService.self) private var auth
    @State private var showPayment = false

    var body: some View {
        @Bindable var store = store
        let usage = store.state.usage
        Form {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plan \(store.state.prefs.plan.name.lowercased())")
                            .font(.k(.headline))
                            .foregroundStyle(Palette.ink)
                        Text(price(for: store.state.prefs.plan))
                            .font(.k(.subheadline))
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer()
                    StatusChip(text: "Activo", level: .good)
                }
                LabeledContent("Pagado hasta", value: Fmt.day(store.state.paidUntil))
            }

            Section("Tu uso") {
                PercentMeter(title: "Sesión actual · 5 horas", percent: store.sessionPercent,
                             detail: (usage.sessionUSD ?? 0) > 0 ? "Se recarga \(Fmt.relative(usage.sessionResetAt ?? Date()))" : "Empieza con tu primer mensaje")
                PercentMeter(title: "Esta semana", percent: store.weekPercent,
                             detail: "Se recarga \(Fmt.relative(usage.weekResetAt)) · \(Fmt.tokens(usage.weekTokens ?? 0)) tokens")
                Text("Una sola medida para todo tu plan: el chat y Kuolki Dev comparten la sesión y la semana. Se mide en tokens; el modo rápido gasta varias veces menos porque no se pone a pensar, y sigue disponible aunque se acabe la sesión.")
                    .font(.k(.caption)).foregroundStyle(Palette.ink3)
                UsageMeter(title: "Créditos para imágenes y video", used: usage.credits, cap: usage.creditsCap,
                           detail: "Imagen: 1 crédito · Video de 5 s: 5 créditos · Se renuevan el \(Fmt.day(usage.creditsResetAt))")
                Button {
                    store.show("Demostración: aquí pagarías \(Fmt.money(ExtraPack.price)) en USDT o USDC y se sumarían \(ExtraPack.credits) créditos.")
                } label: {
                    LabeledContent("Paquete de \(ExtraPack.credits) créditos", value: Fmt.money(ExtraPack.price))
                        .foregroundStyle(Palette.ink)
                }
            }

            Section {
                Picker("Plan", selection: $store.state.prefs.plan) {
                    ForEach(PlanKind.allCases) { plan in
                        Text("\(plan.name) · \(price(for: plan))").tag(plan)
                    }
                }
                Button {
                    showPayment = true
                } label: {
                    Label("Pagar \(Fmt.money(store.planPrice))", systemImage: "creditcard")
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.ink)
                }
            } header: {
                Text("Pagar")
            } footer: {
                Text(store.paymentRegion == "VE"
                     ? "Pago Móvil en bolívares a la tasa oficial del \(store.state.pay.useEuroRate ? "euro" : "dólar") (\(Fmt.bolivares(store.amountInBolivares)) hoy), USDT, USDC o tarjeta."
                     : "Tarjeta de débito o crédito, USDT o USDC.")
            }

            Section("Historial de pagos") {
                if myPayments.isEmpty {
                    Text("Todavía no hay pagos.")
                        .foregroundStyle(Palette.ink3)
                }
                ForEach(myPayments) { payment in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(payment.amount)
                                .foregroundStyle(Palette.ink)
                            Text("\(Fmt.day(payment.date)) · \(payment.method)")
                                .font(.k(.caption))
                                .foregroundStyle(Palette.ink3)
                        }
                        Spacer()
                        StatusChip(text: payment.status.label, level: payment.status.level)
                    }
                }
            }
        }
        .liminalList()
        .navigationTitle("Plan y pagos")
        .sheet(isPresented: $showPayment) {
            PaymentSheet()
        }
    }

    private var myPayments: [Payment] {
        let email = auth.session?.email ?? ""
        return store.state.payments.filter { $0.email == email }.sorted { $0.date > $1.date }
    }

    private func price(for plan: PlanKind) -> String {
        switch plan {
        case .mensual: return "\(Fmt.money(store.state.admin.priceMonthly)) al mes"
        case .semanal: return "\(Fmt.money(store.state.admin.priceWeekly)) a la semana"
        }
    }
}

// MARK: - Founder points

struct PointsSettings: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tus puntos")
                        .font(.k(.subheadline))
                        .foregroundStyle(Palette.ink3)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Palette.yellow)
                        Text(Fmt.int(store.state.points))
                            .font(.system(size: 40, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                    }
                    Text("Ganas 300 puntos por cada mes activo y 250 por cada amigo que se suscriba con tu código. Los puntos no son dinero ni una inversión.")
                        .font(.k(.footnote))
                        .foregroundStyle(Palette.ink3)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            Section("Tu código para invitar") {
                HStack {
                    Text(store.state.referralCode)
                        .font(.body.monospaced())
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Button("Copiar") {
                        UIPasteboard.general.string = store.state.referralCode
                        store.show("Código copiado")
                    }
                    .buttonStyle(.borderless)
                }
                ShareLink(item: "Prueba Kuolki, una IA en español a precio justo. Usa mi código \(store.state.referralCode).") {
                    Label("Compartir invitación", systemImage: "square.and.arrow.up")
                        .foregroundStyle(Palette.ink)
                }
            }

            Section("Historial") {
                ForEach(store.state.pointsHistory) { entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.reason)
                                .foregroundStyle(Palette.ink)
                            Text(entry.month)
                                .font(.k(.caption))
                                .foregroundStyle(Palette.ink3)
                        }
                        Spacer()
                        Text("+\(Fmt.int(entry.points))")
                            .monospacedDigit()
                            .foregroundStyle(Palette.yellowText)
                    }
                }
            }
        }
        .liminalList()
        .navigationTitle("Puntos de fundador")
    }
}

// MARK: - Account

struct AccountSettings: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthService.self) private var auth
    @State private var confirmSignOut = false
    @State private var confirmReset = false

    var body: some View {
        Form {
            if let session = auth.session {
                Section {
                    LabeledContent("Correo", value: session.email)
                    LabeledContent("Rol") {
                        if session.isAdmin {
                            RoleBadge()
                        } else {
                            Text("Usuario")
                        }
                    }
                    LabeledContent("Sesión activa hasta", value: Fmt.dayTime(session.expires))
                }
            }

            DevicesSection()

            Section {
                Button {
                    confirmSignOut = true
                } label: {
                    Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Palette.redText)
                }
            }

            if auth.session?.isAdmin == true {
                Section {
                    Button {
                        confirmReset = true
                    } label: {
                        Label("Restablecer datos de ejemplo", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(Palette.ink)
                    }
                } footer: {
                    Text("Vuelve a cargar los chats, proyectos y usuarios de ejemplo. Borra lo que hayas creado.")
                }
            }

            Section {
                NoticeView(level: .warn, text: "Este inicio de sesión es de prueba y funciona solo en este dispositivo. Antes del lanzamiento, el acceso pasa a un servidor propio.")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .liminalList()
        .navigationTitle("Cuenta")
        .confirmationDialog("¿Cerrar sesión?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                store.stop()
                store.saveNow()
                Task {
                    await store.forgetDevice()
                    auth.signOut()
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
        .confirmationDialog("¿Restablecer los datos de ejemplo?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Restablecer", role: .destructive) { store.resetDemo() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("No se puede deshacer.")
        }
    }
}

// MARK: - Memory

struct MemorySettings: View {
    @Environment(AppStore.self) private var store
    @State private var newText = ""
    @State private var newCategory: MemoryCategory = .perfil
    @State private var editingID: UUID? = nil
    @State private var editText = ""
    @State private var showEdit = false
    @State private var confirmForget = false

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Toggle("Usar memoria", isOn: $store.state.prefs.memory)
                    .tint(Palette.green)
            } footer: {
                Text("Lithium recuerda lo importante entre chats: tu nombre, tu negocio y cómo te gusta que responda. También puedes decirle «recuerda que…».")
            }

            Section("Agregar un recuerdo") {
                TextField("Por ejemplo: mi tienda se llama Cami", text: $newText, axis: .vertical)
                    .lineLimit(1...3)
                Picker("Tipo", selection: $newCategory) {
                    ForEach(MemoryCategory.allCases) { category in
                        Text(category.name).tag(category)
                    }
                }
                Button("Agregar") {
                    store.addMemory(newText, category: newCategory)
                    newText = ""
                }
                .disabled(newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ForEach(MemoryCategory.allCases) { category in
                Section(category.name) {
                    let items = store.state.memories.filter { $0.category == category }
                    if items.isEmpty {
                        Text("Nada todavía.")
                            .foregroundStyle(Palette.ink3)
                    }
                    ForEach(items) { memory in
                        Button {
                            editingID = memory.id
                            editText = memory.text
                            showEdit = true
                        } label: {
                            Text(memory.text)
                                .foregroundStyle(Palette.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                store.deleteMemory(memory.id)
                            } label: {
                                Label("Olvidar", systemImage: "trash")
                            }
                            .tint(Palette.red)
                        }
                    }
                }
            }

            Section {
                Button {
                    confirmForget = true
                } label: {
                    Text("Olvidar todo")
                        .foregroundStyle(Palette.redText)
                }
                .disabled(store.state.memories.isEmpty)
            } footer: {
                Text("Toca un recuerdo para editarlo o deslízalo para olvidarlo.")
            }
        }
        .liminalList()
        .navigationTitle("Memoria")
        .alert("Editar recuerdo", isPresented: $showEdit) {
            TextField("Recuerdo", text: $editText)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                if let editingID { store.updateMemory(editingID, text: editText) }
            }
        }
        .confirmationDialog("¿Olvidar todo?", isPresented: $confirmForget, titleVisibility: .visible) {
            Button("Olvidar todo", role: .destructive) { store.forgetAll() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Lithium borra todos sus recuerdos sobre ti. Tus chats no se tocan.")
        }
    }
}

// MARK: - Connectors

struct ConnectorsSettings: View {
    @Environment(AppStore.self) private var store
    @State private var name = ""
    @State private var url = ""

    var body: some View {
        Form {
            Section {
                ForEach(ConnectorKind.allCases) { kind in
                    HStack(spacing: 12) {
                        Image(systemName: kind.icon)
                            .foregroundStyle(Palette.ink2)
                            .frame(width: 34, height: 34)
                            .background(Palette.sunk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.name)
                                .foregroundStyle(Palette.ink)
                            Text(kind.note)
                                .font(.k(.caption))
                                .foregroundStyle(Palette.ink3)
                        }
                        Spacer(minLength: 8)
                        Button(store.state.connectors.contains(kind) ? "Desconectar" : "Conectar") {
                            store.toggleConnector(kind)
                        }
                        .buttonStyle(.bordered)
                        .font(.k(.footnote))
                    }
                }
            } footer: {
                Text("Los conectores usan MCP, el estándar abierto para que la IA trabaje con tus apps. Con el servidor conectado, al tocar Conectar se abre la autorización de cada servicio.")
            }

            Section {
                ForEach(store.state.customConnectors) { connector in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(connector.name)
                            .foregroundStyle(Palette.ink)
                        Text(connector.url)
                            .font(.k(.caption))
                            .foregroundStyle(Palette.ink3)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            store.removeCustomConnector(connector.id)
                        } label: {
                            Label("Quitar", systemImage: "trash")
                        }
                        .tint(Palette.red)
                    }
                }
                TextField("Nombre, por ejemplo: Mi inventario", text: $name)
                TextField("https://tu-servidor.com/mcp", text: $url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Agregar servidor") {
                    if let problem = store.addCustomConnector(name: name, url: url) {
                        store.show(problem)
                    } else {
                        name = ""
                        url = ""
                    }
                }
            } header: {
                Text("Servidor MCP personalizado")
            } footer: {
                Text("Para conectar Lithium con tu inventario, tu tienda o cualquier sistema propio.")
            }
        }
        .liminalList()
        .navigationTitle("Conectores")
    }
}

// MARK: - Payment

struct PaymentSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var method: PayMethod = .pagoMovil
    @State private var region = "VE"
    @State private var network: Network = .tron
    @State private var reference = ""
    @State private var bank = "Banco de Venezuela"
    @State private var hash = ""

    private let banks = ["Banco de Venezuela", "Banesco", "Mercantil", "BBVA Provincial", "BNC", "Bancamiga",
                         "Banco del Tesoro", "Bicentenario", "Banplus", "Otro"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("País o región", selection: $region) {
                        ForEach(Region.all) { country in
                            Text(country.name).tag(country.code)
                        }
                    }
                    Picker("Método", selection: $method) {
                        ForEach(Region.methods(for: region)) { method in
                            Text(method.name).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(store.state.prefs.region == nil ? "Lo elegimos por tu zona horaria. Cámbialo si no es tu país." : "Los métodos de pago cambian según el país.")
                }
                switch method {
                case .pagoMovil: pagoMovil
                case .usdt, .usdc: crypto
                case .card: card
                }
            }
            .liminalList()
            .navigationTitle("Pagar tu plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .onChange(of: method) { _, newMethod in
                if let first = newMethod.networks.first { network = first }
            }
            .onAppear {
                region = store.paymentRegion
                method = Region.methods(for: region)[0]
            }
            .onChange(of: region) { _, newRegion in
                if newRegion != store.paymentRegion { store.state.prefs.region = newRegion }
                let allowed = Region.methods(for: newRegion)
                if !allowed.contains(method) { method = allowed[0] }
            }
        }
    }

    @ViewBuilder
    private var pagoMovil: some View {
        let pay = store.state.pay
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Monto a pagar")
                    .font(.k(.caption))
                    .foregroundStyle(Palette.ink3)
                Text(Fmt.bolivares(store.amountInBolivares))
                    .font(.k(.title2).weight(.semibold))
                    .monospacedDigit()
                Text("\(Fmt.money(store.planPrice)) × \(Fmt.bolivares(pay.rate)) · tasa oficial del \(pay.useEuroRate ? "euro" : "dólar") (BCV) del \(Fmt.day(pay.rateDate))")
                    .font(.k(.caption))
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.vertical, 4)
        }
        Section("Datos para el Pago Móvil") {
            copyRow("Banco", pay.mobileBank, copy: false)
            copyRow("Teléfono", pay.mobilePhone)
            copyRow("RIF o cédula", pay.mobileID)
            copyRow("Monto exacto", Fmt.decimal2(store.amountInBolivares))
        }
        Section {
            TextField("Número de referencia", text: $reference)
                .keyboardType(.numberPad)
            Picker("Banco desde el que pagaste", selection: $bank) {
                ForEach(banks, id: \.self) { bank in
                    Text(bank).tag(bank)
                }
            }
            Button("Enviar comprobante") {
                if store.submitPagoMovil(reference: reference, bank: bank) { dismiss() }
            }
            .fontWeight(.semibold)
        } footer: {
            Text("Lo verificamos en minutos y activamos tu plan.")
        }
    }

    @ViewBuilder
    private var crypto: some View {
        let coin = method.name
        let address = store.state.pay.wallet(for: network)
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Monto exacto")
                    .font(.k(.caption))
                    .foregroundStyle(Palette.ink3)
                Text("\(Fmt.decimal2(store.planPrice)) \(coin)")
                    .font(.k(.title2).weight(.semibold))
                    .monospacedDigit()
            }
            .padding(.vertical, 4)
            Picker("Red", selection: $network) {
                ForEach(method.networks) { network in
                    Text(network.name).tag(network)
                }
            }
            .pickerStyle(.segmented)
        }
        Section {
            copyRow("Dirección \(coin) en \(network.name)", address.isEmpty ? "Configúrala en Administración › Planes" : address,
                    copy: !address.isEmpty)
            NoticeView(level: .warn, text: "Envía solo \(coin) por la red \(network.name). Si usas otra red o moneda, el pago se pierde.")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
        Section {
            TextField("Código de la transacción (opcional)", text: $hash)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Ya envié el pago") {
                store.submitCrypto(coin: coin, network: network, hash: hash)
                dismiss()
            }
            .fontWeight(.semibold)
        }
    }

    @ViewBuilder
    private var card: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total")
                    .font(.k(.caption))
                    .foregroundStyle(Palette.ink3)
                Text(Fmt.money(store.planPrice))
                    .font(.k(.title2).weight(.semibold))
                Text("Débito o crédito, nacional o internacional")
                    .font(.k(.caption))
                    .foregroundStyle(Palette.ink3)
            }
            .padding(.vertical, 4)
        }
        Section {
            Button {
                store.show("Demostración: aquí se abre la página segura del procesador de pagos.")
            } label: {
                Label("Pagar \(Fmt.money(store.planPrice)) con tarjeta", systemImage: "creditcard")
                    .fontWeight(.semibold)
            }
        } footer: {
            Text("Te llevamos a la página segura del procesador de pagos. Kuolki nunca ve ni guarda los datos de tu tarjeta.")
        }
    }

    private func copyRow(_ title: String, _ value: String, copy: Bool = true) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.k(.caption))
                    .foregroundStyle(Palette.ink3)
                Text(value)
                    .foregroundStyle(Palette.ink)
                    .monospacedDigit()
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            if copy {
                Button("Copiar") {
                    UIPasteboard.general.string = value
                    store.show("Copiado")
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
