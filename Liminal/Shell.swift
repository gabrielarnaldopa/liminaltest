import SwiftUI
import UIKit

// MARK: - iPhone layout: the screen full size, the side menu sliding over it

/// On iPhone the screen you are on fills the phone and the side menu slides in from the left,
/// following your finger: swipe right anywhere to open it, swipe left or tap outside to close it.
struct PhoneShell: View {
    @Environment(AppStore.self) private var store
    /// How far the finger has moved since the swipe began (positive opens, negative closes).
    @State private var drag: CGFloat = 0
    @State private var dragging = false

    private let spring = Animation.spring(response: 0.34, dampingFraction: 0.86)

    var body: some View {
        GeometryReader { geo in
            let width = min(geo.size.width * 0.86, 340)
            let reveal = revealed(width: width)
            let progress = width > 0 ? reveal / width : 0

            ZStack(alignment: .topLeading) {
                NavigationStack {
                    DetailView()
                }
                .accessibilityHidden(store.drawerOpen)

                // The dim layer: tap it to close the menu.
                Color.black
                    .opacity(0.32 * progress)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { setOpen(false) }
                    .allowsHitTesting(progress > 0.01)
                    .accessibilityHidden(true)

                if progress > 0 || dragging {
                    ZStack(alignment: .topLeading) {
                        DrawerSurface()
                            .ignoresSafeArea()
                        SideMenu(compact: true)
                    }
                    .frame(width: width)
                    // A soft edge instead of a live shadow: it costs nothing while the menu moves.
                    .overlay(alignment: .trailing) {
                        LinearGradient(colors: [.black.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 18)
                            .offset(x: 18)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                    .frame(maxHeight: .infinity)
                    .offset(x: reveal - width)
                    .allowsHitTesting(progress > 0.98)
                    .accessibilityHidden(!store.drawerOpen)
                    .accessibilityAction(.escape) { setOpen(false) }
                    .transition(.move(edge: .leading))
                    .transaction { if dragging { $0.animation = nil } }
                }
            }
            .background(
                DrawerPan(
                    isOpen: store.drawerOpen,
                    onChange: { dx in
                        if !dragging {
                            dragging = true
                            Keyboard.dismiss()
                        }
                        drag = store.drawerOpen ? min(0, max(-width, dx)) : max(0, min(width, dx))
                    },
                    onEnd: { dx, velocity in
                        let base: CGFloat = store.drawerOpen ? width : 0
                        let moved = store.drawerOpen ? min(0, dx) : max(0, dx)
                        let projected = base + moved + velocity * 0.18
                        dragging = false
                        withAnimation(spring) {
                            store.drawerOpen = projected > width / 2
                            drag = 0
                        }
                    }
                )
                .frame(width: 0, height: 0)
            )
            .onChange(of: store.drawerOpen) { _, open in
                if open { Keyboard.dismiss() }
            }
        }
    }

    private func revealed(width: CGFloat) -> CGFloat {
        let base: CGFloat = store.drawerOpen ? width : 0
        return max(0, min(width, base + drag))
    }

    private func setOpen(_ open: Bool) {
        withAnimation(spring) {
            store.drawerOpen = open
            drag = 0
        }
    }
}

/// The glass the side menu is made of.
struct DrawerSurface: View {
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                               bottomTrailingRadius: 34, topTrailingRadius: 34, style: .continuous)
    }

    /// Solid, not glass: a blur that has to be redrawn on every frame of the swipe is what made it stutter.
    var body: some View {
        shape.fill(Palette.side)
    }
}

/// Closes the keyboard (before the menu slides in).
enum Keyboard {
    @MainActor static func dismiss() {
        #if canImport(ObjectiveC)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

// MARK: - The swipe that opens and closes the menu

/// Listens for sideways swipes anywhere on the screen. Up-and-down swipes keep scrolling as always,
/// and things that scroll sideways (code, tables) keep their own swipe.
struct DrawerPan: UIViewRepresentable {
    var isOpen: Bool
    var onChange: (CGFloat) -> Void
    var onEnd: (CGFloat, CGFloat) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> Anchor {
        let view = Anchor()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ view: Anchor, context: Context) {
        context.coordinator.isOpen = isOpen
        context.coordinator.onChange = onChange
        context.coordinator.onEnd = onEnd
        view.coordinator = context.coordinator
        context.coordinator.attach(to: view.window)
    }

    /// An invisible view whose only job is to find the window and put the swipe on it.
    final class Anchor: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            coordinator?.attach(to: window)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var isOpen = false
        var onChange: (CGFloat) -> Void = { _ in }
        var onEnd: (CGFloat, CGFloat) -> Void = { _, _ in }
        private var pan: UIPanGestureRecognizer?
        private weak var window: UIWindow?

        func attach(to newWindow: UIWindow?) {
            guard let newWindow, newWindow !== window else { return }
            if let pan, let old = pan.view { old.removeGestureRecognizer(pan) }
            #if canImport(ObjectiveC)
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handle(_:)))
            #else
            let recognizer = UIPanGestureRecognizer()
            #endif
            recognizer.delegate = self
            recognizer.maximumNumberOfTouches = 1
            newWindow.addGestureRecognizer(recognizer)
            pan = recognizer
            window = newWindow
        }

