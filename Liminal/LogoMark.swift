import SwiftUI

/// The Liminal mark: an L, a b and a corner interlocked on an 8-unit grid (792 × 792 units).
struct LogoMark: Shape {
    enum Piece { case l, b, corner }

    /// `nil` draws the whole mark.
    let piece: Piece?

    init(piece: Piece? = nil) {
        self.piece = piece
    }

    nonisolated func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 792
        let originX = rect.midX - 396 * scale
        let originY = rect.midY - 396 * scale
        var path = Path()

        func polygon(_ points: [(CGFloat, CGFloat)]) {
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: originX + first.0 * scale, y: originY + first.1 * scale))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: originX + point.0 * scale, y: originY + point.1 * scale))
            }
            path.closeSubpath()
        }

        if piece == nil || piece == .l {
            polygon([(0, 0), (97, 0), (97, 695), (792, 695), (792, 792), (0, 792)])
        }
        if piece == nil || piece == .b {
            polygon([(198, 0), (295, 0), (295, 198), (594, 198), (594, 594), (198, 594)])
            // The hole is drawn in the opposite direction, so it stays empty.
            polygon([(295, 295), (295, 497), (497, 497), (497, 295)])
        }
        if piece == nil || piece == .corner {
            polygon([(396, 0), (792, 0), (792, 594), (695, 594), (695, 97), (396, 97)])
        }
        return path
    }
}

/// The mark builds itself from its three pieces when it appears.
struct AssemblingLogo: View {
    var size: CGFloat
    @State private var assembled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            LogoMark(piece: .l)
                .offset(x: assembled ? 0 : -size * 0.12, y: assembled ? 0 : size * 0.12)
            LogoMark(piece: .b)
                .offset(y: assembled ? 0 : -size * 0.15)
            LogoMark(piece: .corner)
                .offset(x: assembled ? 0 : size * 0.15, y: assembled ? 0 : -size * 0.08)
        }
        .foregroundStyle(Palette.ink)
        .frame(width: size, height: size)
        .onAppear {
            if reduceMotion {
                assembled = true
            } else {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) { assembled = true }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 24) {
        LogoMark().frame(width: 80, height: 80)
        AssemblingLogo(size: 64)
    }
    .padding()
}
