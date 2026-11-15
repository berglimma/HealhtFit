import SwiftUI

struct MuscleGroupStatsView: View {
    @EnvironmentObject var workoutStore: WorkoutStore

    @State private var period: Period = .week

    private enum Period: String, CaseIterable, Identifiable {
        case week = "Semana"
        case month = "Mês"
        var id: String { rawValue }
        var days: Int { self == .week ? 7 : 30 }
        var label: String { self == .week ? "Últimos 7 dias" : "Últimos 30 dias" }
    }

    private var report: MuscleGroupPeriodReport {
        WorkoutDaySuggestionAnalyzer.report(
            sessions: workoutStore.sessionHistory,
            sheets: workoutStore.workoutSheets,
            days: period.days,
            periodLabel: period.label
        )
    }

    private var maxHits: Int {
        max(report.stats.map(\.sessionHits).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Grupos musculares")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(report.periodLabel)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Picker("Período", selection: $period) {
                    ForEach(Period.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 160)
            }

            Text("\(report.totalStrengthSessions) treinos de musculação no período")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)

            VStack(spacing: 10) {
                ForEach(report.stats) { stat in
                    muscleRow(stat)
                }
            }

            cardioStatsSection

            VStack(alignment: .leading, spacing: 8) {
                Text("Sugestões para melhorar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                ForEach(Array(report.suggestions.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundStyle(Color.orange)
                            .padding(.top, 2)
                        Text(tip)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.cardBackground)
        )
    }

    private var cardioStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Cardio", systemImage: "figure.run")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(report.totalCardioSessions)× no período")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.cyan)
            }

            if report.cardioByType.isEmpty {
                Text("Nenhum cardio registrado neste período.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                FlowWrap(spacing: 8) {
                    ForEach(report.cardioByType) { item in
                        Text("\(item.name) · \(item.count)×")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.cyan.opacity(0.14))
                            .foregroundStyle(Color.cyan)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cyan.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func muscleRow(_ stat: MuscleGroupStat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(stat.group.rawValue, systemImage: stat.group.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(stat.sessionHits)×")
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(AppTheme.accent)
                Text("· \(stat.exerciseHits) ex.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent, Color.cyan.opacity(0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(stat.sessionHits) / CGFloat(maxHits))
                }
            }
            .frame(height: 8)
        }
    }
}

/// Layout simples em linha com quebra — evita dependência de LazyVGrid para chips.
private struct FlowWrap<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        // iOS 16+: Layout wrapping via ViewThatFits fallback to VStack of HStacks is heavy;
        // use flexible LazyVGrid for predictable wrap.
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110), spacing: spacing)],
            alignment: .leading,
            spacing: spacing
        ) {
            content()
        }
    }
}
