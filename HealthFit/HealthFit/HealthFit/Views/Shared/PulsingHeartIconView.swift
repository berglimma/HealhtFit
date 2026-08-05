import SwiftUI

struct PulsingHeartIconView: View {
    var size: CGFloat = 72
    var glowColor: Color = AppTheme.accent

    @State private var isPulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var containerSize: CGFloat { size * 1.34 }
    private var shouldAnimate: Bool {
        !reduceMotion && scenePhase == .active
    }

    var body: some View {
        ZStack(alignment: .center) {
            pulseGlow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            Image("BrandHeart")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: size * 0.9, height: size * 0.9)
                .scaleEffect(isPulsing && shouldAnimate ? 1.06 : 1.0)
                .shadow(
                    color: glowColor.opacity(isPulsing && shouldAnimate ? 0.45 : 0.22),
                    radius: isPulsing && shouldAnimate ? size * 0.12 : size * 0.06
                )
                .allowsHitTesting(false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(width: containerSize, height: containerSize, alignment: .center)
        .background(Color.clear)
        .onAppear {
            guard shouldAnimate else { return }
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                isPulsing = false
            } else if shouldAnimate {
                withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }

    private var pulseGlow: some View {
        ZStack(alignment: .center) {
            Circle()
                .fill(glowColor.opacity(isPulsing && shouldAnimate ? 0.28 : 0.12))
                .frame(width: size * 1.22, height: size * 1.22)
                .scaleEffect(isPulsing && shouldAnimate ? 1.08 : 0.95)

            Circle()
                .stroke(glowColor.opacity(isPulsing && shouldAnimate ? 0.5 : 0.22), lineWidth: max(2, size * 0.035))
                .frame(width: size * 1.08, height: size * 1.08)
                .scaleEffect(isPulsing && shouldAnimate ? 1.04 : 0.96)
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

struct RepeatingBounceSymbolEffect: ViewModifier {
    let speed: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.symbolEffect(.bounce, options: .repeating.speed(speed))
        } else {
            LegacyRepeatingBounceEffect(speed: speed, content: content)
        }
    }
}

struct RepeatingPulseSymbolEffect: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.symbolEffect(.pulse, options: .repeating)
        } else {
            LegacyRepeatingPulseEffect(content: content)
        }
    }
}

private struct LegacyRepeatingBounceEffect<Content: View>: View {
    let speed: Double
    let content: Content
    @State private var isAnimating = false

    var body: some View {
        content
            .scaleEffect(isAnimating ? 1.08 : 0.95)
            .animation(
                .easeInOut(duration: max(0.45, 1.1 / speed))
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

private struct LegacyRepeatingPulseEffect<Content: View>: View {
    let content: Content
    @State private var isAnimating = false

    var body: some View {
        content
            .opacity(isAnimating ? 1 : 0.45)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}
