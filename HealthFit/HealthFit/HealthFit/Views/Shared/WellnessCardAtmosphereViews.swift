import SwiftUI

/// Céu noturno animado para o card de sono (estrelas, lua e brilho).
struct SleepNightAtmosphereView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let paused = reduceMotion || scenePhase != .active
        TimelineView(.animation(minimumInterval: paused ? 1 : 1.0 / 12.0, paused: paused)) { context in
            let t = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                guard size.width > 1, size.height > 1 else { return }
                Self.drawSky(in: &canvas, size: size)
                Self.drawMoon(in: &canvas, size: size, time: t)
                Self.drawStars(in: &canvas, size: size, time: t)
                Self.drawZzz(in: &canvas, size: size, time: t)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func drawSky(in canvas: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        canvas.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.07, green: 0.09, blue: 0.22).opacity(0.92),
                    Color(red: 0.12, green: 0.10, blue: 0.28).opacity(0.55),
                    Color(red: 0.18, green: 0.12, blue: 0.32).opacity(0.18)
                ]),
                startPoint: CGPoint(x: size.width * 0.15, y: 0),
                endPoint: CGPoint(x: size.width * 0.9, y: size.height)
            )
        )
    }

    private static func drawMoon(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let glow = 0.88 + 0.08 * sin(time * 0.55)
        let center = CGPoint(x: size.width * 0.14, y: size.height * 0.20)
        let radius = min(size.width, size.height) * 0.16
        let glowRect = CGRect(
            x: center.x - radius * 2.4,
            y: center.y - radius * 2.4,
            width: radius * 4.8,
            height: radius * 4.8
        )
        canvas.fill(
            Path(ellipseIn: glowRect),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.85, green: 0.90, blue: 1.0).opacity(0.28 * glow),
                    Color(red: 0.45, green: 0.50, blue: 0.85).opacity(0.08),
                    .clear
                ]),
                center: center,
                startRadius: 2,
                endRadius: radius * 2.6
            )
        )
        let moonRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        canvas.fill(
            Path(ellipseIn: moonRect),
            with: .color(Color(red: 0.93, green: 0.95, blue: 1.0).opacity(0.55 * glow))
        )
        let crater = CGRect(
            x: center.x + radius * 0.15,
            y: center.y - radius * 0.2,
            width: radius * 0.28,
            height: radius * 0.22
        )
        canvas.fill(Path(ellipseIn: crater), with: .color(.white.opacity(0.18)))
    }

    private static func drawStars(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let seeds: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (0.08, 0.18, 1.4, 0.0),
            (0.22, 0.12, 1.1, 0.7),
            (0.34, 0.28, 1.7, 1.3),
            (0.48, 0.10, 1.2, 2.1),
            (0.61, 0.22, 1.5, 0.4),
            (0.12, 0.42, 1.0, 1.8),
            (0.27, 0.58, 1.3, 2.6),
            (0.41, 0.48, 1.6, 0.9),
            (0.55, 0.62, 1.1, 1.5),
            (0.70, 0.38, 1.4, 2.4),
            (0.78, 0.55, 1.2, 0.2),
            (0.18, 0.78, 1.0, 1.1),
            (0.63, 0.80, 1.3, 2.0),
            (0.88, 0.68, 1.1, 0.6),
            (0.05, 0.66, 1.2, 1.7)
        ]
        for (sx, sy, r, phase) in seeds {
            let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(time * 1.7 + phase))
            let point = CGPoint(x: size.width * sx, y: size.height * sy)
            let rect = CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)
            canvas.fill(
                Path(ellipseIn: rect),
                with: .color(Color.white.opacity(0.22 + 0.45 * twinkle))
            )
        }
    }

    private static func drawZzz(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let glyphs = ["z", "z", "Z"]
        for index in 0..<glyphs.count {
            let drift = sin(time * 0.7 + Double(index) * 1.4)
            let lift = CGFloat((time * 0.12 + Double(index) * 0.33).truncatingRemainder(dividingBy: 1))
            let x = size.width * (0.58 + 0.12 * CGFloat(index)) + CGFloat(drift) * 6
            let y = size.height * (0.28 - lift * 0.18)
            let opacity = 0.12 + 0.22 * (1 - lift)
            let text = Text(glyphs[index])
                .font(.system(size: 11 + CGFloat(index) * 3, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(opacity))
            canvas.draw(text, at: CGPoint(x: x, y: y))
        }
    }
}

