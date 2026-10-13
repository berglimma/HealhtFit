import Charts
import SwiftUI

/// Diário de tênis: carga, placar, zonas de FC, volume semanal e tips de recuperação.
struct TennisLogbookView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case overview = "Resumo"
        case sessions = "Sessões"
        case recovery = "Recuperação"

        var id: String { rawValue }
    }

    @EnvironmentObject var workoutStore: WorkoutStore
    @State private var selectedTab: Tab = .overview

    private var entries: [TennisSessionEntry] {
        TennisAnalytics.entries(from: workoutStore.sessionHistory)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("Seção", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .overview: overviewSection
                case .sessions: sessionsSection
                case .recovery: recoverySection
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Diário de tênis")
        .navigationBarTitleDisplayMode(.inline)
        .requiresSubscription(.advancedSportAnalytics)
    }

    // MARK: - Resumo

    @ViewBuilder
    private var overviewSection: some View {
        if entries.isEmpty {
            emptyState(
                icon: CardioExercise.tennisSystemImage,
                title: "Sem sessões registradas",
                message: "Inicie um treino em Cardio → Tênis. O placar, zonas de FC e picos alimentam este diário."
            )
        } else {
            summaryCard
            weeklyVolumeCard
            surfaceCard
            loadBandCard
        }
    }

    private var summaryCard: some View {
        let minutes = entries.reduce(0) { $0 + $1.activeSeconds } / 60
        let bursts = entries.reduce(0) { $0 + $1.snapshot.burstCount }
        let matches = entries.filter { $0.snapshot.sessionType == .match }.count
        let avgLoad = entries.isEmpty
            ? 0
            : entries.reduce(0.0) { $0 + $1.snapshot.loadScore } / Double(entries.count)

        return card(title: "Resumo", icon: "chart.bar.doc.horizontal") {
            HStack(spacing: 0) {
                metric(value: "\(entries.count)", label: "sessões")
                metric(value: "\(matches)", label: "partidas")
                metric(value: "\(minutes)", label: "minutos")
                metric(value: "\(bursts)", label: "picos")
            }
            Divider().overlay(AppTheme.textSecondary.opacity(0.2))
            Label(
                String(format: "Carga média: %.0f", avgLoad),
                systemImage: "flame.fill"
            )
            .font(.caption)
            .foregroundStyle(AppTheme.accentSecondary)
        }
    }

    private var weeklyVolumeCard: some View {
        let weeks = TennisAnalytics.weeklyVolume(from: entries, weeks: 8)

        return card(title: "Volume semanal", icon: "calendar") {
            if weeks.isEmpty {
                Text("Sem dados suficientes.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Chart {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                        BarMark(
                            x: .value("Semana", week.label),
                            y: .value("Minutos", week.minutes)
                        )
                        .foregroundStyle(AppTheme.accent)
                    }
                }
                .frame(height: 160)
                .chartYAxisLabel("Minutos")

                Text("Barras = minutos ativos por semana · sessões nas dicas dos eixos.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var surfaceCard: some View {
        let groups = Dictionary(grouping: entries, by: \.snapshot.surface)
            .map { (surface: $0.key, count: $0.value.count, minutes: $0.value.reduce(0) { $0 + $1.activeSeconds } / 60) }
            .sorted { $0.count > $1.count }

        return card(title: "Por superfície", icon: "sportscourt.fill") {
            if groups.isEmpty {
                Text("Sem superfícies registradas.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(groups, id: \.surface) { item in
                    HStack {
                        Circle()
                            .fill(item.surface.color)
                            .frame(width: 8, height: 8)
                        Text(item.surface.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("\(item.count) · \(item.minutes) min")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var loadBandCard: some View {
        let bands = TennisLoadBand.allCases.map { band in
            (band, entries.filter { $0.snapshot.loadBand == band }.count)
        }

        return card(title: "Distribuição de carga", icon: "bolt.heart.fill") {
            ForEach(bands, id: \.0) { band, count in
                HStack {
                    Label(band.rawValue, systemImage: band.icon)
                        .font(.subheadline)
                        .foregroundStyle(band.color)
                    Spacer()
                    Text("\(count)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
    }

    // MARK: - Sessões

    @ViewBuilder
    private var sessionsSection: some View {
        if entries.isEmpty {
            emptyState(
                icon: "list.bullet.rectangle",
                title: "Histórico vazio",
                message: "Suas partidas e treinos de tênis aparecem aqui com placar e carga."
            )
        } else {
            ForEach(entries) { entry in
                sessionRow(entry)
            }
        }
    }

    private func sessionRow(_ entry: TennisSessionEntry) -> some View {
        let snap = entry.snapshot
        return card(title: entry.title, icon: snap.sessionType.icon) {
            Text(sessionDate(entry.startedAt))
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)

            HStack(spacing: 0) {
                metric(value: DurationFormatting.format(seconds: entry.activeSeconds), label: "ativo")
                metric(value: "\(snap.setsWon)–\(snap.setsLost)", label: "sets")
                metric(value: "\(snap.burstCount)", label: "picos")
                metric(value: String(format: "%.0f", snap.loadScore), label: "carga")
            }

            HStack {
                Text(snap.surface.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(snap.surface.color)
                Spacer()
                Label(snap.loadBand.rawValue, systemImage: snap.loadBand.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(snap.loadBand.color)
            }

            if snap.highZoneSeconds > 0 || snap.recoverySeconds > 0 {
                Text(String(format: "Zona alta %.0f%% · meta %.0f%%", snap.highZonePercent, snap.highZoneGoalPercent))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Recuperação

    @ViewBuilder
    private var recoverySection: some View {
        if let latest = entries.first {
            card(title: "Última sessão", icon: "heart.text.square.fill") {
                Label(latest.snapshot.loadBand.rawValue, systemImage: latest.snapshot.loadBand.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(latest.snapshot.loadBand.color)
                Text(latest.snapshot.surface.detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            card(title: "Tips de recuperação", icon: "leaf.fill") {
                if latest.snapshot.recoveryTips.isEmpty {
                    Text("Finalize uma sessão para gerar tips personalizados.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    ForEach(Array(latest.snapshot.recoveryTips.enumerated()), id: \.offset) { _, tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AppTheme.accent)
                            Text(tip)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        } else {
            emptyState(
                icon: "leaf.fill",
                title: "Sem tips ainda",
                message: "Após a primeira sessão de tênis, mostro recuperação por superfície, carga e volume."
            )
        }
    }

    // MARK: - Helpers

    private func card<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func sessionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Rota de navegação para o diário de tênis.
struct TennisLogbookRoute: Hashable {}
