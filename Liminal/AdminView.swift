import SwiftUI

/// Admin panel: summary, users, plans and payments. Only visible to the admin account.
struct AdminView: View {
    @Environment(AuthService.self) private var auth

    enum Tab: String, CaseIterable, Identifiable {
        case resumen, usuarios, planes, pagos
        var id: String { rawValue }
        var name: String {
            switch self {
            case .resumen: return "Resumen"
            case .usuarios: return "Usuarios"
            case .planes: return "Planes"
            case .pagos: return "Pagos"
            }
        }
    }

    @State private var tab: Tab = .resumen

    var body: some View {
        Group {
            if auth.session?.isAdmin == true {
                VStack(spacing: 0) {
                    Picker("Sección", selection: $tab) {
                        ForEach(Tab.allCases) { tab in
                            Text(tab.name).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    switch tab {
                    case .resumen: AdminSummary()
                    case .usuarios: AdminUsers()
                    case .planes: AdminPlans()
                    case .pagos: AdminPayments()
                    }
                }
            } else {
                ContentUnavailableView("Sin acceso", systemImage: "lock",
                                       description: Text("Esta sección es solo para la cuenta de administración."))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.side)
        .navigationTitle("Administración")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Summary

struct AdminSummary: View {
    @Environment(AppStore.self) private var store

    private struct Service: Identifiable {
        let name: String
        let status: String
        let level: StatusLevel
        var id: String { name }
    }

    private let services: [Service] = [
        Service(name: "Motores de \(Brand.modelName) (DeepSeek, Qwen, GLM)", status: "Operativo", level: .good),
        Service(name: "Cobros en Tron", status: "Operativo", level: .good),
        Service(name: "Cobros en Base", status: "Lento", level: .warn),
        Service(name: "Cobros en Solana", status: "Operativo", level: .good),
        Service(name: "Motor de imágenes", status: "Operativo", level: .good),
        Service(name: "Motor de video", status: "Operativo", level: .good),
        Service(name: "Copias de seguridad", status: "Hace 2 horas", level: .good)
    ]

    var body: some View {
        let users = store.state.users
        let payments = store.state.payments
        let active = users.filter { $0.status != .suspendido }.count
        let expiring = users.filter { $0.status == .vence }.count
        let revenue = payments.filter { $0.status == .confirmado }.reduce(0.0) { $0 + amount($1.amount) }
        let pending = payments.filter { $0.status == .pendiente }.count
        let failed = payments.filter { $0.status == .fallido }.count
        let topUsers = users.sorted { $0.advThisWeek > $1.advThisWeek }.prefix(4)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    AdminTile(title: "Usuarios activos", value: Fmt.int(active), detail: "de \(users.count) en total")
                    AdminTile(title: "Ingresos confirmados", value: Fmt.money(revenue), detail: "últimos 30 días")
                    AdminTile(title: "Por vencer", value: Fmt.int(expiring), detail: "renuevan esta semana",
                              level: expiring > 0 ? .warn : .good)
                    AdminTile(title: "Pagos pendientes", value: Fmt.int(pending), detail: "esperando a la red",
                              level: pending > 0 ? .warn : .good)
                    AdminTile(title: "Pagos fallidos", value: Fmt.int(failed), detail: "revisar con el cliente",
                              level: failed > 0 ? .bad : .good)
                    AdminTile(title: "Margen objetivo", value: "\(Int(store.state.admin.margin)) %",
                              detail: "precio \(Fmt.money(store.state.admin.priceMonthly)) al mes")
                }

                Card(title: "Estado del servicio") {
                    ForEach(services) { service in
                        HStack {
                            Text(service.name)
                                .font(.subheadline)
                                .foregroundStyle(Palette.ink)
                            Spacer(minLength: 8)
                            StatusChip(text: service.status, level: service.level)
                        }
                        if service.id != services.last?.id {
                            Divider()
                        }
                    }
                }

                Card(title: "Más uso avanzado esta semana") {
                    ForEach(Array(topUsers)) { user in
                        UsageMeter(title: user.name, used: user.advThisWeek, cap: store.state.admin.weekCap)
                    }
                }

                NoticeView(level: .warn, text: "Datos de ejemplo. Al conectar el servidor, este panel muestra usuarios y pagos reales.")
            }
            .frame(maxWidth: 900)
            .padding(16)
            .frame(maxWidth: .infinity)
        }
    }

    /// "11 USDT" → 11
    private func amount(_ text: String) -> Double {
        Double(text.split(separator: " ").first ?? "") ?? 0
    }
}

struct AdminTile: View {
    let title: String
    let value: String
    var detail: String? = nil
    var level: StatusLevel? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let level {
                    Circle()
                        .fill(level.color)
                        .frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(Palette.ink3)
                    .lineLimit(1)
            }
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.ink3)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Users

struct AdminUsers: View {
    @Environment(AppStore.self) private var store

    enum Filter: String, CaseIterable, Identifiable {
        case todos, activo, vence, suspendido
        var id: String { rawValue }
        var name: String {
            switch self {
            case .todos: return "Todos"
            case .activo: return "Activos"
            case .vence: return "Por vencer"
            case .suspendido: return "Suspendidos"
            }
        }
    }

    @State private var search = ""
    @State private var filter: Filter = .todos
    @State private var target: AdminUser? = nil
    @State private var showConfirm = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Palette.ink3)
                    TextField("Buscar por nombre o correo", text: $search)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Picker("Estado", selection: $filter) {
                    ForEach(Filter.allCases) { filter in
                        Text(filter.name).tag(filter)
                    }
                }
            }

