import SwiftUI
import StoreKit
import UIKit

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    SheetCard {
                        HStack(spacing: 14) {
                            Avatar(name: displayName, size: 54)
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
                                    .lineLimit(1)
                                StatusChip(text: "Plan \(store.prefs.plan.name.lowercased()) activo", level: .good)
                                    .padding(.top, 4)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(18)
                    }

                    SheetCard {
                        SettingsNavRow(title: "General", icon: "gearshape") { GeneralSettings() }
                        SheetDivider()
                        SettingsNavRow(title: "Apariencia", icon: "circle.lefthalf.filled") { AppearanceSettings() }
                        SheetDivider()
                        SettingsNavRow(title: "Modelos y modos", icon: "cpu") { ModelSettings() }
                        SheetDivider()
                        SettingsNavRow(title: "Navegación", icon: "globe") { NavigationSettings() }
                        SheetDivider()
                        SettingsNavRow(title: "Voz e Isla Dinámica", icon: "waveform") { VoiceSettings() }
                        SheetDivider()
                        SettingsNavRow(title: "Memoria", icon: "brain") { MemorySettings() }
                        SheetDivider()
                        SettingsNavRow(title: "Conectores", icon: "puzzlepiece.extension") { ConnectorsSettings() }
                        SheetDivider()
                        SettingsNavRow(title: "Privacidad", icon: "lock") { PrivacySettings() }
                    }

                    SheetCard {
                        SettingsNavRow(title: "Plan y pagos", icon: "creditcard", accent: true) { PlanSettings() }
                        SheetDivider()
                        SettingsNavRow(title: "Puntos de fundador", icon: "star", accent: true) { PointsSettings() }
                    }

                    SheetCard {
                        SettingsNavRow(title: "Cuenta", icon: "person.crop.circle") { AccountSettings() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .background(Palette.bg)
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SheetClose { dismiss() }
                }
            }
        }
    }

    private var displayName: String {
        store.prefs.name.isEmpty ? (auth.session?.name ?? "Tú") : store.prefs.name
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
                TextField("Tu nombre", text: $store.prefs.name)
                    .textContentType(.givenName)
            }
            Section("Idioma de las respuestas") {
                Picker("Idioma", selection: $store.prefs.language) {
                    Text("Español (Latinoamérica)").tag("es-419")
                    Text("Español (España)").tag("es-ES")
                    Text("Português (Brasil)").tag("pt-BR")
                    Text("English").tag("en")
                }
            }
            Section {
                Picker("Tono", selection: $store.prefs.tone) {
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
                TextEditor(text: $store.prefs.custom)
                    .frame(minHeight: 130)
            } header: {
                Text("Instrucciones personalizadas")
            } footer: {
                let count = store.prefs.custom.count
                Text("Kuolki las tiene en cuenta en todos tus chats. \(count) de \(customLimit) caracteres.")
                    .foregroundStyle(count >= customLimit ? Palette.yellowText : Palette.ink3)
            }
        }
        .liminalList()
        .navigationTitle("General")
        .onChange(of: store.prefs.custom) { _, newValue in
            if newValue.count > customLimit {
                store.prefs.custom = String(newValue.prefix(customLimit))
            }
        }
    }

    private var toneNote: String {
        switch store.prefs.tone {
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
                Toggle("Avisarme cuando termine una respuesta", isOn: Binding(get: { store.prefs.notify ?? true }, set: { on in
                    store.prefs.notify = on
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
        let prefs = store.prefs
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header("Tema")
                SheetCard {
                    segmented(ThemeChoice.allCases, selected: prefs.theme, name: \.name) { store.prefs.theme = $0 }
                        .padding(8)
                }

                header("Letra")
                SheetCard {
                    ForEach(Array(FontFamily.allCases.enumerated()), id: \.element) { index, family in
                        if index > 0 { SheetDivider(inset: 18) }
                        Button {
                            choose(family)
                        } label: {
                            HStack(spacing: 14) {
                                Text("Aa")
                                    .font(sample(family, size: 24))
                                    .foregroundStyle(Palette.ink)
                                    .frame(width: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(family.name)
                                        .font(sample(family, size: 17))
                                        .foregroundStyle(Palette.ink)
                                    Text(family.detail)
                                        .font(.k(.subheadline))
                                        .foregroundStyle(Palette.ink3)
                                }
                                Spacer(minLength: 8)
                                if (prefs.fontFamily ?? .kuolki) == family {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(Palette.accent)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                header("Tamaño del texto")
                SheetCard {
                    segmented(FontScale.allCases, selected: prefs.fontScale, name: \.name) { store.prefs.fontScale = $0 }
                        .padding(8)
                }

                header("Vista previa")
                SheetCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Spacer(minLength: 40)
                            Text("¿Me ayudas con un mensaje para mis clientes?")
                                .font(.k(.body))
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Palette.bubble, in: UnevenRoundedRectangle(topLeadingRadius: 22, bottomLeadingRadius: 22,
                                                                                         bottomTrailingRadius: 8, topTrailingRadius: 22,
                                                                                         style: .continuous))
                        }
                        HStack(spacing: 6) {
                            LogoMark().fill(Palette.ink).frame(width: 15, height: 15)
                            Text(Brand.modelName)
                                .font(.k(.subheadline).weight(.semibold))
                                .foregroundStyle(Palette.ink)
                        }
                        Text("Claro. Cuéntame qué vendes y te propongo tres versiones: una corta para WhatsApp, una para Instagram y una más formal.")
                            .font(.k(.body))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                }
                Text("Así se ven tus chats con el tema, la letra y el tamaño que elegiste.")
                    .font(.k(.footnote))
                    .foregroundStyle(Palette.ink3)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Palette.bg)
        .navigationTitle("Apariencia")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: prefs.fontScale)
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.k(.subheadline).weight(.medium))
            .foregroundStyle(Palette.ink3)
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 8)
    }

    /// Three choices side by side; the chosen one stands out.
    private func segmented<T: Hashable>(_ options: [T], selected: T, name: KeyPath<T, String>,
                                        pick: @escaping (T) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    pick(option)
                } label: {
                    Text(option[keyPath: name])
                        .font(.k(.subheadline).weight(option == selected ? .semibold : .regular))
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background {
                            if option == selected {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Palette.raised)
                                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(option == selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Palette.sunk, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    /// Each typeface written in itself.
    private func sample(_ family: FontFamily, size: CGFloat) -> Font {
        switch family {
        case .kuolki: return .custom(KFont.text, size: size).weight(.semibold)
        case .sistema: return .system(size: size, weight: .semibold)
        case .clasica: return .system(size: size, weight: .semibold, design: .serif)
        }
    }

    /// The typeface changes before anything redraws, so the whole app switches at once.
    private func choose(_ family: FontFamily) {
        KFont.family = family
        KFont.applyToBars()
        store.prefs.fontFamily = family
    }
}

// MARK: - Models and modes

struct ModelSettings: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Picker("Modelo", selection: $store.prefs.tier) {
                    ForEach(Tier.allCases) { tier in
                        Text(tier.name).tag(tier)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Modelo")
            } footer: {
                Text(store.prefs.tier == .adv
                     ? "Razona antes de responder. Usa tu ventana de 5 horas."
                     : "Responde al instante. Tiene su propio límite diario.")
            }

            if store.prefs.tier == .adv {
                Section {
                    Picker("Esfuerzo", selection: $store.prefs.effort) {
                        ForEach(Effort.allCases) { effort in
                            Text(effort.name).tag(effort)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Esfuerzo")
                } footer: {
                    Text(store.prefs.effort.note)
                        .foregroundStyle(store.prefs.effort == .alto ? Palette.yellowText : Palette.ink3)
                }
            }

            Section {
                LabeledContent("Modelo", value: Brand.modelName)
            } footer: {
                Text("\(Brand.modelName) combina varios motores abiertos y elige el mejor para cada mensaje. Si uno se satura, pasa al siguiente sin que lo notes.")
            }

            Section {
                Picker("Modo al empezar", selection: $store.prefs.defaultMode) {
                    ForEach(ChatMode.allCases) { mode in
                        Label(mode.name, systemImage: mode.icon).tag(mode)
                    }
                }
                Toggle("Mostrar el razonamiento", isOn: $store.prefs.showThinking)
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
                Toggle("Guardar el historial de chats", isOn: $store.prefs.saveHistory)
                    .tint(Palette.green)
                Toggle("Empezar siempre en chat temporal", isOn: $store.prefs.tempDefault)
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
                    LabeledContent("Memoria", value: store.prefs.memory
                                   ? "Activa · \(store.memories.count) datos" : "Apagada")
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
                promise("Pagas con Apple o en la web con Pago Móvil, USDT, USDC o tarjeta.")
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
    @State private var showCheckout = false

    var body: some View {
        @Bindable var store = store
        let usage = store.usage
        let plan = store.prefs.plan
        Form {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plan \(store.planLabel.lowercased())")
                            .font(.k(.headline))
                            .foregroundStyle(Palette.ink)
                        Text(plan.isFree ? "Modo rápido con un límite por sesión y por semana" : priceLine(plan, annual: store.isAnnual))
                            .font(.k(.subheadline))
                            .foregroundStyle(Palette.ink3)
                    }
                    Spacer()
                    StatusChip(text: "Activo", level: .good)
                }
                if !plan.isFree {
                    LabeledContent("Pagado hasta", value: Fmt.day(store.paidUntil))
                }
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
            }

            Section {
                Picker("Cómo pagar", selection: Binding(get: { store.prefs.annual ?? false },
                                                        set: { store.prefs.annual = $0 })) {
                    Text("Mensual").tag(false)
                    Text("Anual").tag(true)
                }
                .pickerStyle(.segmented)
                ForEach(PlanKind.allCases) { option in
                    Button {
                        store.prefs.plan = option
                    } label: {
                        PlanChoiceRow(plan: option, annual: store.prefs.annual ?? false,
                                      admin: store.admin, selected: option == plan)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Cambiar o renovar")
            } footer: {
                Text("Precios con IVA incluido. Pagando el año te ahorras hasta 2 meses. \(plan.research).")
            }

            if !plan.isFree {
                Section {
                    Button {
                        showCheckout = true
                    } label: {
                        Label("Pagar \(Fmt.money(store.planPrice))", systemImage: "creditcard")
                            .fontWeight(.semibold)
                            .foregroundStyle(Palette.ink)
                    }
                } footer: {
                    Text(store.showsWebPay ? "Con tu cuenta de Apple, o en la web con Pago Móvil, USDT, USDC o tarjeta." : "Con tu cuenta de Apple.")
                }
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
                            Text("\(Fmt.day(payment.date)) · \(payment.plan.name)\(payment.annual == true ? " anual" : "") · \(payment.method)")
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
        .sheet(isPresented: $showCheckout) {
            CheckoutSheet()
        }
    }

    private var myPayments: [Payment] {
        let email = auth.session?.email ?? ""
        return store.payments.filter { $0.email == email }.sorted { $0.date > $1.date }
    }

    private func priceLine(_ plan: PlanKind, annual: Bool) -> String {
        let total = plan.price(annual: annual, admin: store.admin)
        return annual && plan.hasAnnual ? "\(Fmt.money(total)) al año" : "\(Fmt.money(total)) \(plan.unit)"
    }
}

/// One plan to pick: name, price and what it is for.
struct PlanChoiceRow: View {
    let plan: PlanKind
    let annual: Bool
    let admin: AdminConfig
    let selected: Bool

    var body: some View {
        let yearly = annual && plan.hasAnnual
        let total = plan.price(annual: yearly, admin: admin)
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.name)
                    .font(.k(.body).weight(.semibold))
                    .foregroundStyle(Palette.ink)
                Text(detail(yearly: yearly, total: total))
                    .font(.k(.caption))
                    .foregroundStyle(Palette.ink3)
            }
            Spacer(minLength: 8)
            Text(Fmt.money(yearly ? total / 12 : total))
                .font(.k(.title3).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                .font(.k(.title3))
                .foregroundStyle(selected ? Palette.ink : Palette.ink3)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func detail(yearly: Bool, total: Double) -> String {
        switch plan {
        case .gratis: return "Solo modo rápido"
        case .semanal: return annual ? "Solo se paga por semana" : "Por semana"
        default: return yearly ? "Al mes · \(Fmt.money(total)) al año" : "Al mes"
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
                        Text(Fmt.int(store.points))
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
                    Text(store.referralCode)
                        .font(.body.monospaced())
                        .foregroundStyle(Palette.ink)
                    Spacer()
                    Button("Copiar") {
                        UIPasteboard.general.string = store.referralCode
                        store.show("Código copiado")
                    }
                    .buttonStyle(.borderless)
                }
                ShareLink(item: "Prueba Kuolki, una IA en español a precio justo. Usa mi código \(store.referralCode).") {
                    Label("Compartir invitación", systemImage: "square.and.arrow.up")
                        .foregroundStyle(Palette.ink)
                }
            }

            Section("Historial") {
                ForEach(store.pointsHistory) { entry in
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
                Toggle("Usar memoria", isOn: $store.prefs.memory)
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
                    let items = store.memories.filter { $0.category == category }
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
                .disabled(store.memories.isEmpty)
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
                        Button(store.connectors.contains(kind) ? "Desconectar" : "Conectar") {
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
                ForEach(store.customConnectors) { connector in
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

// MARK: - Choose how to pay

/// Pay the chosen plan with Apple (App Store subscription) or on the web
/// (Pago Móvil, USDT, USDC or card), which opens in Safari with this account.
struct CheckoutSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(Purchases.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.purchase) private var purchase

    var body: some View {
        let plan = store.prefs.plan
        let annual = store.isAnnual
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Plan \(store.planLabel.lowercased())")
                            .font(.k(.headline))
                            .foregroundStyle(Palette.ink)
                        Text("\(Fmt.money(store.planPrice)) \(annual ? "al año" : plan.unit) · IVA incluido")
                            .font(.k(.subheadline))
                            .foregroundStyle(Palette.ink3)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        Task { await payWithApple(plan, annual: annual) }
                    } label: {
                        HStack {
                            Label("Pagar con Apple", systemImage: "bag")
                                .fontWeight(.semibold)
                                .foregroundStyle(Palette.ink)
                            Spacer()
                            if purchases.busy {
                                ProgressView()
                            } else if let price = purchases.displayPrice(plan, annual: annual) {
                                Text(price)
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.ink3)
                            }
                        }
                    }
                    .disabled(purchases.busy)
                } footer: {
                    Text("Se cobra a tu cuenta de Apple y se renueva sola. La cancelas cuando quieras en Ajustes del iPhone › tu nombre › Suscripciones.")
                }

                if store.showsWebPay {
                    Section {
                        Button {
                            if let url = store.webPayURL(plan: plan, annual: annual) {
                                openURL(url)
                                dismiss()
                            } else {
                                store.show("Falta la dirección de la app web en Administración.")
                            }
                        } label: {
                            HStack {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Pagar en la web")
                                            .fontWeight(.semibold)
                                            .foregroundStyle(Palette.ink)
                                        Text("Pago Móvil, USDT, USDC o tarjeta")
                                            .font(.k(.caption))
                                            .foregroundStyle(Palette.ink3)
                                    }
                                } icon: {
                                    Image(systemName: "safari")
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.k(.caption))
                                    .foregroundStyle(Palette.ink3)
                                    .accessibilityHidden(true)
                            }
                        }
                    } footer: {
                        Text("Se abre Kuolki en Safari con tu cuenta y este plan. Pago Móvil en bolívares a la tasa oficial del euro del BCV. Tu plan se activa cuando confirmamos el pago.")
                    }
                }

                Section {
                    Button("Restaurar compras de Apple") {
                        Task { await purchases.restore() }
                    }
                    .disabled(purchases.busy)
                }
            }
            .liminalList()
            .navigationTitle("Elige cómo pagar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .task { await purchases.load() }
            .onChange(of: purchases.message) { _, text in
                if let text {
                    store.show(text)
                    purchases.message = nil
                }
            }
        }
    }

    private func payWithApple(_ plan: PlanKind, annual: Bool) async {
        if await purchases.buy(plan, annual: annual, account: store.appAccountToken, using: purchase) {
            store.show("Listo: tu plan \(store.planLabel.lowercased()) quedó activo.")
            dismiss()
        }
    }
}
