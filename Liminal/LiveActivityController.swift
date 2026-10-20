import Foundation
import ActivityKit
import UIKit

/// Starts, updates and ends Kuolki's Live Activity: the Dynamic Island on iPhones that have it
/// (14 Pro and newer) and the Lock Screen on every iPhone. Only one runs at a time.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    typealias Kind = LiminalActivityAttributes.Kind
    typealias State = LiminalActivityAttributes.ContentState

    /// Turned off in Ajustes › Voz e Isla Dinámica.
    var isOn = true
    private(set) var kind: Kind? = nil

    private var activity: Activity<LiminalActivityAttributes>? = nil
    /// What the activity shows right now.
    private(set) var current: State? = nil
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private init() {}

    /// False when the person turned Live Activities off, here or in the iPhone's settings.
    var isAvailable: Bool {
        isOn && systemAllows
    }

    /// The switch in Ajustes del iPhone › Kuolki › Actividades en vivo.
    var systemAllows: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Removes activities left over if the app closed while one was running.
    func removeLeftovers() {
        for leftover in Activity<LiminalActivityAttributes>.activities {
            Task { await leftover.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func start(_ kind: Kind, chatID: UUID?, state: State) {
        endNow()
        guard isAvailable else { return }
        let attributes = LiminalActivityAttributes(kind: kind, chatID: chatID?.uuidString ?? "")
        do {
            activity = try Activity<LiminalActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            self.kind = kind
            current = state
        } catch {
            activity = nil
            self.kind = nil
        }
    }

    func update(_ state: State) {
        guard let activity, state != current else { return }
        current = state
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    /// Shows the final state, then keeps it on the Lock Screen for a while so you can tap it.
    func finish(_ state: State, keepFor seconds: TimeInterval = 600) {
        guard let activity else { return }
        self.activity = nil
        kind = nil
        current = nil
        let policy: ActivityUIDismissalPolicy = seconds <= 0 ? .immediate : .after(Date().addingTimeInterval(seconds))
        Task { await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: policy) }
    }

    func endNow() {
        guard let activity else { return }
        self.activity = nil
        kind = nil
        current = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    // MARK: - Time in the background

    /// Asks iOS for extra time, so an answer or a creation finishes even if you leave the app.
    func beginBackgroundWork() {
        guard backgroundTask == .invalid else { return }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Lithium") {
            Task { @MainActor in LiveActivityController.shared.endBackgroundWork() }
        }
    }

    func endBackgroundWork() {
        guard backgroundTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
}
