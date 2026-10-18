import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

typealias LiminalContext = ActivityViewContext<LiminalActivityAttributes>
typealias LiminalPhase = LiminalActivityAttributes.Phase

/// Lithium in the Dynamic Island and on the Lock Screen:
/// a live conversation you can pause or end, and images, videos or long answers with their progress.
struct LiminalLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiminalActivityAttributes.self) { context in
            LockScreenActivity(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    MarkIcon(size: 26, color: .white)
                        .padding(.leading, 6)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TrailingInfo(context: context, ink: Tone.islandGray)
                        .padding(.trailing, 6)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    TitleLine(state: context.state, ink: .white)
                        .padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ActivityDetails(context: context, ink: .white, secondary: Tone.islandGray, buttonFill: Color.white.opacity(0.16))
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                }
            } compactLeading: {
                MarkIcon(size: 15, color: .white)
                    .padding(.leading, 2)
            } compactTrailing: {
                StatusIcon(state: context.state)
            } minimal: {
                StatusIcon(state: context.state)
            }
            .widgetURL(context.attributes.link)
            .keylineTint(Tone.color(for: context.state.phase))
        }
    }
}

// MARK: - Lock Screen

struct LockScreenActivity: View {
    let context: LiminalContext
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        let ink = dark ? Tone.darkInk : Tone.lightInk
        let secondary = dark ? Tone.darkInk3 : Tone.lightInk3
        HStack(alignment: .top, spacing: 12) {
            MarkIcon(size: 28, color: ink)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TitleLine(state: context.state, ink: ink)
                    Spacer(minLength: 6)
                    TrailingInfo(context: context, ink: secondary)
                }
                ActivityDetails(context: context, ink: ink, secondary: secondary,
                                buttonFill: dark ? Color.white.opacity(0.14) : Color.black.opacity(0.07))
            }
        }
        .padding(16)
        .activityBackgroundTint(dark ? Tone.darkBackground : Tone.lightBackground)
        .activitySystemActionForegroundColor(ink)
    }
}

// MARK: - Pieces

struct MarkIcon: View {
    var size: CGFloat
    var color: Color

    var body: some View {
        LogoMark()
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityLabel("Liminal")
    }
}

/// A traffic-light dot and what Lithium is doing.
struct TitleLine: View {
    let state: LiminalActivityAttributes.ContentState
    var ink: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Tone.color(for: state.phase))
                .frame(width: 7, height: 7)
            Text(state.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ink)
                .lineLimit(1)
        }
    }
}

/// The conversation's timer, the seconds left for a creation, or a check when it is ready.
struct TrailingInfo: View {
    let context: LiminalContext
    var ink: Color

    var body: some View {
        let state = context.state
        switch state.phase {
        case .listening, .thinking, .speaking, .muted:
            Text(state.startedAt, style: .timer)
                .font(.footnote.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(ink)
                .multilineTextAlignment(.trailing)
                .frame(width: 50, alignment: .trailing)
        case .working:
            if let end = state.endsAt, end > state.startedAt {
                Text(timerInterval: state.startedAt...end, countsDown: true)
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 44, alignment: .trailing)
            }
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Tone.green)
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Tone.red)
        }
    }
}

/// The text below the title, plus the progress bar or the conversation buttons.
struct ActivityDetails: View {
    let context: LiminalContext
    var ink: Color
    var secondary: Color
    var buttonFill: Color

    var body: some View {
        let state = context.state
        VStack(alignment: .leading, spacing: 10) {
            if !state.detail.isEmpty {
                Text(state.detail)
                    .font(.footnote)
                    .foregroundStyle(secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if context.attributes.kind == .voice {
                HStack(spacing: 10) {
                    Button(intent: ToggleMuteIntent()) {
                        Label(state.phase == .muted ? "Activar" : "Pausar",
                              systemImage: state.phase == .muted ? "mic.fill" : "mic.slash.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(buttonFill, in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button(intent: EndVoiceIntent()) {
                        Label("Terminar", systemImage: "xmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Tone.red, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else if state.phase == .working, let end = state.endsAt, end > state.startedAt {
                ProgressView(timerInterval: state.startedAt...end, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(Tone.yellow)
            } else if state.phase == .done {
                Text(openHint)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Tone.green)
            }
        }
    }

    private var openHint: String {
        switch context.attributes.kind {
        case .image: return "Toca para verla"
        case .video: return "Toca para verlo"
        case .answer, .voice: return "Toca para leerla"
        }
    }
}

/// The small icon on the right of the Dynamic Island.
struct StatusIcon: View {
    let state: LiminalActivityAttributes.ContentState

    var body: some View {
        switch state.phase {
        case .working:
            if let end = state.endsAt, end > state.startedAt {
                ProgressView(timerInterval: state.startedAt...end, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(Tone.yellow)
                .frame(width: 18, height: 18)
            } else {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Tone.yellow)
            }
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Tone.green)
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Tone.red)
        case .listening:
            Image(systemName: "waveform")
                .foregroundStyle(Tone.green)
        case .thinking:
            Image(systemName: "ellipsis")
                .foregroundStyle(Tone.yellow)
        case .speaking:
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(Tone.green)
        case .muted:
            Image(systemName: "mic.slash.fill")
                .foregroundStyle(Tone.red)
        }
    }
}

// MARK: - Colors

/// Liminal's grays, with the macOS traffic lights only for status.
enum Tone {
    static let green = Color(red: 0x28 / 255, green: 0xC8 / 255, blue: 0x40 / 255)
    static let yellow = Color(red: 0xFE / 255, green: 0xBC / 255, blue: 0x2E / 255)
    static let red = Color(red: 0xFF / 255, green: 0x5F / 255, blue: 0x57 / 255)

    static let islandGray = Color(red: 0x98 / 255, green: 0x98 / 255, blue: 0x9D / 255)
    static let darkBackground = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)
    static let lightBackground = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255)
    static let darkInk = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255)
    static let lightInk = Color(red: 0x1D / 255, green: 0x1D / 255, blue: 0x1F / 255)
    static let darkInk3 = Color(red: 0x98 / 255, green: 0x98 / 255, blue: 0x9D / 255)
    static let lightInk3 = Color(red: 0x6E / 255, green: 0x6E / 255, blue: 0x73 / 255)

    /// Green when on or done, yellow while working, red when paused or cancelled.
    static func color(for phase: LiminalPhase) -> Color {
        switch phase {
        case .listening, .speaking, .done: return green
        case .thinking, .working: return yellow
        case .muted, .cancelled: return red
        }
    }
}
