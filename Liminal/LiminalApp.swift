import SwiftUI
import UIKit

@main
@MainActor
struct LiminalApp: App {
    @State private var auth = AuthService()
    @State private var store = AppStore()

    init() {
        KFont.applyToBars()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(store)
        }
        // iOS wakes the app here when an answer finishes on the server while the app is closed.
        .backgroundTask(.urlSession(BackgroundJobs.identifier)) { _ in
            await BackgroundJobs.shared.handleEvents()
        }
    }
}

/// Shows the sign-in screen or the app, and applies the person's theme and text size.
struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            if auth.session != nil {
                MainView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth.session == nil)
        .overlay(alignment: .bottom) { ToastView() }
        .preferredColorScheme(store.state.prefs.theme.colorScheme)
        .font(.k(.body))
        .dynamicTypeSize(store.state.prefs.fontScale.dynamicTypeSize)
        .environment(\.locale, Fmt.locale)
        .tint(Palette.ink)
        .onChange(of: store.state) { store.scheduleSave() }
        .onOpenURL { url in store.open(url) }
        .task {
            AppStore.deviceName = "\(UIDevice.current.model) · app de Kuolki"
            store.accountEmail = auth.session?.email
            store.appBecameActive()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                auth.refreshSession()
                store.checkUsage()
                store.accountEmail = auth.session?.email
                store.appBecameActive()
            case .background:
                store.appWentToBackground()
            default:
                store.saveNow()
            }
        }
        .onChange(of: auth.session?.email) { _, email in
            store.accountEmail = email
            if email != nil { Task { await store.registerDevice() } }
        }
        .onChange(of: store.signedOutRemotely) { _, out in
            guard out else { return }
            store.signedOutRemotely = false
            store.stop()
            auth.signOut()
            store.show("Cerraron tu sesión en este dispositivo desde otro.")
        }
    }
}

/// iPhone: the screen full size with the side menu that slides over it.
/// iPad: the sidebar with chats, projects and folders, and the selected screen on the right.
struct MainView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var compactColumn: NavigationSplitViewColumn = .detail

    var body: some View {
        Group {
            if sizeClass == .regular {
                splitView
            } else {
                PhoneShell()
            }
        }
        .onChange(of: store.route) { store.routeChanged() }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn) {
            SideMenu(compact: false)
                .background(Palette.side)
                .toolbar(.hidden, for: .navigationBar)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            NavigationStack {
                DetailView()
            }
        }
        // The menu button in the top bar shows or hides the sidebar.
        .onChange(of: store.drawerOpen) { _, open in
            guard open else { return }
            withAnimation { columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly }
            store.drawerOpen = false
        }
        .appSheets()
    }
}

struct DetailView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        switch store.route {
        case .chat(let id)?:
            if store.chat(id) != nil {
                ChatView(chatID: id).id(id)
            } else {
                HomeView()
            }
        case .project(let id)?:
            if store.project(id) != nil {
                ProjectView(projectID: id).id(id)
            } else {
                HomeView()
            }
        case .admin?:
            AdminView()
        case .home?, .none:
            HomeView()
        }
    }
}
