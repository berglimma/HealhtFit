import SwiftUI

/// Linhas de vento animadas (partículas/tração) — estilo leve, sem assets pesados.
/// Usado no card Vento e maré (centro do card). Direção em graus meteorológicos (0° = N).
struct TransparentWindLinesView: View {
    /// Direção de onde o vento vem (0–360°).
    var directionDegrees: Double = 90
    var speedKmh: Double = 20
    var tint: Color = Color(red: 0.55, green: 0.82, blue: 0.95)
    var baseOpacity: Double = 0.55
    var lineCount: Int = 7

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let paused = reduceMotion || scenePhase != .active
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: paused)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                guard size.width > 1, size.height > 1 else { return }
                // Meteorologia: 0° = do Norte; fluxo visual = para onde o vento vai (+180°).
                let flowRadians = Angle(degrees: directionDegrees + 180).radians
                let dx = CGFloat(cos(flowRadians))
                let dy = CGFloat(sin(flowRadians))
                let speedFactor = min(max(speedKmh / 28, 0.35), 2.2)
                let lineLength = min(size.width, size.height) * (0.28 + 0.08 * CGFloat(speedFactor))

                for index in 0..<lineCount {
                    let path = Self.streakPath(
                        in: size,
                        time: t,
                        index: index,
                        count: lineCount,
                        dx: dx,
                        dy: dy,
                        length: lineLength,
                        speedFactor: speedFactor
                    )
                    let opacity = baseOpacity * (0.35 + 0.12 * Double(index % 4))
                    canvas.stroke(
                        path,
                        with: .color(tint.opacity(opacity)),
                        style: StrokeStyle(
                            lineWidth: 1.6 + CGFloat(index % 3) * 0.35,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }

                for p in 0..<5 {
                    let progress = Self.particleProgress(time: t, index: p, speedFactor: speedFactor)
                    let origin = Self.laneOrigin(in: size, index: p, count: 5)
                    let point = CGPoint(
                        x: origin.x + dx * progress * size.width * 0.55,
                        y: origin.y + dy * progress * size.height * 0.55
                    )
                    let r: CGFloat = 1.4 + CGFloat(p % 2)
                    let rect = CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)
                    canvas.fill(
                        Path(ellipseIn: rect),
                        with: .color(tint.opacity(baseOpacity * (0.5 + 0.1 * Double(p))))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func streakPath(
        in size: CGSize,
        time: TimeInterval,
        index: Int,
        count: Int,
        dx: CGFloat,
        dy: CGFloat,
        length: CGFloat,
        speedFactor: Double
    ) -> Path {
        let origin = laneOrigin(in: size, index: index, count: count)
        let travel = particleProgress(time: time, index: index, speedFactor: speedFactor)
        let mid = CGPoint(
            x: origin.x + dx * travel * size.width * 0.45,
            y: origin.y + dy * travel * size.height * 0.45
        )
        let half = length * 0.5
        let start = CGPoint(x: mid.x - dx * half, y: mid.y - dy * half)
        let end = CGPoint(x: mid.x + dx * half, y: mid.y + dy * half)
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        let ax = -dy
        let ay = dx
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - dx * 8 + ax * 4, y: end.y - dy * 8 + ay * 4))
        path.move(to: end)
        path.addLine(to: CGPoint(x: end.x - dx * 8 - ax * 4, y: end.y - dy * 8 - ay * 4))
        return path
    }

    private static func laneOrigin(in size: CGSize, index: Int, count: Int) -> CGPoint {
        let t = CGFloat(index + 1) / CGFloat(count + 1)
        return CGPoint(
            x: size.width * (0.12 + 0.76 * t),
            y: size.height * (0.2 + 0.55 * ((CGFloat(index % 3) + 1) / 4))
        )
    }

    private static func particleProgress(time: TimeInterval, index: Int, speedFactor: Double) -> CGFloat {
        let phase = time * (0.45 + 0.12 * Double(index % 3)) * speedFactor + Double(index) * 0.37
        let wrapped = phase.truncatingRemainder(dividingBy: 1.0)
        return CGFloat(wrapped < 0 ? wrapped + 1 : wrapped)
    }
}

#Preview {
    ZStack {
        Color.black
        TransparentWindLinesView(directionDegrees: 90, speedKmh: 24)
            .frame(height: 120)
    }
}
