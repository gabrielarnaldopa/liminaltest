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
        Service(name: "Modelos (DeepSeek, Qwen, GLM)", status: "Operativo", level: .good),
        Service(name: "Cobros en Tron", status: "Operativo", level: .good),
        Service(name: "Cobros en Base", status: "Lento", level: .warn),
        Service(name: "Cobros en Solana", status: "Operativo", level: .good),
        Service(name: "Bot de Telegram", status: "Operativo", level: .good),
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
                HStack {
                    StatusChip(text: draft.weeklyCapFits ? "El límite semanal cabe en el presupuesto"
                                                         : "El límite semanal no cabe: bájalo o sube el precio",
                               level: draft.weeklyCapFits ? .good : .bad)
                    Spacer(minLength: 0)
                }
            } header: {
                Text("Economía por usuario al mes")
            } footer: {
                Text("Calculado con DeepSeek V4 Pro a $0,56 por millón de tokens y 2.000 tokens por mensaje.")
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
                Text("Motores disponibles")
            } footer: {
                Text("Tiene que quedar al menos uno encendido.")
            }

            Section {
                Button {
                    store.saveAdmin(draft)
                } label: {
                    Text("Guardar cambios")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(!isValid || draft == store.state.admin)
                Button("Volver a los valores recomendados") {
                    draft = .defaults
                }
                .foregroundStyle(Palette.ink2)
            }
        }
        .liminalList()
        .onAppear {
            if !loaded {
                draft = store.state.admin
                loaded = true
            }
        }
    }

    private var pricesValid: Bool { draft.priceMonthly > 0 && draft.priceWeekly > 0 }
    private var capsValid: Bool { draft.weekCap >= draft.advCap }
    private var isValid: Bool { pricesValid && capsValid && !draft.enabledEngines.isEmpty }

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
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(payment.email)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                            Text("\(payment.plan.name) · \(payment.network.name) · \(Fmt.relative(payment.date))")
                                .font(.caption)
                                .foregroundStyle(Palette.ink3)
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
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .liminalList()
    }
}
