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
                                    .font(.headline)
                                    .foregroundStyle(Palette.ink)
                                if auth.session?.isAdmin == true {
                                    RoleBadge()
                                }
                            }
                            Text(auth.session?.email ?? "")
                                .font(.subheadline)
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
                    settingsLink("Privacidad", icon: "lock") { PrivacySettings() }
                }

                Section {
                    settingsLink("Plan y pagos", icon: "creditcard") { PlanSettings() }
                    settingsLink("Puntos de fundador", icon: "star") { PointsSettings() }
                    settingsLink("Telegram", icon: "paperplane") { TelegramSettings() }
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
                Text("Liminal las tiene en cuenta en todos tus chats. \(count) de \(customLimit) caracteres.")
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
                            .background(Palette.bubble, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                    .font(.footnote)
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

            Section("Motor") {
                Picker("Motor", selection: $store.state.prefs.engine) {
                    ForEach(store.enabledEngines) { engine in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(engine.name)
                            Text(engine.note)
                                .font(.footnote)
                                .foregroundStyle(Palette.ink3)
                        }
                        .tag(engine)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
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

            Section {
                Toggle("Usar memoria", isOn: $store.state.prefs.memory)
                    .tint(Palette.green)
                if store.state.prefs.memory {
                    if store.state.memories.isEmpty {
                        Text("Todavía no hay recuerdos.")
                            .foregroundStyle(Palette.ink3)
                    }
                    ForEach(store.state.memories) { memory in
                        Text(memory.text)
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink)
                    }
                    .onDelete { offsets in
                        store.state.memories.remove(atOffsets: offsets)
                        store.show("Recuerdo borrado")
                    }
                }
            } header: {
                Text("Memoria")
            } footer: {
                Text("Liminal recuerda estos datos para responderte mejor. Desliza a la izquierda para borrar uno.")
            }

            Section("Tus datos") {
                ShareLink(item: store.exportText(), subject: Text("Mis datos de Liminal")) {
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

    var body: some View {
        @Bindable var store = store
        let usage = store.state.usage
        Form {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plan \(store.state.prefs.plan.name.lowercased())")
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                        Text(price(for: store.state.prefs.plan))
                            .font(.subheadline)
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer()
                    StatusChip(text: "Activo", level: .good)
                }
                LabeledContent("Pagado hasta", value: Fmt.day(store.state.paidUntil))
            }

            Section("Tu uso") {
                UsageMeter(title: "Avanzado, ventana de 5 h", used: usage.adv, cap: usage.advCap,
                           detail: "Se recarga \(Fmt.relative(usage.resetAt))")
                UsageMeter(title: "Avanzado, esta semana", used: usage.week, cap: usage.weekCap,
                           detail: "Se recarga \(Fmt.relative(usage.weekResetAt))")
                UsageMeter(title: "Rápido, hoy", used: usage.fast, cap: usage.fastCap,
                           detail: "Se recarga a medianoche")
            }

            Section {
                Picker("Plan", selection: $store.state.prefs.plan) {
                    ForEach(PlanKind.allCases) { plan in
                        Text("\(plan.name) · \(price(for: plan))").tag(plan)
                    }
                }
                Picker("Red de pago", selection: $store.state.prefs.network) {
                    ForEach(Network.allCases) { network in
                        Text(network.name).tag(network)
                    }
                }
                Button {
                    store.show("La dirección de pago aparece aquí cuando conectemos el servidor.")
                } label: {
                    Label("Renovar con USDT o USDC", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(Palette.ink)
                }
            } header: {
                Text("Renovar")
            } footer: {
                Text("Sin tarjeta y sin datos bancarios. El plan se activa cuando la red confirma el pago.")
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
                            Text("\(Fmt.day(payment.date)) · \(payment.network.name)")
                                .font(.caption)
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
                        .font(.subheadline)
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
                        .font(.footnote)
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
                ShareLink(item: "Prueba Liminal, una IA en español a precio justo. Usa mi código \(store.state.referralCode).") {
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
                                .font(.caption)
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

// MARK: - Telegram

struct TelegramSettings: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let linked = store.state.telegramLinked
        Form {
            Section {
                HStack {
                    Text("Estado")
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    StatusChip(text: linked ? "Conectado" : "Sin conectar", level: linked ? .good : .warn)
                }
            } footer: {
                Text("Usa Liminal desde Telegram con el mismo plan y los mismos límites.")
            }

            Section {
                if linked {
                    Button {
                        store.state.telegramLinked = false
                        store.show("Telegram desconectado")
                    } label: {
                        Text("Desconectar Telegram")
                            .foregroundStyle(Palette.redText)
                    }
                } else {
                    Button {
                        store.state.telegramLinked = true
                        store.show("Telegram conectado")
                    } label: {
                        Label("Conectar con Telegram", systemImage: "paperplane")
                            .foregroundStyle(Palette.ink)
                    }
                }
            }

            Section("Cómo funciona") {
                step(1, "Toca Conectar y abre el bot de Liminal.")
                step(2, "Envía el código que te mostramos.")
                step(3, "Escríbele al bot como en la app.")
            }
        }
        .liminalList()
        .navigationTitle("Telegram")
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number).")
                .monospacedDigit()
                .foregroundStyle(Palette.ink3)
            Text(text)
                .foregroundStyle(Palette.ink)
        }
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
                auth.signOut()
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
