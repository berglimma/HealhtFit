import SwiftUI

struct DuoTeamReportView: View {
    let teamId: String
    @ObservedObject private var duoService = DuoTeamService.shared
    @EnvironmentObject private var workoutStore: WorkoutStore

    @State private var report: DuoTeamReport?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading && report == nil {
                ProgressView("Montando ranking…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let report {
                ScrollView {
                    VStack(spacing: 16) {
                        header(report)
                        teamTotals(report)
                        rankingList(report)
                        Text("Cada membro publica o próprio desempenho ao abrir o relatório. Sem localização em tempo real.")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView(
                    "Relatório indisponível",
                    systemImage: "chart.bar.xaxis",
                    description: Text(duoService.lastError ?? "Tente novamente em instantes.")
                )
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Relatório da equipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .task { await reload() }
    }

    private func header(_ report: DuoTeamReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(report.teamName, systemImage: report.modality.icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Ranking de desempenho · \(report.periodLabel)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Text("Somente treinos iniciados em dupla/equipe. Treinos individuais não entram.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Ordem: treinos + minutos ativos + calorias da equipe.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func teamTotals(_ report: DuoTeamReport) -> some View {
        HStack(spacing: 12) {
            metricChip(title: "Treinos", value: "\(report.teamSessions7d)")
            metricChip(title: "Minutos", value: "\(report.teamMinutes7d)")
            metricChip(title: "kcal", value: "\(report.teamCalories7d)")
        }
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func rankingList(_ report: DuoTeamReport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ranking do grupo")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(report.rows) { row in
                rankingRow(row)
            }
        }
    }

    private func rankingRow(_ row: DuoTeamRankingRow) -> some View {
        let perf = row.performance
        return HStack(alignment: .top, spacing: 12) {
            Text("\(row.rank)º")
                .font(.title3.weight(.bold))
                .foregroundStyle(row.rank == 1 ? AppTheme.accent : AppTheme.textSecondary)
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(perf.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(perf.sessionsLast7Days) treinos · \(perf.minutesLast7Days) min · \(perf.caloriesLast7Days) kcal")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("30 dias: \(perf.sessionsLast30Days) treinos · \(perf.minutesLast30Days) min · \(perf.caloriesLast30Days) kcal")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.9))
                if let last = perf.lastWorkoutAt {
                    Text("Último treino: \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Text("\(perf.rankingScore7d)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .accessibilityLabel("Pontuação \(perf.rankingScore7d)")
        }
        .cardStyle()
    }

    private func reload() async {
        isLoading = true
        defer { isLoading = false }
        report = await duoService.buildAndPublishReport(
            teamId: teamId,
            sessions: workoutStore.sessionHistory
        )
    }
}
