import SwiftUI

struct PulsingHeartIconView: View {
    var size: CGFloat = 72
    var glowColor: Color = AppTheme.accent

    @State private var isPulsing = false

    private var containerSize: CGFloat { size * 1.34 }

    var body: some View {
        ZStack(alignment: .center) {
            pulseGlow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            Image("BrandHeart")
                .resizable()
                .renderingMode(.original)
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size * 0.9, height: size * 0.9)
                .scaleEffect(isPulsing ? 1.06 : 0.96)
                .shadow(
                    color: glowColor.opacity(isPulsing ? 0.55 : 0.22),
                    radius: isPulsing ? size * 0.14 : size * 0.06
                )
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(width: containerSize, height: containerSize, alignment: .center)
        .background(Color.clear)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    private var pulseGlow: some View {
        ZStack(alignment: .center) {
            Circle()
                .fill(glowColor.opacity(isPulsing ? 0.34 : 0.14))
                .frame(width: size * 1.22, height: size * 1.22)
                .scaleEffect(isPulsing ? 1.1 : 0.9)
                .blur(radius: size * 0.07)

            Circle()
                .stroke(glowColor.opacity(isPulsing ? 0.6 : 0.28), lineWidth: max(2, size * 0.035))
                .frame(width: size * 1.08, height: size * 1.08)
                .scaleEffect(isPulsing ? 1.06 : 0.94)
        }
        .frame(width: size * 1.22, height: size * 1.22, alignment: .center)
    }
}

#Preview {
    ZStack {
        AppTheme.background.ignoresSafeArea()
        PulsingHeartIconView(size: 88)
    }
}
