import SwiftUI

/// The live conversation screen. Talk, pause, and Lithium answers out loud.
/// Everything said is saved in a chat, which opens when the conversation ends.
struct LiveVoiceView: View {
    @Environment(AppStore.self) private var store
    @State private var session = LiveVoiceSession()

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 8)

            Spacer(minLength: 16)

            Button {
                session.tapOrb()
            } label: {
                VoiceOrb(level: session.level, phase: session.phase)
                    .frame(width: 232, height: 232)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(orbHint)

            statusLine
                .padding(.top, 26)

            Spacer(minLength: 16)

            captions
                .frame(maxHeight: 210)

            if case .failed(let message) = session.phase {
                failure(message)
            } else {
                controls
                    .padding(.top, 18)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.bg)
        .task {
            let store = self.store
            session.speed = store.voiceSpeed
            session.thinkingDelay = store.serverReady ? 0 : 650
            session.answer = { said in await store.voiceTurn(said) }
            await session.begin()
        }
        .onChange(of: session.phase) { _, phase in
            if phase == .ended { store.endVoice() }
        }
        .onDisappear {
            session.end()
        }
    }

    // MARK: - Parts

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: store.mode.icon)
                Text(store.mode == .general ? "Conversación en vivo" : store.mode.name)
                    .lineLimit(1)
            }
            .font(.k(.footnote).weight(.medium))
            .foregroundStyle(Palette.ink2)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Palette.sunk, in: Capsule())

            Spacer(minLength: 8)

            if session.onDevice {
                Image(systemName: "lock.fill")
                    .font(.k(.caption))
                    .foregroundStyle(Palette.ink3)
                    .accessibilityLabel("Tu voz se procesa en tu iPhone")
            }
            Text(session.startedAt, style: .timer)
                .font(.k(.footnote).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(Palette.ink3)
                .accessibilityLabel("Tiempo de conversación")
        }
    }

    private var statusLine: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusTitle)
                    .font(.k(.headline))
                    .foregroundStyle(Palette.ink)
            }
            Text(statusHint)
                .font(.k(.footnote))
                .foregroundStyle(Palette.ink3)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var captions: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !session.heard.isEmpty {
                    Text(verbatim: session.heard)
                        .font(.k(.body))
                        .foregroundStyle(Palette.ink2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                }
                if !session.reply.isEmpty {
                    captionText
                        .font(.k(.title3).weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
        }
        .defaultScrollAnchor(.bottom)
    }

    /// Words already spoken in full ink, the rest in gray, like karaoke.
    private var captionText: Text {
        let text = session.reply
        guard session.phase == .speaking else {
            return Text(verbatim: text).foregroundColor(session.phase == .thinking ? Palette.ink3 : Palette.ink2)
        }
        let offset = min(max(session.spokenUpTo, 0), text.utf16.count)
        let split = String.Index(utf16Offset: offset, in: text)
        return Text(verbatim: String(text[..<split])).foregroundColor(Palette.ink)
            + Text(verbatim: String(text[split...])).foregroundColor(Palette.ink3)
    }

    private var controls: some View {
        HStack(alignment: .top, spacing: 34) {
            roundButton(session.micMuted ? "Activar" : "Pausar",
                        icon: session.micMuted ? "mic.slash.fill" : "mic.fill",
                        fill: session.micMuted ? Palette.redTint : Palette.sunk,
                        ink: session.micMuted ? Palette.redText : Palette.ink) {
                session.toggleMute()
            }
            .accessibilityLabel(session.micMuted ? "Activar el micrófono" : "Pausar el micrófono")

            roundButton("Terminar", icon: "xmark", size: 70, fill: Palette.red, ink: .white) {
                session.end()
            }
            .accessibilityLabel("Terminar la conversación")

            roundButton("Ver chat", icon: "text.bubble", fill: Palette.sunk, ink: Palette.ink) {
                session.end()
            }
            .accessibilityLabel("Terminar y ver la conversación escrita")
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Palette.red)
                Text(message)
                    .font(.k(.footnote))
                    .foregroundStyle(Palette.redText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.redTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                store.endVoice()
            } label: {
                Text("Cerrar")
                    .font(.k(.body).weight(.semibold))
                    .foregroundStyle(Palette.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 12)
    }

    private func roundButton(_ title: String, icon: String, size: CGFloat = 58, fill: Color, ink: Color,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.k(.title3).weight(.semibold))
                    .foregroundStyle(ink)
                    .frame(width: size, height: size)
                    .background(fill, in: Circle())
                Text(title)
                    .font(.k(.caption))
                    .foregroundStyle(Palette.ink3)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Words

    private var statusColor: Color {
        switch session.phase {
        case .listening, .speaking: return Palette.green
        case .starting, .thinking: return Palette.yellow
        case .muted, .failed, .ended: return Palette.red
        }
    }

    private var statusTitle: String {
        switch session.phase {
        case .starting: return "Preparando el micrófono…"
        case .listening: return session.heard.isEmpty ? "Te escucho" : "Te escucho…"
        case .thinking: return "Pensando…"
        case .speaking: return "\(Brand.modelName) te responde"
        case .muted: return "Micrófono en pausa"
        case .failed: return "No se pudo empezar"
        case .ended: return "Conversación terminada"
        }
    }

    private var statusHint: String {
        switch session.phase {
        case .listening: return "Habla con calma. Cuando hagas una pausa, Lithium responde."
        case .speaking: return "Toca el círculo para interrumpir."
        case .muted: return "Toca el círculo o el micrófono para seguir."
        case .thinking: return "Un momento."
        default: return "Sal de la app cuando quieras: la conversación sigue en la Isla Dinámica."
        }
    }

    private var orbHint: String {
        switch session.phase {
        case .speaking: return "Interrumpir a Lithium"
        case .listening: return "Enviar lo que dijiste"
        case .muted: return "Activar el micrófono"
        default: return "Conversación en vivo"
        }
    }
}

/// Gray circles that breathe with your voice and with Lithium's, with a status ring in traffic-light colors.
struct VoiceOrb: View {
    var level: Double
    var phase: LiveVoiceSession.Phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let amount = reduceMotion ? 0 : level
        ZStack {
            Circle()
                .fill(Palette.ink.opacity(0.05))
                .scaleEffect(0.86 + amount * 0.14)
            Circle()
                .fill(Palette.ink.opacity(0.08))
                .scaleEffect(0.72 + amount * 0.16)
            Circle()
                .fill(Palette.raised)
                .overlay(Circle().stroke(Palette.line, lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
                .scaleEffect(0.58 + amount * 0.05)

            if phase == .thinking && !reduceMotion {
                TimelineView(.animation) { context in
                    let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.1) / 1.1
                    Circle()
                        .trim(from: 0, to: 0.22)
                        .stroke(Palette.yellow, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(turn * 360))
                        .scaleEffect(0.66)
                }
            } else {
                Circle()
                    .stroke(ringColor, lineWidth: 2)
                    .scaleEffect(0.66 + amount * 0.05)
            }

            center
        }
        .animation(.easeOut(duration: 0.18), value: level)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var center: some View {
        switch phase {
        case .listening, .speaking:
            HStack(spacing: 6) {
                ForEach(Array(Self.bars.enumerated()), id: \.offset) { item in
                    Capsule()
                        .fill(Palette.ink)
                        .frame(width: 7, height: 10 + (reduceMotion ? 0.4 : level) * item.element)
                }
            }
        case .muted:
            Image(systemName: "mic.slash.fill")
                .font(.k(.title).weight(.semibold))
                .foregroundStyle(Palette.redText)
        default:
            LogoMark()
                .fill(Palette.ink)
                .frame(width: 46, height: 46)
        }
    }

    private static let bars: [Double] = [22, 40, 54, 40, 22]

    private var ringColor: Color {
        switch phase {
        case .listening, .speaking: return Palette.green
        case .muted, .failed: return Palette.red
        default: return Palette.line
        }
    }
}
