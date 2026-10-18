import Foundation
import AppIntents
import ActivityKit

/// What the buttons in the Dynamic Island and on the Lock Screen do.
/// The app fills these in while a live conversation is running.
@MainActor
enum LiveControls {
    static var endVoice: (() -> Void)?
    static var toggleMute: (() -> Void)?
}

/// Ends the live conversation without opening the app. Live Activity intents run inside the app.
struct EndVoiceIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Terminar la conversación"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        let handled = await MainActor.run { () -> Bool in
            guard let end = LiveControls.endVoice else { return false }
            end()
            return true
        }
        if !handled {
            // The app had closed: just take the activity away.
            for activity in Activity<LiminalActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        return .result()
    }
}

/// Pauses or resumes the microphone during a live conversation.
struct ToggleMuteIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pausar o activar el micrófono"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        await MainActor.run { LiveControls.toggleMute?() }
        return .result()
    }
}