        #if canImport(ObjectiveC)
        @objc func handle(_ recognizer: UIPanGestureRecognizer) { follow(recognizer) }
        #endif

        func follow(_ recognizer: UIPanGestureRecognizer) {
            let dx = recognizer.translation(in: recognizer.view).x
            switch recognizer.state {
            case .began, .changed:
                onChange(dx)
            case .ended, .cancelled, .failed:
                onEnd(dx, recognizer.velocity(in: recognizer.view).x)
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let recognizer = gestureRecognizer as? UIPanGestureRecognizer,
                  let window = recognizer.view as? UIWindow else { return false }
            // Not while a sheet, the camera or another full screen is on top.
            if window.rootViewController?.presentedViewController != nil { return false }
            let velocity = recognizer.velocity(in: window)
            guard abs(velocity.x) > abs(velocity.y) * 1.2 else { return false }
            if isOpen { return velocity.x < 0 }
            guard velocity.x > 0 else { return false }
            // Inside a screen you opened (its back swipe goes first).
            if Self.canGoBack(window.rootViewController) { return false }
            // Leave the swipe to anything that scrolls sideways and can still move right.
            var view = window.hitTest(recognizer.location(in: window), with: nil)
            while let current = view {
                if let scroll = current as? UIScrollView, scroll.isScrollEnabled,
                   scroll.contentSize.width > scroll.bounds.width + 1,
                   scroll.contentOffset.x > 1 {
                    return false
                }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            false
        }

        /// Lists wait a moment for this swipe to decide: a sideways swipe moves the menu,
        /// an up-and-down one is handed straight back to the list.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
            other is UIPanGestureRecognizer && other.view is UIScrollView
        }

        /// True when a navigation stack on screen has a page pushed on top of its first one.
        private static func canGoBack(_ controller: UIViewController?) -> Bool {
            guard let controller else { return false }
            if let navigation = controller as? UINavigationController, navigation.viewControllers.count > 1 {
                return true
            }
            return controller.children.contains { canGoBack($0) }
        }
    }
}

// MARK: - The bar at the top

/// The floating glass bar at the top of every main screen: the menu, the model in the middle
/// and two actions on the right. It fits from the smallest iPhone (or Display Zoom) to the largest.
struct TopBar<Center: View, Trailing: View>: View {
    @Environment(AppStore.self) private var store
    @ViewBuilder var center: Center
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) { store.openMenu() }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
                    .liquidCircle()
            }
            .buttonStyle(PressScale())
            .accessibilityLabel("Menú")

            center
                .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                trailing
            }
            .frame(height: 44)
            .liquidCapsule()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .background(alignment: .top) {
            LinearGradient(stops: [
                Gradient.Stop(color: Palette.bg.opacity(0.97), location: 0),
                Gradient.Stop(color: Palette.bg.opacity(0.78), location: 0.62),
                Gradient.Stop(color: Palette.bg.opacity(0), location: 1)
            ], startPoint: .top, endPoint: .bottom)
            .padding(.bottom, -18)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }
}

/// One button inside the pair on the right of the top bar.
struct BarButton: View {
    let icon: String
    let label: String
    var tint: Color = Palette.ink
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .accessibilityLabel(label)
    }
}

/// The thin line between the two buttons on the right.
struct BarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Palette.line2)
            .frame(width: 0.5, height: 20)
            .accessibilityHidden(true)
    }
}

/// A title in a glass capsule, for screens that do not show the model (Administración).
struct BarTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.k(.headline))
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 16)
            .frame(height: 44)
            .liquidCapsule()
    }
}

extension View {
    /// Puts the glass top bar on a main screen and hides the system bar.
    func topBar<Center: View, Trailing: View>(@ViewBuilder center: () -> Center,
                                               @ViewBuilder trailing: () -> Trailing) -> some View {
        let bar = TopBar(center: center, trailing: trailing)
        return self
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) { bar }
    }
}

// MARK: - Sheets and full screens shared by the iPhone and iPad layouts

struct AppSheets: ViewModifier {
    @Environment(AppStore.self) private var store

    func body(content: Content) -> some View {
        @Bindable var store = store
        return content
            .sheet(isPresented: $store.showSettings) {
                SettingsView()
                    .kAppearance(store.prefs)
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(32)
            }
            .fullScreenCover(isPresented: $store.showVoice) {
                LiveVoiceView()
            }
            .fullScreenCover(isPresented: $store.showDev) { DevWebSheet() }
            .sheet(item: $store.browser) { target in
                BrowserView(start: target.url)
            }
            .sheet(isPresented: $store.showConnectors) {
                NavigationStack {
                    ConnectorsSettings()
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Listo") { store.showConnectors = false }
                            }
                        }
                }
                .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func appSheets() -> some View { modifier(AppSheets()) }
}
