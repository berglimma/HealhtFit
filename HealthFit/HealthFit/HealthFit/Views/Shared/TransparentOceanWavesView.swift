import SwiftUI

/// Ondas oceânicas animadas em camadas (fundo transparente, estilo “GIF”).
/// Usado em cards de Surf/Kitesurf — não bloqueia interações.
struct TransparentOceanWavesView: View {
    var tint: Color = Color(red: 0.35, green: 0.72, blue: 0.92)
    var baseOpacity: Double = 0.28
    var waveCount: Int = 3

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let paused = reduceMotion || scenePhase != .active
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: paused)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                guard size.width > 1, size.height > 1 else { return }
                for index in 0..<waveCount {
                    let path = Self.wavePath(
                        in: size,
                        time: t,
                        index: index
                    )
                    let opacity = baseOpacity * (0.45 + 0.2 * Double(index))
                    canvas.fill(
                        path,
                        with: .color(tint.opacity(opacity))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Onda seno preenchida até a base (camada semi-transparente).
    private static func wavePath(
        in size: CGSize,
        time: TimeInterval,
        index: Int
    ) -> Path {
        let amplitude = size.height * (0.06 + 0.035 * CGFloat(index))
        let baseY = size.height * (0.55 + 0.08 * CGFloat(index))
        let wavelength = size.width * (0.85 + 0.12 * CGFloat(index))
        let speed = 0.55 + 0.18 * Double(index)
        let phase = time * speed + Double(index) * 1.1
        let verticalBob = sin(time * 0.35 + Double(index)) * (size.height * 0.012)

        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height + 2))
        path.addLine(to: CGPoint(x: 0, y: baseY + verticalBob))

        let steps = max(Int(size.width / 8), 16)
        for step in 0...steps {
            let x = size.width * CGFloat(step) / CGFloat(steps)
            let angle = (x / max(wavelength, 1)) * .pi * 2 + phase
            let y = baseY + verticalBob + CGFloat(sin(angle)) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: size.width, y: size.height + 2))
        path.closeSubpath()
        return path
    }
}

#Preview("Ocean waves") {
    ZStack {
        Color.black
        TransparentOceanWavesView()
            .frame(height: 180)
    }
}
