import SwiftUI

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
