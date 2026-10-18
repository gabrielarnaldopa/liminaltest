import SwiftUI
import UIKit

// MARK: - Formatting (Spanish, with "." for thousands and "," for decimals)

enum Fmt {
    static let locale = Locale(identifier: "es")

    private static func numberFormatter(fractionDigits: ClosedRange<Int>) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSize = 3
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.minimumFractionDigits = fractionDigits.lowerBound
        formatter.maximumFractionDigits = fractionDigits.upperBound
        return formatter
    }

    /// "Bs 10.810,36"
    static func bolivares(_ value: Double) -> String {
        "Bs " + (numberFormatter(fractionDigits: 2...2).string(from: NSNumber(value: value)) ?? "\(value)")
    }

    /// "11,00"
    static func decimal2(_ value: Double) -> String {
        numberFormatter(fractionDigits: 2...2).string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func int(_ value: Int) -> String {
        numberFormatter(fractionDigits: 0...0).string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func decimal(_ value: Double) -> String {
        numberFormatter(fractionDigits: 1...1).string(from: NSNumber(value: value)) ?? "\(value)"
    }

    /// "$11" for whole amounts, "$6,60" otherwise.
    static func money(_ value: Double) -> String {
        let whole = value.rounded() == value
        let text = numberFormatter(fractionDigits: whole ? 0...0 : 2...2).string(from: NSNumber(value: value)) ?? "\(value)"
        return "$" + text
    }

    /// "hace 2 horas", "dentro de 3 horas"
    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = locale
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// "14 nov 2026"
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().locale(locale))
    }

    /// "14 nov 2026, 18:30"
    static func dayTime(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(locale))
    }
}

// MARK: - Small pieces

/// A status label with a traffic-light dot.
struct StatusChip: View {
    let text: String
    let level: StatusLevel

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(level.color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(Palette.ink2)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Palette.sunk, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

struct RoleBadge: View {
    var body: some View {
        Text("Admin")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Palette.ink2)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Palette.sel, in: Capsule())
            .accessibilityLabel("Administración")
    }
}

struct Avatar: View {
    let name: String
    var size: CGFloat = 32

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(Palette.bg)
            .frame(width: size, height: size)
            .background(Palette.ink, in: Circle())
            .accessibilityHidden(true)
    }

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0) }
        let text = letters.joined().uppercased()
        return text.isEmpty ? "?" : text
    }
}

struct PulsingDot: View {
    var color: Color = Palette.yellow
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(on ? 1 : 0.35)
            .scaleEffect(on ? 1 : 0.8)
            .onAppear {
                if reduceMotion {
                    on = true
                } else {
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { on = true }
                }
            }
            .accessibilityHidden(true)
    }
}

struct AttachmentChip: View {
    let name: String
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Palette.ink3)
            Text(name)
                .lineLimit(1)
                .truncationMode(.middle)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.ink3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quitar \(name)")
            }
        }
        .font(.footnote)
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Palette.sunk, in: Capsule())
        .frame(maxWidth: 240, alignment: .leading)
    }

    private var icon: String {
        switch (name as NSString).pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "png", "jpg", "jpeg", "heic", "gif", "webp": return "photo"
        case "xlsx", "xls", "csv", "numbers": return "tablecells"
        default: return "doc"
        }
    }
}

/// A file in the composer or in a message, with what Lithium read from it.
struct FileChip: View {
    let attachment: Attachment
    var onOpen: (() -> Void)? = nil
    var onRemove: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let data = attachment.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else if attachment.isReading {
                ProgressView()
                    .frame(width: 30, height: 30)
            } else {
                Image(systemName: attachment.kind.icon)
                    .foregroundStyle(Palette.ink3)
                    .frame(width: 30, height: 30)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.name)
                    .font(.footnote.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(attachment.detail)
                    .font(.caption2)
                    .foregroundStyle(attachment.failed ? Palette.redText : Palette.ink3)
                    .lineLimit(1)
            }
            if let onOpen {
                Button(action: onOpen) {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.ink3)
                .accessibilityLabel("Abrir \(attachment.name) en el editor")
            }
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.ink3)
                .accessibilityLabel("Quitar \(attachment.name)")
            }
        }
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Palette.sunk, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(maxWidth: 260, alignment: .leading)
    }
}

/// A short message with a traffic-light icon: green for good news, yellow for warnings, red for blocks.
struct NoticeView: View {
    let level: StatusLevel
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(level.color)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch level {
        case .good: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .bad: return "xmark.octagon.fill"
        }
    }

    private var background: Color {
        switch level {
        case .good: return Palette.sunk
        case .warn: return Palette.yellowTint
        case .bad: return Palette.redTint
        }
    }
}

