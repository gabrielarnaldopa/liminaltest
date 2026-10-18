import SwiftUI
import UIKit
import WebKit
import Observation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Browsing steps, permission and sources in a message

/// «Buscó …», «Leyó …»: what Lithium did on the web for this answer.
struct ToolStepsView: View {
    let steps: [ToolStep]
    let onOpen: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(steps) { step in
                HStack(spacing: 8) {
                    if step.isBusy {
                        PulsingDot(color: Palette.yellow)
                    } else {
                        Image(systemName: step.isSearch ? "magnifyingglass" : "globe")
                            .foregroundStyle(Palette.ink3)
                    }
                    if !step.isSearch, step.status != "denied", let url = URL(string: step.url) {
                        Button {
                            onOpen(url)
                        } label: {
                            Text(step.label).lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(step.label).lineLimit(1)
                    }
                }
                .font(.footnote)
                .foregroundStyle(step.status == "denied" || step.status == "error" ? Palette.ink3 : Palette.ink2)
            }
        }
    }
}

/// «Lithium quiere entrar a …» with Permitir, Permitir siempre and No.
struct AskCardView: View {
    let ask: AskRequest
    let onAnswer: (_ approved: Bool, _ always: Bool) -> Void
    let onAuto: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ask.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.ink)
            ForEach(ask.items) { item in
                Label(item.isSearch ? "«\(item.query)»" : item.url, systemImage: item.isSearch ? "magnifyingglass" : "globe")
                    .font(.caption)
                    .foregroundStyle(Palette.ink3)
                    .lineLimit(2)
            }
            FlowLayout(spacing: 8) {
                answerButton("Permitir", primary: true) { onAnswer(true, false) }
                answerButton(ask.alwaysLabel, primary: false) { onAnswer(true, true) }
                answerButton("No", primary: false) { onAnswer(false, false) }
            }
            .padding(.top, 4)
            Button("Navegar siempre sin preguntar", action: onAuto)
                .font(.caption.weight(.medium))
                .foregroundStyle(Palette.ink2)
                .buttonStyle(.borderless)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.line2, lineWidth: 1))
    }

    private func answerButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(primary ? Palette.bg : Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(primary ? Palette.ink : Palette.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(primary ? Color.clear : Palette.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// The pages an answer cites, opened in the built-in browser.
struct LinkSourcesView: View {
    let links: [SourceLink]
    let onOpen: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Fuentes")
                .font(.caption)
                .foregroundStyle(Palette.ink3)
            FlowLayout(spacing: 6) {
                ForEach(links, id: \.url) { link in
                    if let url = URL(string: link.url) {
                        Button {
                            onOpen(url)
                        } label: {
                            Label(link.host, systemImage: "globe")
                                .font(.caption)
                                .foregroundStyle(Palette.ink2)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Palette.sunk, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Abrir \(link.title)")
                    }
                }
            }
        }
    }
}

// MARK: - Live pages and presentations

/// A page or presentation in an answer: tap to see it live.
struct ArtifactCard: View {
    let doc: ArtifactDoc
    let writing: Bool
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Palette.sunk)
                    if writing {
                        PulsingDot(color: Palette.yellow)
                    } else {
                        Image(systemName: doc.icon)
                            .foregroundStyle(Palette.ink2)
                    }
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(writing ? "\(doc.kindName) · escribiendo… \(doc.lines) líneas" : "\(doc.kindName) · \(doc.lines) líneas")
                        .font(.caption)
                        .foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 8)
                Text(writing ? "Ver código" : "Abrir")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(writing ? Palette.ink2 : Palette.bg)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(writing ? Palette.sunk : Palette.ink, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .padding(12)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(doc.kindName): \(doc.title). Abrir")
    }
}

/// Full screen: the page running, or its code, with share and close.
struct ArtifactView: View {
    let doc: ArtifactDoc
    @Environment(\.dismiss) private var dismiss
    @State private var showCode = false
    @State private var shared: SharedFile? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: doc.icon)
                    .foregroundStyle(Palette.ink2)
                    .frame(width: 34, height: 34)
                    .background(Palette.sunk, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(doc.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text("\(doc.kindName) · \(doc.lines) líneas")
                        .font(.caption)
                        .foregroundStyle(Palette.ink3)
                }
                Spacer(minLength: 8)
                Button {
                    share()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Compartir o guardar el archivo")
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Cerrar")
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Picker("Ver", selection: $showCode) {
                Text("Vista previa").tag(false)
                Text("Código").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            if showCode {
                ScrollView([.vertical, .horizontal]) {
                    Text(verbatim: doc.code)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(Palette.codeInk)
                        .textSelection(.enabled)
                        .padding(14)
                }
                .background(Palette.codeBg)
            } else {
                WebView(content: .html(doc.html))
            }
        }
        .background(Palette.bg)
        .sheet(item: $shared) { file in
            ShareSheet(url: file.url)
        }
    }

    private func share() {
        let name = doc.title.folding(options: .diacriticInsensitive, locale: Locale(identifier: "es")).lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent((name.isEmpty ? "pagina" : String(name.prefix(50))) + "." + doc.fileExtension)
        if (try? doc.code.data(using: .utf8)?.write(to: url, options: .atomic)) != nil {
            shared = SharedFile(url: url)
        }
    }
}

