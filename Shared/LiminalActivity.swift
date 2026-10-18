import Foundation
import ActivityKit

/// What Liminal shows in the Dynamic Island and on the Lock Screen while Lithium works.
/// The app starts and updates it; the LiminalWidgets extension draws it.
struct LiminalActivityAttributes: ActivityAttributes {
    enum Kind: String, Codable, Hashable {
        /// A live spoken conversation.
        case voice
        /// An image or a video being created.
        case image, video
        /// A long answer in the advanced mode.
        case answer
    }

    enum Phase: String, Codable, Hashable {
        // Live conversation
        case listening, thinking, speaking, muted
        // Creations and answers
        case working, done, cancelled
    }

    struct ContentState: Codable, Hashable {
        var phase: Phase
        var title: String
        var detail: String
        /// When the conversation or the task started.
        var startedAt: Date
        /// When an image, a video or an answer should be ready, for the progress bar.
        var endsAt: Date?
    }

    var kind: Kind
    /// The chat that opens when you tap the activity. Empty for a live conversation.
    var chatID: String

    /// Opens the right screen in the app when you tap the activity.
    var link: URL? {
        if kind == .voice || chatID.isEmpty { return URL(string: "liminal://voice") }
        return URL(string: "liminal://chat/\(chatID)")
    }
}

extension String {
    /// Short enough for the Dynamic Island, which has little room. ActivityKit also limits the size of each update.
    func clipped(_ limit: Int = 140) -> String {
        let flat = replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return flat.count > limit ? String(flat.prefix(limit - 1)) + "…" : flat
    }
}
