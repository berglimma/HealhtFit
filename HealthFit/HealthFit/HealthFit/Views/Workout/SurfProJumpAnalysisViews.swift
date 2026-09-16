import Charts
import SwiftUI
import UIKit

/// Análise de saltos no estilo SurfPro: métricas, curva altura×tempo e barras comparativas.
struct SurfProJumpAnalysisSection: View {
    let jumps: [SurfJumpEvent]
    var windAngleDegrees: Double? = nil
    var isKitesurf: Bool = true
    var accent: Color = AppTheme.accent
    var profileImage: UIImage? = nil

    @State private var selectedJumpID: UUID?

    private var cards: [SurfProJumpCardModel] {
        SurfProJumpCardModel.make(from: jumps, windAngleDegrees: windAngleDegrees)
    }

    private var selected: SurfProJumpCardModel? {
        if let selectedJumpID, let match = cards.first(where: { $0.id == selectedJumpID }) {
            return match
        }
        return cards.max(by: { $0.heightMeters < $1.heightMeters })
    }

    var body: some View {
        if cards.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                header
                jumpTable
                if let selected {
                    detailCard(selected)
                }
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .onAppear {
                if selectedJumpID == nil {
                    selectedJumpID = selected?.id
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: isKitesurf ? CardioExercise.kitesurfSystemImage : CardioExercise.surfSystemImage)
                .foregroundStyle(accent)
            Text(isKitesurf ? "Análise de saltos (Kite)" : "Análise de saltos (Surf)")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Spacer()
            Text("\(cards.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(accent.opacity(0.15))
                .clipShape(Capsule())
        }
    }

    private var jumpTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("#").frame(width: 28, alignment: .leading)
                Text("Altura").frame(maxWidth: .infinity)
                Text("Ar").frame(width: 52)
                Text("Dist.").frame(width: 52)
                Text("Hora").frame(width: 48, alignment: .trailing)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            ForEach(cards) { card in
                Button {
                    selectedJumpID = card.id
                } label: {
                    HStack {
                        Text("\(card.index)")
                            .frame(width: 28, alignment: .leading)
                        Text(String(format: "%.2fm", card.heightMeters))
                            .frame(maxWidth: .infinity)
                        Text(String(format: "%.2fs", card.airtimeSeconds))
                            .frame(width: 52)
                        Text(String(format: "%.0fm", card.distanceMeters))
                            .frame(width: 52)
                        Text(card.timeLabel)
                            .frame(width: 48, alignment: .trailing)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(card.id == selected?.id ? accent.opacity(0.22) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func detailCard(_ card: SurfProJumpCardModel) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Salto \(card.index)")
                    .font(.title3.weight(.bold))
                Text(card.timeLabel)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(card.directionLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                Spacer()
            }

            heightTimeChart(for: card)

            SurfProJump3DSceneView(
                card: card,
                profileImage: profileImage,
                accent: accent
            )
            .frame(height: 230)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12
            ) {
                metricBlock(String(format: "%.1f m", card.heightMeters), "Altura")
                metricBlock(String(format: "%.1f s", card.airtimeSeconds), "Tempo no ar")
                metricBlock(String(format: "%.0f m", card.distanceMeters), "Distância")
                metricBlock(String(format: "%.0f kmh", card.maxSpeedKmh), "Vel. máxima")
            }

            VStack(alignment: .leading, spacing: 6) {
                Label(
                    String(format: "%.0f kmh Velocidade na abordagem", card.approachSpeedKmh),
                    systemImage: "gauge.with.dots.needle.33percent"
                )
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

                HStack(spacing: 6) {
                    Image(systemName: "wind")
                    Text(card.windSummary)
                    Text("•")
                    Text(card.windQualityLabel)
                        .foregroundStyle(card.windQualityColor)
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            }

            Text(card.insight)
                .font(.caption)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.22))
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(card.windQualityColor)
                                .frame(width: 3)
                        }
                )

            comparisonBars(selected: card)
        }
        .padding(12)
        .background(Color.black.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func heightTimeChart(for card: SurfProJumpCardModel) -> some View {
        let points = card.heightCurve
        let yMax = max(card.heightMeters * 1.08, 1)
        return Chart(points) { point in
            AreaMark(
                x: .value("s", point.seconds),
                y: .value("m", point.meters)
            )
            .foregroundStyle(accent.opacity(0.18))
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("s", point.seconds),
                y: .value("m", point.meters)
            )
            .foregroundStyle(accent)
            .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel {
                    if let s = value.as(Double.self) {
                        Text("\(Int(s.rounded()))")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel {
                    if let m = value.as(Double.self) {
                        Text(String(format: "%.0fm", m))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
        .chartXScale(domain: 0...(max(card.airtimeSeconds, 0.5)))
        .chartYScale(domain: 0...yMax)
        .chartXAxisLabel("Tempo (s)", position: .bottom, alignment: .trailing)
        .chartYAxisLabel("Altura (m)")
        .frame(height: 160)
        .padding(.top, 4)
    }

    private func comparisonBars(selected: SurfProJumpCardModel) -> some View {
        let maxH = max(cards.map(\.heightMeters).max() ?? 1, 0.5)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Comparativo de altura na sessão")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(cards) { card in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(card.id == selected.id ? accent : Color.white.opacity(0.18))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(10, CGFloat(card.heightMeters / maxH) * 56))
                        .onTapGesture { selectedJumpID = card.id }
                }
            }
            .frame(height: 60)
        }
    }

    private func metricBlock(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Models

struct SurfProJumpCardModel: Identifiable {
    struct CurvePoint: Identifiable, Hashable {
        var id: Double { seconds }
        var seconds: Double
        var meters: Double
    }

    let id: UUID
    let index: Int
    let timestamp: Date
    let heightMeters: Double
    let airtimeSeconds: Double
    let distanceMeters: Double
    let maxSpeedKmh: Double
    let approachSpeedKmh: Double
    let directionLabel: String
    let windAngleDegrees: Double
    let windQualityLabel: String
    let windQualityColor: Color
    let insight: String

    var timeLabel: String {
        timestamp.formatted(date: .omitted, time: .shortened)
    }

    var windSummary: String {
        let absAngle = abs(windAngleDegrees)
        if absAngle < 8 {
            return String(format: "%.0f° a favor do vento", absAngle)
        }
        if windAngleDegrees >= 0 {
            return String(format: "%.0f° upwind", windAngleDegrees)
        }
        return String(format: "%.0f° downwind", abs(windAngleDegrees))
    }

    var heightCurve: [CurvePoint] {
        let duration = max(airtimeSeconds, 0.4)
        let samples = max(12, Int(duration * 8))
        return (0...samples).map { i in
            let t = duration * Double(i) / Double(samples)
            // Parábola com pico em t = T/2.
            let meters = 4 * heightMeters * t * (duration - t) / (duration * duration)
            return CurvePoint(seconds: t, meters: max(0, meters))
        }
    }

    static func make(from jumps: [SurfJumpEvent], windAngleDegrees: Double?) -> [SurfProJumpCardModel] {
        let sorted = jumps.sorted { $0.timestamp < $1.timestamp }
        return sorted.enumerated().map { offset, jump in
            let airtime = jump.airtimeSeconds ?? Self.estimateAirtime(height: jump.heightMeters)
            let approach = Self.estimateApproachSpeedKmh(jump: jump, airtime: airtime)
            let distance = Self.estimateDistanceMeters(height: jump.heightMeters, airtime: airtime, approachKmh: approach)
            let maxSpeed = min(65, max(approach * 1.12, approach + jump.peakAccelerationG * 2.5))
            let angle = windAngleDegrees ?? Self.syntheticWindAngle(for: offset)
            let quality = Self.windQuality(angle: angle)
            let direction = offset % 2 == 0 ? "Direita" : "Esquerda"
            return SurfProJumpCardModel(
                id: jump.id,
                index: offset + 1,
                timestamp: jump.timestamp,
                heightMeters: jump.heightMeters,
                airtimeSeconds: airtime,
                distanceMeters: distance,
                maxSpeedKmh: maxSpeed,
                approachSpeedKmh: approach,
                directionLabel: direction,
                windAngleDegrees: angle,
                windQualityLabel: quality.label,
                windQualityColor: quality.color,
                insight: Self.insight(angle: angle, height: jump.heightMeters, airtime: airtime)
            )
        }
    }

    private static func estimateAirtime(height: Double) -> Double {
        // Queda livre aproximada ida+volta: t ≈ 2 * sqrt(2h/g)
        let g = 9.81
        return max(0.6, 2 * sqrt(max(0.1, 2 * height / g)) * 0.85)
    }

    private static func estimateApproachSpeedKmh(jump: SurfJumpEvent, airtime: Double) -> Double {
        if jump.peakAccelerationG > 0.4 {
            return min(55, max(18, 22 + jump.peakAccelerationG * 7))
        }
        // Heurística a partir da altura/airtime.
        let fromHeight = 18 + jump.heightMeters * 1.8
        let fromAir = airtime > 0 ? (jump.heightMeters / airtime) * 12 : fromHeight
        return min(52, max(16, (fromHeight + fromAir) / 2))
    }

    private static func estimateDistanceMeters(height: Double, airtime: Double, approachKmh: Double) -> Double {
        let fromSpeed = (approachKmh / 3.6) * airtime
        let fromHeight = height * 4.2
        return max(6, (fromSpeed * 0.55 + fromHeight * 0.45))
    }

    private static func syntheticWindAngle(for index: Int) -> Double {
        let pattern: [Double] = [5, 0, -8, 12, 3, -4]
        return pattern[index % pattern.count]
    }

    private static func windQuality(angle: Double) -> (label: String, color: Color) {
        let absAngle = abs(angle)
        if absAngle <= 12 {
            return ("Bom", Color.green)
        }
        if absAngle <= 25 {
            return ("Ok", AppTheme.accentSecondary)
        }
        return ("Atenção", Color.orange)
    }

    private static func insight(angle: Double, height: Double, airtime: Double) -> String {
        let absAngle = abs(angle)
        if absAngle <= 8 {
            return "O teu rumo de approach foi quase perpendicular ao vento — ideal para lift máximo."
        }
        if absAngle <= 18 {
            return String(
                format: "Approach com %.0f° de ângulo ao vento. Bom compromisso entre lift (%.1f m) e controle no ar (%.1f s).",
                absAngle, height, airtime
            )
        }
        if angle > 0 {
            return "Approach mais upwind — útil para altura, mas exige edge firme na saída."
        }
        return "Approach mais downwind — favorece distância; cuida da velocidade na aterragem."
    }
}

// MARK: - Cena 3D do salto (estilo SurfPro)

/// Visualização em perspectiva: approach, cortina verde de altura, aterragem e foto no pico.
struct SurfProJump3DSceneView: View {
    let card: SurfProJumpCardModel
    var profileImage: UIImage?
    var accent: Color = AppTheme.accent

    private let sampleCount = 28

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let peak = peakScreenPoint(in: size)

            ZStack {
                coastalBackground

                Canvas { context, canvasSize in
                    drawGround(context: &context, size: canvasSize)
                    drawApproachPath(context: &context, size: canvasSize)
                    drawLandingPath(context: &context, size: canvasSize)
                    drawJumpCurtain(context: &context, size: canvasSize)
                    drawJumpTopEdge(context: &context, size: canvasSize)
                    drawGroundMarkers(context: &context, size: canvasSize)
                }

                takeoffMarker(in: size)
                landingMarker(in: size)
                peakBadge(at: peak)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(format: "Salto 3D de %.1f metros, %.1f segundos no ar", card.heightMeters, card.airtimeSeconds)
        )
    }

    private var coastalBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.18, green: 0.28, blue: 0.34),
                Color(red: 0.12, green: 0.22, blue: 0.28),
                Color(red: 0.10, green: 0.18, blue: 0.16),
                Color(red: 0.16, green: 0.24, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: Projection

    /// x: 0…1 ao longo do salto · y: altura normalizada · z: profundidade (-0.5…0.5)
    private func project(x: CGFloat, y: CGFloat, z: CGFloat, in size: CGSize) -> CGPoint {
        let depth = 1.15 + z * 0.42
        let scale = 1.0 / max(depth, 0.65)
        let screenX = size.width * 0.50
            + (x - 0.50) * size.width * 0.88 * scale
            + z * size.width * 0.22
        let screenY = size.height * 0.78
            - y * size.height * 0.58 * scale
            - z * size.height * 0.10
        return CGPoint(x: screenX, y: screenY)
    }

    private func heightAt(progress t: CGFloat) -> CGFloat {
        // Parábola com pico em t = 0.5
        let clamped = min(max(t, 0), 1)
        return 4 * clamped * (1 - clamped)
    }

    private func jumpX(progress t: CGFloat) -> CGFloat {
        0.22 + t * 0.56
    }

    private func peakScreenPoint(in size: CGSize) -> CGPoint {
        let top = project(x: jumpX(progress: 0.5), y: 1.0, z: 0, in: size)
        return CGPoint(x: top.x, y: top.y - 6)
    }

    // MARK: Drawing

    private func drawGround(context: inout GraphicsContext, size: CGSize) {
        var water = Path()
        water.move(to: project(x: -0.05, y: 0, z: -0.55, in: size))
        water.addLine(to: project(x: 1.05, y: 0, z: -0.55, in: size))
        water.addLine(to: project(x: 1.05, y: 0, z: 0.55, in: size))
        water.addLine(to: project(x: -0.05, y: 0, z: 0.55, in: size))
        water.closeSubpath()
        context.fill(water, with: .color(Color(red: 0.08, green: 0.22, blue: 0.28).opacity(0.85)))

        // Grid sutil no “chão”
        for i in 0...6 {
            let gz = -0.45 + CGFloat(i) * 0.15
            var line = Path()
            line.move(to: project(x: 0.02, y: 0, z: gz, in: size))
            line.addLine(to: project(x: 0.98, y: 0, z: gz, in: size))
            context.stroke(line, with: .color(.white.opacity(0.05)), lineWidth: 1)
        }
        for i in 0...8 {
            let gx = CGFloat(i) / 8
            var line = Path()
            line.move(to: project(x: gx, y: 0, z: -0.45, in: size))
            line.addLine(to: project(x: gx, y: 0, z: 0.45, in: size))
            context.stroke(line, with: .color(.white.opacity(0.04)), lineWidth: 1)
        }
    }

    private func drawApproachPath(context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let samples = 10
        for i in 0...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let x = 0.02 + t * 0.20
            let z = -0.08 + sin(t * .pi) * 0.04
            let p = project(x: x, y: 0.002, z: z, in: size)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        context.stroke(
            path,
            with: .color(Color.orange),
            style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawLandingPath(context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        let samples = 10
        for i in 0...samples {
            let t = CGFloat(i) / CGFloat(samples)
            let x = 0.78 + t * 0.20
            let z = 0.06 + sin(t * .pi) * 0.03
            let p = project(x: x, y: 0.002, z: z, in: size)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        context.stroke(
            path,
            with: .color(Color(red: 0.95, green: 0.82, blue: 0.25)),
            style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawJumpCurtain(context: inout GraphicsContext, size: CGSize) {
        let ribbonHalf: CGFloat = 0.045
        for i in 0..<sampleCount {
            let t0 = CGFloat(i) / CGFloat(sampleCount)
            let t1 = CGFloat(i + 1) / CGFloat(sampleCount)
            let h0 = heightAt(progress: t0)
            let h1 = heightAt(progress: t1)
            let x0 = jumpX(progress: t0)
            let x1 = jumpX(progress: t1)

            let g0a = project(x: x0, y: 0, z: -ribbonHalf, in: size)
            let g0b = project(x: x0, y: 0, z: ribbonHalf, in: size)
            let t0a = project(x: x0, y: h0, z: -ribbonHalf, in: size)
            let t0b = project(x: x0, y: h0, z: ribbonHalf, in: size)
            let g1a = project(x: x1, y: 0, z: -ribbonHalf, in: size)
            let g1b = project(x: x1, y: 0, z: ribbonHalf, in: size)
            let t1a = project(x: x1, y: h1, z: -ribbonHalf, in: size)
            let t1b = project(x: x1, y: h1, z: ribbonHalf, in: size)

            // Face frontal da cortina
            var front = Path()
            front.move(to: g0a)
            front.addLine(to: g1a)
            front.addLine(to: t1a)
            front.addLine(to: t0a)
            front.closeSubpath()

            let lift = (h0 + h1) / 2
            let green = Color(red: 0.35, green: 0.92, blue: 0.45).opacity(0.18 + Double(lift) * 0.45)
            context.fill(front, with: .color(green))

            // Topo da fita (espessura)
            var top = Path()
            top.move(to: t0a)
            top.addLine(to: t0b)
            top.addLine(to: t1b)
            top.addLine(to: t1a)
            top.closeSubpath()
            context.fill(top, with: .color(Color(red: 0.55, green: 1.0, blue: 0.55).opacity(0.55)))

            // Lateral
            var side = Path()
            side.move(to: g0b)
            side.addLine(to: g1b)
            side.addLine(to: t1b)
            side.addLine(to: t0b)
            side.closeSubpath()
            context.fill(side, with: .color(Color(red: 0.20, green: 0.70, blue: 0.35).opacity(0.28)))
        }
    }

    private func drawJumpTopEdge(context: inout GraphicsContext, size: CGSize) {
        var edge = Path()
        for i in 0...sampleCount {
            let t = CGFloat(i) / CGFloat(sampleCount)
            let p = project(x: jumpX(progress: t), y: heightAt(progress: t), z: 0, in: size)
            if i == 0 { edge.move(to: p) } else { edge.addLine(to: p) }
        }
        context.stroke(
            edge,
            with: .color(Color(red: 0.55, green: 1.0, blue: 0.55)),
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawGroundMarkers(context: inout GraphicsContext, size: CGSize) {
        // sombras sob takeoff/landing
        let takeoff = project(x: jumpX(progress: 0), y: 0, z: 0, in: size)
        let landing = project(x: jumpX(progress: 1), y: 0, z: 0, in: size)
        let shadow = CGSize(width: 18, height: 8)
        context.fill(
            Path(ellipseIn: CGRect(x: takeoff.x - shadow.width / 2, y: takeoff.y - shadow.height / 2, width: shadow.width, height: shadow.height)),
            with: .color(.black.opacity(0.25))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: landing.x - shadow.width / 2, y: landing.y - shadow.height / 2, width: shadow.width, height: shadow.height)),
            with: .color(.black.opacity(0.25))
        )
    }

    private func takeoffMarker(in size: CGSize) -> some View {
        let p = project(x: jumpX(progress: 0), y: 0.02, z: 0, in: size)
        return markerCircle(systemName: "arrow.up", at: p)
    }

    private func landingMarker(in size: CGSize) -> some View {
        let p = project(x: jumpX(progress: 1), y: 0.02, z: 0, in: size)
        return markerCircle(systemName: "arrow.down", at: p)
    }

    private func markerCircle(systemName: String, at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.35, green: 0.75, blue: 0.95))
                .frame(width: 26, height: 26)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .position(point)
    }

    private func peakBadge(at point: CGPoint) -> some View {
        VStack(spacing: 4) {
            Group {
                if let profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Circle().fill(accent.opacity(0.85))
                        Image(systemName: "person.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.45), radius: 4, y: 2)

            Text(String(format: "%.1f m", card.heightMeters))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
        }
        .position(x: point.x, y: point.y - 28)
    }
}
