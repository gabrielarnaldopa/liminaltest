import SwiftUI

@main
@MainActor
struct LiminalApp: App {
    @State private var auth = AuthService()
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(store)
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
        .dynamicTypeSize(store.state.prefs.fontScale.dynamicTypeSize)
        .environment(\.locale, Fmt.locale)
        .tint(Palette.ink)
        .onChange(of: store.state) { store.scheduleSave() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                auth.refreshSession()
                store.checkUsage()
            } else {
                store.saveNow()
            }
        }
    }
}

/// Sidebar with chats, projects and folders, and the selected screen on the right
/// (on iPhone, one after the other).
struct MainView: View {
    @Environment(AppStore.self) private var store
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var compactColumn: NavigationSplitViewColumn = .detail
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn) {
            SidebarView(compactColumn: $compactColumn, showSettings: $showSettings)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            NavigationStack {
                DetailView()
            }
        }
        .onChange(of: store.route) { store.routeChanged() }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
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