            Section("\(filtered.count) usuarios") {
                if filtered.isEmpty {
                    Text("Nadie coincide con tu búsqueda.")
                        .foregroundStyle(Palette.ink3)
                }
                ForEach(filtered) { user in
                    row(user)
                }
            }
        }
        .liminalList()
        .confirmationDialog(confirmTitle, isPresented: $showConfirm, titleVisibility: .visible, presenting: target) { user in
            if user.status == .suspendido {
                Button("Reactivar") { store.toggleSuspension(user.id) }
            } else {
                Button("Suspender", role: .destructive) { store.toggleSuspension(user.id) }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { user in
            Text(user.status == .suspendido
                 ? "\(user.name) podrá volver a usar Liminal."
                 : "\(user.name) no podrá usar Liminal hasta que lo reactives.")
        }
    }

    private var filtered: [AdminUser] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return store.state.users.filter { user in
            let matchesFilter: Bool
            switch filter {
            case .todos: matchesFilter = true
            case .activo: matchesFilter = user.status == .activo
            case .vence: matchesFilter = user.status == .vence
            case .suspendido: matchesFilter = user.status == .suspendido
            }
            let matchesSearch = query.isEmpty
                || user.name.localizedCaseInsensitiveContains(query)
                || user.email.localizedCaseInsensitiveContains(query)
            return matchesFilter && matchesSearch
        }
    }

    private var confirmTitle: String {
        guard let target else { return "" }
        return target.status == .suspendido ? "¿Reactivar a \(target.name)?" : "¿Suspender a \(target.name)?"
    }

    private func row(_ user: AdminUser) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(user.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Palette.ink)
                        if user.isAdmin {
                            RoleBadge()
                        }
                    }
                    Text(user.email)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink3)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                StatusChip(text: user.status.label, level: user.status.level)
            }
            UsageMeter(title: "Avanzado esta semana", used: user.advThisWeek, cap: store.state.admin.weekCap)
            HStack {
                Text("Plan \(user.plan.name.lowercased()) · \(Fmt.int(user.points)) puntos · visto \(Fmt.relative(user.lastSeen))")
                    .font(.caption)
                    .foregroundStyle(Palette.ink3)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if !user.isAdmin {
                    Button(user.status == .suspendido ? "Reactivar" : "Suspender") {
                        target = user
                        showConfirm = true
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(user.status == .suspendido ? Palette.greenText : Palette.redText)
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Plans and limits

struct AdminPlans: View {
    @Environment(AppStore.self) private var store
    @State private var draft = AdminConfig.defaults
    @State private var loaded = false
    @State private var pay = PaymentSettings.defaults
    @State private var testing = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Mensual (USD)") {
                    TextField("11", value: $draft.priceMonthly, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Semanal (USD)") {
                    TextField("3", value: $draft.priceWeekly, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Precios")
            } footer: {
                if !pricesValid {
                    Text("Los precios tienen que ser mayores que 0.")
                        .foregroundStyle(Palette.redText)
                }
            }

            Section {
                Stepper(value: $draft.advCap, in: 5...500, step: 5) {
                    limitLabel("Avanzado por ventana de 5 h", "\(Fmt.int(draft.advCap)) mensajes")
                }
                Stepper(value: $draft.weekCap, in: 20...5000, step: 10) {
                    limitLabel("Avanzado por semana", "\(Fmt.int(draft.weekCap)) mensajes")
                }
                Stepper(value: $draft.fastCap, in: 10...5000, step: 10) {
                    limitLabel("Rápido por día", "\(Fmt.int(draft.fastCap)) mensajes")
                }
            } header: {
                Text("Límites")
            } footer: {
                if !capsValid {
                    Text("El límite semanal no puede ser menor que el de la ventana de 5 horas.")
                        .foregroundStyle(Palette.redText)
                }
            }

            Section {
                Stepper(value: $draft.creditsCap, in: 0...2000, step: 10) {
                    limitLabel("Créditos al mes", "\(Fmt.int(draft.creditsCap)) · imagen: 1 · video de 5 s: 5")
                }
                LabeledContent("Costo por crédito (USD)") {
                    TextField("0,021", value: $draft.creditCost, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Imágenes y video")
            } footer: {
                Text("Lo que te cobra el proveedor por una imagen. Un video de 5 segundos cuesta unas 5 imágenes.")
            }

            Section {
                Picker("Tasa para Pago Móvil", selection: $pay.useEuroRate) {
                    Text("Euro BCV").tag(true)
                    Text("Dólar BCV").tag(false)
                }
                LabeledContent("Tasa euro (Bs por €)") {
                    TextField("982,76", value: $pay.rateEur, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Tasa dólar (Bs por $)") {
                    TextField("877,90", value: $pay.rateUsd, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                TextField("Banco para Pago Móvil", text: $pay.mobileBank)
                TextField("Teléfono", text: $pay.mobilePhone)
                    .keyboardType(.phonePad)
                TextField("RIF o cédula", text: $pay.mobileID)
                TextField("Dirección USDT en Tron", text: $pay.walletTron)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Dirección USDC en Base", text: $pay.walletBase)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Dirección en Solana (USDT y USDC)", text: $pay.walletSolana)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Cobros")
            } footer: {
                Text("Con la tasa del euro el monto en bolívares es mayor que con la del dólar. El servidor actualiza las tasas cada día desde el BCV.")
            }

            Section("Margen") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Margen")
                            .foregroundStyle(Palette.ink)
                        Spacer()
                        Text(verbatim: "\(Int(draft.margin)) %")
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink3)
                    }
                    Slider(value: $draft.margin, in: 0...90, step: 5)
                        .tint(Palette.ink)
                        .accessibilityLabel("Margen")
                        .accessibilityValue("\(Int(draft.margin)) por ciento")
                }
            }

            Section {
                LabeledContent("Presupuesto de cómputo", value: Fmt.money(draft.computeBudget))
                LabeledContent("Tokens que cubre", value: "\(Fmt.decimal(draft.millionTokens)) M")
                LabeledContent("Uso máximo al mes", value: "\(Fmt.decimal(maxMonthlyMillions)) M")
                LabeledContent("Texto, peor caso", value: Fmt.money(rounded(draft.maxTextCost)))
                LabeledContent("Imágenes y video, peor caso", value: Fmt.money(rounded(draft.maxMediaCost)))
                LabeledContent("Peor caso total", value: "\(Fmt.money(rounded(draft.maxTotalCost))) de \(Fmt.money(rounded(draft.computeBudget)))")
                HStack {
                    StatusChip(text: draft.worstCaseFits ? "Cabe en el presupuesto aunque alguien use todo"
                                                         : "No cabe: baja los créditos o el tope semanal",
                               level: draft.worstCaseFits ? .good : .bad)
                    Spacer(minLength: 0)
                }
            } header: {
                Text("Economía por usuario al mes")
            } footer: {
                Text("Calculado con DeepSeek V4 Pro a $0,56 por millón de tokens y 2.000 tokens por mensaje.")
            }

            Section {
                TextField("https://liminal-api.tu-cuenta.workers.dev", text: serverURLBinding)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Clave de la app", text: serverKeyBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    testing = true
                    Task {
                        let message = await store.testServer(address: draft.serverURL ?? "", key: draft.serverKey ?? "")
                        testing = false
                        store.show(message)
                    }
                } label: {
                    Label(testing ? "Probando…" : "Probar conexión", systemImage: "bolt")
                }
                .disabled(testing)
            } header: {
                HStack(spacing: 6) {
                    Text("Servidor de \(Brand.modelName)")
                    Spacer()
                    StatusChip(text: store.serverReady ? "Conectado" : "Demostración", level: store.serverReady ? .good : .warn)
                }
            } footer: {
                Text("La clave de DeepSeek vive solo en tu servidor. Aquí van su dirección y la clave de la app que inventaste al crearlo. Sin servidor, Lithium da respuestas de demostración.")
            }

            Section {
                ForEach(Engine.allCases) { engine in
                    Toggle(isOn: engineBinding(engine)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(engine.name)
                                .foregroundStyle(Palette.ink)
                            Text(engine.note)
                                .font(.caption)
                                .foregroundStyle(Palette.ink3)
                        }
                    }
                    .tint(Palette.green)
                }
            } header: {
                Text("Motores detrás de \(Brand.modelName)")
            } footer: {
                Text("Tus clientes solo ven \(Brand.modelName). Si el primero se satura, el mensaje pasa al siguiente. Tiene que quedar al menos uno encendido.")
            }

            Section {
                Button {
                    store.saveAdmin(draft)
                    store.savePaySettings(pay)
                } label: {
                    Text("Guardar cambios")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(!isValid || (draft == store.state.admin && pay == store.state.pay))
                Button("Volver a los valores recomendados") {
                    let address = draft.serverURL, key = draft.serverKey
                    draft = .defaults
                    draft.serverURL = address
                    draft.serverKey = key
                }
                .foregroundStyle(Palette.ink2)
            }
        }
        .liminalList()
        .onAppear {
            if !loaded {
                draft = store.state.admin
                pay = store.state.pay
                loaded = true
            }
        }
    }

    private func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private var serverURLBinding: Binding<String> {
        Binding(get: { draft.serverURL ?? "" }, set: { draft.serverURL = $0 })
    }

    private var serverKeyBinding: Binding<String> {
        Binding(get: { draft.serverKey ?? "" }, set: { draft.serverKey = $0 })
    }

    private var pricesValid: Bool { draft.priceMonthly > 0 && draft.priceWeekly > 0 }
    private var capsValid: Bool { draft.weekCap >= draft.advCap }
    private var isValid: Bool { pricesValid && capsValid && !draft.enabledEngines.isEmpty && draft.creditCost >= 0 }

    /// Someone who uses the whole weekly limit every week, in millions of tokens.
    private var maxMonthlyMillions: Double {
        Double(draft.weekCap * 4 * 2000) / 1_000_000
    }

    private func limitLabel(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundStyle(Palette.ink)
            Text(value)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Palette.ink3)
        }
    }

    private func engineBinding(_ engine: Engine) -> Binding<Bool> {
        Binding(
            get: { draft.enabledEngines.contains(engine) },
            set: { isOn in
                if isOn {
                    draft.enabledEngines.insert(engine)
                } else if draft.enabledEngines.count > 1 {
                    draft.enabledEngines.remove(engine)
                } else {
                    store.show("Tiene que quedar al menos un motor encendido")
                }
            }
        )
    }
}