// MARK: - Web view

/// What a web view shows and what it can do, for the browser's buttons.
@MainActor
@Observable
final class BrowserModel {
    var url: URL?
    var title = ""
    var canGoBack = false
    var canGoForward = false
    var isLoading = false
    @ObservationIgnored weak var webView: WKWebView?

    func load(_ url: URL) {
        self.url = url
        webView?.load(URLRequest(url: url))
    }
    func back() { webView?.goBack() }
    func forward() { webView?.goForward() }
    func reload() { webView?.reload() }

    func sync() {
        guard let webView else { return }
        url = webView.url ?? url
        title = webView.title ?? ""
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
        isLoading = webView.isLoading
    }
}

struct WebView: UIViewRepresentable {
    enum Content: Equatable {
        case html(String)
        case url(URL)
    }

    let content: Content
    var model: BrowserModel? = nil

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        model?.webView = view
        switch content {
        case .html(let html):
            // A web address as origin, so pages that save data (localStorage) work.
            view.loadHTMLString(html, baseURL: URL(string: "https://preview.liminal.app/"))
        case .url(let url):
            view.load(URLRequest(url: url))
        }
        context.coordinator.loaded = content
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.loaded != content else { return }
        context.coordinator.loaded = content
        switch content {
        case .html(let html): view.loadHTMLString(html, baseURL: URL(string: "https://preview.liminal.app/"))
        case .url(let url): view.load(URLRequest(url: url))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        let model: BrowserModel?
        var loaded: Content?

        init(model: BrowserModel?) {
            self.model = model
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { model?.sync() }
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) { model?.sync() }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { model?.sync() }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { model?.sync() }
    }
}

/// The built-in browser: links from answers open here, and /navegador opens it empty.
struct BrowserView: View {
    let start: URL?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var model = BrowserModel()
    @State private var address = ""
    @State private var opened: URL? = nil
    @FocusState private var editing: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    model.back()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!model.canGoBack)
                .accessibilityLabel("Atrás")
                Button {
                    model.forward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!model.canGoForward)
                .accessibilityLabel("Adelante")

                TextField("Dirección o búsqueda", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .focused($editing)
                    .onSubmit(go)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Palette.sunk, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Button {
                    model.reload()
                } label: {
                    Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
                }
                .disabled(opened == nil)
                .accessibilityLabel("Recargar")
                Menu {
                    if let url = model.url ?? opened {
                        Button {
                            openURL(url)
                        } label: {
                            Label("Abrir en Safari", systemImage: "safari")
                        }
                        Button {
                            UIPasteboard.general.string = url.absoluteString
                        } label: {
                            Label("Copiar enlace", systemImage: "link")
                        }
                    }
                    Button {
                        dismiss()
                    } label: {
                        Label("Cerrar", systemImage: "xmark")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Más opciones")
            }
            .font(.body.weight(.medium))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if let opened {
                WebView(content: .url(opened), model: model)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "safari")
                        .font(.largeTitle)
                        .foregroundStyle(Palette.ink3)
                    Text("Navegador de Liminal")
                        .font(.headline)
                    Text("Escribe una dirección arriba o toca un enlace en cualquier respuesta.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink3)
                        .multilineTextAlignment(.center)
                    Button("Cerrar") { dismiss() }
                        .padding(.top, 6)
                }
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.bg)
        .onAppear {
            if let start {
                opened = start
                address = start.absoluteString
            } else {
                editing = true
            }
        }
        .onChange(of: model.url) { _, url in
            if let url, !editing { address = url.absoluteString }
        }
    }

    private func go() {
        guard let url = Browsing.url(from: address) else { return }
        editing = false
        if opened == nil {
            opened = url
        } else {
            model.load(url)
        }
        address = url.absoluteString
    }
}

// MARK: - Slash commands

/// The list that appears over the composer after typing "/".
struct SlashSuggestions: View {
    let commands: [SlashCommand]
    let onPick: (SlashCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Comandos")
                .font(.caption)
                .foregroundStyle(Palette.ink3)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(commands) { command in
                        Button {
                            onPick(command)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: command.icon)
                                    .frame(width: 22)
                                    .foregroundStyle(Palette.ink2)
                                Text("/\(command.key)")
                                    .font(.system(.subheadline, design: .monospaced).weight(.medium))
                                    .foregroundStyle(Palette.ink)
                                Text(command.title)
                                    .font(.subheadline)
                                    .foregroundStyle(Palette.ink3)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(command.title): \(command.detail)")
                    }
                }
            }
            .frame(maxHeight: 260)
        }
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