/// Ondas e bolhas animadas para o card de água.
struct WaterRippleAtmosphereView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let paused = reduceMotion || scenePhase != .active
        TimelineView(.animation(minimumInterval: paused ? 1 : 1.0 / 12.0, paused: paused)) { context in
            let t = paused ? 0 : context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                guard size.width > 1, size.height > 1 else { return }
                Self.drawPool(in: &canvas, size: size)
                for index in 0..<3 {
                    canvas.fill(
                        Self.wavePath(in: size, time: t, index: index),
                        with: .color(
                            Color(red: 0.35, green: 0.72, blue: 1.0)
                                .opacity(0.16 + 0.10 * Double(index))
                        )
                    )
                }
                Self.drawBubbles(in: &canvas, size: size, time: t)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private static func drawPool(in canvas: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        canvas.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.08, green: 0.18, blue: 0.32).opacity(0.55),
                    Color(red: 0.10, green: 0.32, blue: 0.52).opacity(0.28),
                    Color(red: 0.12, green: 0.42, blue: 0.62).opacity(0.12)
                ]),
                startPoint: CGPoint(x: size.width * 0.5, y: 0),
                endPoint: CGPoint(x: size.width * 0.5, y: size.height)
            )
        )
    }

    private static func wavePath(in size: CGSize, time: TimeInterval, index: Int) -> Path {
        let amplitude = size.height * (0.045 + 0.03 * CGFloat(index))
        let baseY = size.height * (0.58 + 0.10 * CGFloat(index))
        let wavelength = size.width * (0.78 + 0.14 * CGFloat(index))
        let speed = 0.62 + 0.16 * Double(index)
        let phase = time * speed + Double(index) * 1.05
        let bob = sin(time * 0.4 + Double(index)) * (size.height * 0.01)

        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height + 2))
        path.addLine(to: CGPoint(x: 0, y: baseY + bob))
        let steps = max(Int(size.width / 8), 16)
        for step in 0...steps {
            let x = size.width * CGFloat(step) / CGFloat(steps)
            let angle = (x / max(wavelength, 1)) * .pi * 2 + phase
            let y = baseY + bob + CGFloat(sin(angle)) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: size.width, y: size.height + 2))
        path.closeSubpath()
        return path
    }

    private static func drawBubbles(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let bubbles: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (0.12, 6, 0.0, 9),
            (0.28, 4.5, 1.2, 11),
            (0.46, 5.5, 0.6, 8),
            (0.63, 3.8, 2.1, 12),
            (0.81, 5.0, 1.5, 10),
            (0.91, 3.4, 0.3, 13)
        ]
        for (sx, radius, phase, duration) in bubbles {
            let progress = ((time + phase).truncatingRemainder(dividingBy: duration)) / duration
            let x = size.width * sx + CGFloat(sin(time * 1.2 + phase)) * 4
            let y = size.height * (1.05 - CGFloat(progress) * 1.15)
            let fade = sin(progress * .pi)
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            canvas.stroke(
                Path(ellipseIn: rect),
                with: .color(Color.white.opacity(0.18 + 0.28 * fade)),
                lineWidth: 1
            )
            canvas.fill(
                Path(ellipseIn: rect),
                with: .color(Color(red: 0.55, green: 0.82, blue: 1.0).opacity(0.12 * fade))
            )
        }
    }
}

/// Copo de água (tumbler) — não usar xícara/`cup.and.saucer`.
struct WaterGlassGlyph: View {
    var tint: Color = Color(red: 0.45, green: 0.78, blue: 1.0)

    var body: some View {
        Canvas { canvas, size in
            let w = size.width
            let h = size.height
            var glass = Path()
            glass.move(to: CGPoint(x: w * 0.18, y: h * 0.08))
            glass.addLine(to: CGPoint(x: w * 0.82, y: h * 0.08))
            glass.addLine(to: CGPoint(x: w * 0.74, y: h * 0.92))
            glass.addLine(to: CGPoint(x: w * 0.26, y: h * 0.92))
            glass.closeSubpath()

            var water = Path()
            water.move(to: CGPoint(x: w * 0.24, y: h * 0.36))
            water.addQuadCurve(
                to: CGPoint(x: w * 0.76, y: h * 0.36),
                control: CGPoint(x: w * 0.50, y: h * 0.28)
            )
            water.addLine(to: CGPoint(x: w * 0.70, y: h * 0.86))
            water.addLine(to: CGPoint(x: w * 0.30, y: h * 0.86))
            water.closeSubpath()

            canvas.fill(water, with: .color(tint.opacity(0.88)))
            canvas.stroke(
                glass,
                with: .color(Color.white.opacity(0.95)),
                style: StrokeStyle(lineWidth: max(1.1, w * 0.08), lineJoin: .round)
            )
            var shine = Path()
            shine.move(to: CGPoint(x: w * 0.32, y: h * 0.16))
            shine.addLine(to: CGPoint(x: w * 0.36, y: h * 0.70))
            canvas.stroke(
                shine,
                with: .color(.white.opacity(0.6)),
                style: StrokeStyle(lineWidth: max(0.8, w * 0.06), lineCap: .round)
            )
        }
        .accessibilityHidden(true)
    }
}

#Preview("Sleep night") {
    SleepNightAtmosphereView()
        .frame(height: 220)
        .background(Color.black)
}

#Preview("Water ripples") {
    WaterRippleAtmosphereView()
        .frame(height: 220)
        .background(Color.black)
}
