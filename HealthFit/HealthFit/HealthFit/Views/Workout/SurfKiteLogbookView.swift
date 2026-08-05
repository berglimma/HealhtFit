import Charts
import SwiftUI

/// Diário / comparativo de sessões Surf e Kitesurf.
struct SurfKiteLogbookView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var filter: LogFilter = .all

    private enum LogFilter: String, CaseIterable, Identifiable {
        case all = "Todos"
        case kite = "Kitesurf"
        case surf = "Surf"

        var id: String { rawValue }
    }

    private var sessions: [WorkoutSession] {
        switch filter {
        case .all:
            return SurfKiteMetricsAnalyzer.sessions(from: workoutStore.sessionHistory)
        case .kite:
            return SurfKiteMetricsAnalyzer.sessions(from: workoutStore.sessionHistory, kitesurfOnly: true)
        case .surf:
            return SurfKiteMetricsAnalyzer.sessions(from: workoutStore.sessionHistory, kitesurfOnly: false)
        }
    }

    private var totalJumps: Int {
        SurfKiteMetricsAnalyzer.totalJumps(in: sessions)
    }

    private var bestJump: Double {
        SurfKiteMetricsAnalyzer.bestJumpMeters(in: sessions)
    }

    private var totalDistance: Double {
        SurfKiteMetricsAnalyzer.totalDistanceKm(in: sessions)
    }

    private var jumpChartPoints: [(date: Date, jumps: Int)] {
        sessions.compactMap { s in
            guard let c = s.waterSport?.jumpCount, c > 0 else { return nil }
            return (s.startedAt, c)
        }
        .reversed()
    }

    private var heightChartPoints: [(date: Date, meters: Double)] {
        sessions.compactMap { s in
            guard let h = s.waterSport?.maxJumpHeightMeters, h > 0 else { return nil }
            return (s.startedAt, h)
        }
        .reversed()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerBanner
                Picker("Filtro", selection: $filter) {
                    ForEach(LogFilter.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if sessions.isEmpty {
                    emptyState
                } else {
                    summaryGrid
                    jumpCountChart
                    jumpHeightChart
                    sessionList
                }
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle("Diário Surf / Kite")
        .navigationBarTitleDisplayMode(.large)
    }

    private var headerBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: "water.waves")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Comparativo de sessões")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Saltos, altura, GPS e condições entre treinos da modalidade.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Nenhuma sessão registrada")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text("Inicie Cardio → Surf ou Kitesurf, preencha equipamento/SPOT e encerre a sessão. O histórico e os comparativos aparecem aqui.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var summaryGrid: some View {
        HStack(spacing: 12) {
            summaryTile(title: "Sessões", value: "\(sessions.count)", icon: "list.bullet")
            summaryTile(title: "Saltos", value: "\(totalJumps)", icon: "arrow.up.to.line")
            summaryTile(title: "Recorde", value: String(format: "%.1f m", bestJump), icon: "medal.fill")
            summaryTile(title: "km GPS", value: String(format: "%.1f", totalDistance), icon: "map")
        }
    }

    private func summaryTile(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var jumpCountChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Saltos por sessão")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            if jumpChartPoints.count >= 2 {
                Chart(jumpChartPoints, id: \.date) { point in
                    BarMark(
                        x: .value("Data", point.date),
                        y: .value("Saltos", point.jumps)
                    )
                    .foregroundStyle(AppTheme.accent.gradient)
                }
                .frame(height: 160)
            } else {
                Text("Registre mais sessões com saltos para ver a evolução.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var jumpHeightChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Maior salto (m)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            if heightChartPoints.count >= 2 {
                Chart(heightChartPoints, id: \.date) { point in
                    LineMark(
                        x: .value("Data", point.date),
                        y: .value("m", point.meters)
                    )
                    .foregroundStyle(Color.orange)
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Data", point.date),
                        y: .value("m", point.meters)
                    )
                    .foregroundStyle(Color.orange)
                }
                .frame(height: 160)
            } else {
                Text("Comparativo de altura disponível após 2+ sessões com saltos.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Histórico")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(sessions) { session in
                sessionRow(session)
            }
        }
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        let w = session.waterSport
        let report = SurfKiteReportBuilder.build(session: session, allSessions: workoutStore.sessionHistory)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.workoutTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(2)
                Spacer()
                Text(session.startedAt, style: .date)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            HStack(spacing: 12) {
                Label("\(w?.jumpCount ?? 0)", systemImage: "arrow.up.to.line")
                Label(String(format: "%.1f m", w?.maxJumpHeightMeters ?? 0), systemImage: "arrow.up.circle")
                Label(String(format: "%.1f km", session.displayDistanceKm), systemImage: "map")
            }
            .font(.caption)
            .foregroundStyle(AppTheme.textSecondary)

            if let mode = w?.ridingModeRaw {
                Text("Modo: \(mode)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let spot = w?.spot?.name, !spot.isEmpty {
                Text("SPOT: \(spot)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.accent)
            }
            if let report, let delta = report.jumpDeltaVsBest, delta > 0 {
                Text(String(format: "Recorde na sessão (+%.2f m)", delta))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SurfKiteLogbookRoute: Hashable {}