// MARK: - Settings: browsing and devices

struct NavigationSettings: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        let mode = store.state.prefs.browse ?? .ask
        Form {
            Section {
                Picker("Antes de entrar a un sitio", selection: Binding(get: { mode }, set: { store.state.prefs.browse = $0 })) {
                    ForEach(BrowseMode.allCases) { option in
                        Text(option.name).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                if mode == .ask {
                    Toggle("Buscar sin preguntar", isOn: Binding(get: { store.state.prefs.allowSearch ?? false },
                                                                set: { store.state.prefs.allowSearch = $0 }))
                }
            } footer: {
                Text(mode.detail)
            }

            if let server = store.server, !server.search {
                Section {
                    NoticeView(level: .warn, text: "La búsqueda no está activada en tu servidor. Agrega la clave gratis de Tavily (LEEME del servidor). Abrir enlaces funciona igual.")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                let hosts = store.state.prefs.allowedHosts ?? []
                if hosts.isEmpty {
                    Text("Ninguno todavía. Toca «Permitir siempre» cuando Lithium pida entrar a un sitio.")
                        .foregroundStyle(Palette.ink3)
                } else {
                    ForEach(hosts, id: \.self) { host in
                        Text(host)
                    }
                    .onDelete { offsets in
                        var list = hosts
                        list.remove(atOffsets: offsets)
                        store.state.prefs.allowedHosts = list
                    }
                }
            } header: {
                Text("Sitios que puede abrir sin preguntar")
            }

            Section {
                Button {
                    store.browser = BrowserTarget(url: nil)
                } label: {
                    Label("Abrir el navegador", systemImage: "safari")
                }
            } footer: {
                Text("Los enlaces de las respuestas se abren dentro de Liminal.")
            }
        }
        .liminalList()
        .navigationTitle("Navegación")
        .task { await store.refreshServer() }
    }
}

/// The phones and computers where the account is open, with sign out for each.
struct DevicesSection: View {
    @Environment(AppStore.self) private var store
    @State private var target: DeviceInfo? = nil
    @State private var confirmOthers = false

    var body: some View {
        Section {
            if !store.serverReady {
                Text("Conecta el servidor de Lithium para ver en qué teléfonos y computadoras está abierta tu cuenta.")
                    .foregroundStyle(Palette.ink3)
            } else if store.server?.background != true {
                Text("Tu servidor todavía no tiene la pieza para esto. Publícalo desde GitHub (paso «Activar todo lo nuevo» del LEEME del servidor) y aparecerán aquí.")
                    .foregroundStyle(Palette.ink3)
            } else if let devices = store.devices {
                ForEach(devices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: device.isPhone ? "iphone" : "laptopcomputer")
                            .foregroundStyle(Palette.ink2)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.current ? "\(device.name) · este dispositivo" : device.name)
                                .foregroundStyle(Palette.ink)
                            Text(subtitle(device))
                                .font(.caption)
                                .foregroundStyle(Palette.ink3)
                        }
                        Spacer(minLength: 8)
                        if !device.current {
                            Button("Cerrar sesión") { target = device }
                                .buttonStyle(.borderless)
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }
                if devices.count > 1 {
                    Button("Cerrar sesión en todos los demás", role: .destructive) { confirmOthers = true }
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Cargando…").foregroundStyle(Palette.ink3)
                }
            }
        } header: {
            Text("Dispositivos conectados")
        }
        .task {
            await store.refreshServer()
            await store.registerDevice()
        }
        .confirmationDialog("¿Cerrar sesión en \(target?.name ?? "ese dispositivo")?", isPresented: Binding(get: { target != nil }, set: { if !$0 { target = nil } }), titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) {
                if let id = target?.id {
                    Task {
                        if let error = await store.revokeDevice(id) { store.show(error) } else { store.show("Sesión cerrada en ese dispositivo") }
                    }
                }
                target = nil
            }
            Button("Cancelar", role: .cancel) { target = nil }
        } message: {
            Text("Ese dispositivo tendrá que volver a iniciar sesión.")
        }
        .confirmationDialog("¿Cerrar sesión en los demás?", isPresented: $confirmOthers, titleVisibility: .visible) {
            Button("Cerrar las demás", role: .destructive) {
                Task {
                    if let error = await store.revokeDevice("others") { store.show(error) } else { store.show("Listo: solo queda abierto este dispositivo") }
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private func subtitle(_ device: DeviceInfo) -> String {
        let seen = Date(timeIntervalSince1970: device.lastSeen / 1000)
        var text = device.current ? "Activo ahora" : "Activo \(Fmt.relative(seen))"
        if let country = device.country { text += " · \(Region.name(country))" }
        return text
    }
}