// MARK: - Payments

struct AdminPayments: View {
    @Environment(AppStore.self) private var store
    @State private var filter: PaymentStatus? = nil

    var body: some View {
        let payments = store.state.payments.sorted { $0.date > $1.date }
        let shown = payments.filter { filter == nil || $0.status == filter }
        List {
            Section {
                Picker("Estado", selection: $filter) {
                    Text("Todos").tag(PaymentStatus?.none)
                    ForEach(PaymentStatus.allCases) { status in
                        Text(status.label).tag(PaymentStatus?.some(status))
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section("\(shown.count) pagos") {
                if shown.isEmpty {
                    Text("No hay pagos con este estado.")
                        .foregroundStyle(Palette.ink3)
                }
                ForEach(shown) { payment in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(payment.email)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Palette.ink)
                                    .lineLimit(1)
                                Text("\(payment.plan.name) · \(payment.method) · \(Fmt.relative(payment.date))")
                                    .font(.caption)
                                    .foregroundStyle(Palette.ink3)
                                if !payment.reference.isEmpty {
                                    Text("Referencia \(payment.reference)")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(Palette.ink3)
                                }
                            }
                            Spacer(minLength: 8)
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(payment.amount)
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.ink)
                                StatusChip(text: payment.status.label, level: payment.status.level)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        if payment.status == .pendiente && !payment.reference.isEmpty {
                            HStack(spacing: 10) {
                                Button("Aprobar") {
                                    store.review(paymentID: payment.id, approve: true)
                                }
                                .foregroundStyle(Palette.greenText)
                                Button("Rechazar") {
                                    store.review(paymentID: payment.id, approve: false)
                                }
                                .foregroundStyle(Palette.redText)
                            }
                            .font(.footnote.weight(.semibold))
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .liminalList()
    }
}
