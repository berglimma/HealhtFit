import SwiftUI
import WatchKit

/// Faixa de desempenho do cronômetro Watch (corrida, caminhada, esteira, bikes e MTB).
enum WatchChronometerPerformance: Equatable {
    case unknown
    case paused
    case stopped
    case poor      // vermelho
    case fair      // laranja
    case good      // verde

    var accent: Color {
        switch self {
        case .unknown, .good:
            return Color(red: 0.20, green: 0.90, blue: 0.35)
        case .fair:
            return Color(red: 1.0, green: 0.55, blue: 0.12)
        case .poor:
            return Color(red: 0.95, green: 0.22, blue: 0.22)
        case .paused:
            return Color(red: 1.0, green: 0.78, blue: 0.15)
        case .stopped:
            return Color(red: 0.55, green: 0.55, blue: 0.58)
        }
    }

    var statusLabel: String {
        switch self {
        case .paused: return "Pausado"
        case .stopped: return "Parado"
        case .poor: return "Fraco"
        case .fair: return "Médio"
        case .good: return "Bom"
        case .unknown: return "Registrando"
        }
    }
}

/// Métricas de layout escaladas pelo tamanho da tela do Watch.
private struct WatchChronometerLayout {
    let diameter: CGFloat
    let tickWidth: CGFloat
    let tickHeight: CGFloat
    let tickActiveHeight: CGFloat
    let tickRadius: CGFloat
    let clockFont: CGFloat
    let statusFont: CGFloat
    let secondaryFont: CGFloat
    let titleFont: CGFloat
    let centerMaxWidth: CGFloat
    let metricsValueFont: CGFloat
    let metricsLabelFont: CGFloat
    let metricsSpacing: CGFloat
    let stackSpacing: CGFloat

    /// Usa a largura disponível (GeometryReader) ou a tela do device como fallback.
    static func make(availableWidth: CGFloat, availableHeight: CGFloat = .infinity) -> WatchChronometerLayout {
        let screen = WKInterfaceDevice.current().screenBounds
        let screenW = screen.width > 1 ? screen.width : 176
        let screenH = screen.height > 1 ? screen.height : 215

        let widthBudget = availableWidth > 1 ? availableWidth : screenW
        // Reserva espaço para título + BPM/Kcal + paddings na página.
        let heightBudget: CGFloat = {
            if availableHeight.isFinite, availableHeight > 1 {
                return availableHeight
            }
            // ~58% da altura útil da tela para o anel (preenche sem esmagar métricas).
            return screenH * 0.58
        }()

        // Diâmetro dominante: quase a largura da tela, limitado pela altura útil.
        let diameter = min(widthBudget * 0.96, heightBudget, screenW * 0.98)
            .clamped(to: 132...210)

        let scale = diameter / 148 // referência visual confortável

        return WatchChronometerLayout(
            diameter: diameter,
            tickWidth: max(2.8, 3.6 * scale),
            tickHeight: max(9, 12 * scale),
            tickActiveHeight: max(10, 14 * scale),
            tickRadius: diameter * 0.42,
            clockFont: max(26, min(42, 32 * scale)),
            statusFont: max(10, min(15, 12 * scale)),
            secondaryFont: max(12, min(18, 14 * scale)),
            titleFont: max(11, min(15, 12.5 * scale)),
            centerMaxWidth: diameter * 0.72,
            metricsValueFont: max(20, min(30, 24 * scale)),
            metricsLabelFont: max(10, min(13, 11 * scale)),
            metricsSpacing: max(20, min(36, 26 * scale)),
            stackSpacing: max(4, min(8, 6 * scale))
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

/// Cronômetro circular segmentado (60 ticks) — escala com o tamanho da tela do Watch.
struct WatchSegmentedChronometer: View {
    let elapsedSeconds: Int
    let performance: WatchChronometerPerformance
    var secondaryText: String = ""
    var statusOverride: String? = nil

    private let segmentCount = 60

    private var filledCount: Int {
        max(0, min(segmentCount, elapsedSeconds % segmentCount))
    }

    private var accent: Color { performance.accent }

    private var statusText: String {
        statusOverride ?? performance.statusLabel
    }

    var body: some View {
        GeometryReader { geo in
            let layout = WatchChronometerLayout.make(
                availableWidth: geo.size.width,
                availableHeight: geo.size.height
            )
            chronometerContent(layout: layout)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
        // Altura mínima generosa — em telas grandes o anel cresce de verdade.
        .frame(maxWidth: .infinity)
        .frame(height: WatchChronometerLayout.make(availableWidth: WKInterfaceDevice.current().screenBounds.width).diameter + 22)
    }

    @ViewBuilder
    private func chronometerContent(layout: WatchChronometerLayout) -> some View {
        VStack(spacing: layout.stackSpacing) {
            Label("Cronômetro", systemImage: "stopwatch.fill")
                .font(.system(size: layout.titleFont, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .labelStyle(.titleAndIcon)

            ZStack {
                ForEach(0..<segmentCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.16))
                        .frame(width: layout.tickWidth, height: layout.tickHeight)
                        .offset(y: -layout.tickRadius)
                        .rotationEffect(.degrees(Double(index) / Double(segmentCount) * 360))
                }

                ForEach(0..<filledCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(accent)
                        .frame(width: layout.tickWidth, height: layout.tickActiveHeight)
                        .offset(y: -layout.tickRadius)
                        .rotationEffect(.degrees(Double(index) / Double(segmentCount) * 360))
                }

                VStack(spacing: max(1, layout.stackSpacing * 0.35)) {
                    Text(formatClock(elapsedSeconds))
                        .font(.system(size: layout.clockFont, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                        .minimumScaleFactor(0.55)
                        .lineLimit(1)
                        .contentTransition(.numericText())

                    Text(statusText)
                        .font(.system(size: layout.statusFont, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if !secondaryText.isEmpty {
                        Text(secondaryText)
                            .font(.system(size: layout.secondaryFont, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .frame(maxWidth: layout.centerMaxWidth)
            }
            .frame(width: layout.diameter, height: layout.diameter)
            .animation(.easeInOut(duration: 0.28), value: filledCount)
            .animation(.easeInOut(duration: 0.35), value: performance)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatClock(_ seconds: Int) -> String {
        let total = max(seconds, 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

/// BPM + Kcal no rodapé — tipografia proporcional à tela.
struct WatchChronometerMetricsRow: View {
    let heartRate: Double
    let calories: Double

    var body: some View {
        let layout = WatchChronometerLayout.make(
            availableWidth: WKInterfaceDevice.current().screenBounds.width
        )

        HStack(spacing: layout.metricsSpacing) {
            VStack(spacing: 2) {
                Text("\(Int(heartRate))")
                    .font(.system(size: layout.metricsValueFont, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                Text("BPM")
                    .font(.system(size: layout.metricsLabelFont, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }

            VStack(spacing: 2) {
                Text("\(Int(calories))")
                    .font(.system(size: layout.metricsValueFont, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                Text("Kcal")
                    .font(.system(size: layout.metricsLabelFont, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
