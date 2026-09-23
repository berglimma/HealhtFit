import SwiftUI

/// Faixa de desempenho do cronômetro Watch (caminhada / corrida / bike / MTB).
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

/// Cronômetro circular segmentado (60 ticks) — estilo da imagem, sem sobreposições.
struct WatchSegmentedChronometer: View {
    let elapsedSeconds: Int
    let performance: WatchChronometerPerformance
    var secondaryText: String = ""
    var statusOverride: String? = nil

    private let segmentCount = 60

    private var filledCount: Int {
        // Anel = segundos do minuto atual (0…59), animado a cada tick.
        max(0, min(segmentCount, elapsedSeconds % segmentCount))
    }

    private var accent: Color { performance.accent }

    private var statusText: String {
        statusOverride ?? performance.statusLabel
    }

    var body: some View {
        VStack(spacing: 6) {
            Label("Cronômetro", systemImage: "stopwatch.fill")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .labelStyle(.titleAndIcon)

            ZStack {
                // Fundo do anel (ticks inativos)
                ForEach(0..<segmentCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 3.2, height: 9)
                        .offset(y: -52)
                        .rotationEffect(.degrees(Double(index) / Double(segmentCount) * 360))
                }

                // Ticks ativos (cor por desempenho)
                ForEach(0..<filledCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(accent)
                        .frame(width: 3.2, height: 10)
                        .offset(y: -52)
                        .rotationEffect(.degrees(Double(index) / Double(segmentCount) * 360))
                }

                VStack(spacing: 2) {
                    Text(formatClock(elapsedSeconds))
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .contentTransition(.numericText())

                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !secondaryText.isEmpty {
                        Text(secondaryText)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.55))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: 110)
            }
            .frame(width: 126, height: 126)
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

/// BPM + Kcal no rodapé — layout da imagem, sem sobrepor o anel.
struct WatchChronometerMetricsRow: View {
    let heartRate: Double
    let calories: Double

    var body: some View {
        HStack(spacing: 28) {
            VStack(spacing: 1) {
                Text("\(Int(heartRate))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("BPM")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }

            VStack(spacing: 1) {
                Text("\(Int(calories))")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("Kcal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
    }
}