/// Usage bar: green under 70%, yellow from 70%, red from 90%.
struct UsageMeter: View {
    let title: String
    let used: Int
    let cap: Int
    var detail: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 8)
                Text("\(Fmt.int(used)) de \(Fmt.int(cap))")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink3)
            }
            ProgressView(value: fraction)
                .tint(StatusLevel.forUsage(used: used, cap: cap).color)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.ink3)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var fraction: Double {
        guard cap > 0 else { return 1 }
        return min(1, Double(used) / Double(cap))
    }
}

/// Warns before the person hits a limit, and explains what to do when they do.
struct LimitNotice: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        let tier = store.state.prefs.tier
        if let block = store.usageBlock(tier: tier) {
            NoticeView(level: .bad, text: block)
        } else if tier == .adv && store.sessionPercent >= 80 {
            NoticeView(level: .warn, text: "Llevas \(Int(store.sessionPercent))% de esta sesión. El modo rápido gasta mucho menos.")
        }
    }
}

struct ModeChip: View {
    let mode: ChatMode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: mode.icon)
                Text(mode.name)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selected ? Palette.bg : Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(selected ? Palette.ink : Palette.raised, in: Capsule())
            .overlay(Capsule().stroke(selected ? Color.clear : Palette.line))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(mode.summary)
    }
}

/// A white (or dark gray) rounded box with an optional title.
struct Card<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Palette.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// The three macOS window dots, as decoration.
struct TrafficLights: View {
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(Palette.red)
            Circle().fill(Palette.yellow)
            Circle().fill(Palette.green)
        }
        .frame(width: 52, height: 12)
        .accessibilityHidden(true)
    }
}

// MARK: - Toast

struct ToastView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ZStack {
            if let text = store.notice {
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.bg)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .id(text)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.notice)
        .allowsHitTesting(false)
        .onChange(of: store.notice) { _, text in
            if let text {
                AccessibilityNotification.Announcement(text).post()
            }
        }
    }
}

// MARK: - Model menu and toolbar

/// The menu at the top: model (Rápido or Avanzado), effort and engine.
struct ModelMenu: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Menu {
            Section(Brand.modelName) {
                Picker("Modelo", selection: $store.state.prefs.tier) {
                    ForEach(Tier.allCases) { tier in
                        Label(tier.name, systemImage: tier.icon).tag(tier)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            if store.state.prefs.tier == .adv {
                Section("Esfuerzo") {
                    Picker("Esfuerzo", selection: $store.state.prefs.effort) {
                        ForEach(Effort.allCases) { effort in
                            Text(effort == .alto ? "Alto · cuenta doble" : effort.name).tag(effort)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            Section {
                Text("\(Brand.modelName) combina varios motores y elige el mejor para cada mensaje.")
            }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Palette.ink)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.ink3)
            }
        }
        .accessibilityLabel("Modelo: \(title)")
    }

    private var title: String {
        let prefs = store.state.prefs
        return "\(Brand.modelName) \(prefs.tier.name)"
    }
}

struct LiminalToolbar: ViewModifier {
    @Environment(AppStore.self) private var store
    var showsTemporary = true

    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Palette.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ModelMenu()
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if showsTemporary {
                        Button {
                            store.toggleTemporary()
                        } label: {
                            Image(systemName: store.isTemporary ? "eye.slash.circle.fill" : "eye.slash")
                                .foregroundStyle(store.isTemporary ? Palette.yellowText : Palette.ink)
                        }
                        .accessibilityLabel(store.isTemporary ? "Desactivar chat temporal" : "Activar chat temporal")
                    }
                    Button {
                        store.newChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Nuevo chat")
                }
            }
    }
}

extension View {
    func liminalToolbar(showsTemporary: Bool = true) -> some View {
        modifier(LiminalToolbar(showsTemporary: showsTemporary))
    }

    /// Lists and forms on the gray background of the palette.
    func liminalList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Palette.side)
    }

    /// Text field box used on the sign-in screen.
    func inputBox(invalid: Bool) -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(invalid ? Palette.red : Palette.line, lineWidth: invalid ? 1.5 : 1)
            )
    }
}

// MARK: - Flow layout

/// Places views in rows, centered, wrapping to the next row when they do not fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(width: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        let contentWidth = rows.map(\.width).max() ?? 0
        let width = maxWidth.isFinite ? maxWidth : contentWidth
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX + max(0, (bounds.width - row.width) / 2)
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width && !current.indices.isEmpty {
                rows.append(current)
                current = Row(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}
