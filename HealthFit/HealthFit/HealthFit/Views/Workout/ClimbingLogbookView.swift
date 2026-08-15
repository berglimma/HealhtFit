import Charts
import SwiftUI

/// Diário de escalada: evolução por grau, histórico de vias e inventário de equipamento.
struct ClimbingLogbookView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case evolution = "Evolução"
        case routes = "Vias"
        case gear = "Equipamento"

        var id: String { rawValue }
    }

    @EnvironmentObject var workoutStore: WorkoutStore
    @ObservedObject private var gearService = ClimbingGearService.shared
    @State private var selectedTab: Tab = .evolution
    @State private var gearToEdit: ClimbingGearItem?
    @State private var showsAddGear = false

    private var entries: [ClimbingSessionEntry] {
        ClimbingAnalytics.entries(from: workoutStore.sessionHistory)
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
                case .evolution: evolutionSection
                case .routes: routesSection
                case .gear: gearSection
                }
            }
            .padding(16)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Diário de escalada")
        .navigationBarTitleDisplayMode(.inline)
        .requiresSubscription(.advancedSportAnalytics)
        .sheet(isPresented: $showsAddGear) {
            ClimbingGearEditorView(item: nil)
        }
        .sheet(item: $gearToEdit) { item in
            ClimbingGearEditorView(item: item)
        }
    }

    // MARK: - Evolução

    @ViewBuilder
    private var evolutionSection: some View {
        if entries.isEmpty {
            emptyState(
                icon: "figure.climbing",
                title: "Sem sessões registradas",
                message: "Inicie uma escalada em Cardio → Escalada e registre suas vias. Com algumas sessões eu mostro progressão por grau, taxa de sucesso e volume semanal."
            )
        } else {
            summaryCard
            weeklyVolumeCard
            degreeProgressCard
            disciplineCard
            conditionsCard
        }
    }

    private var summaryCard: some View {
        let attempts = ClimbingAnalytics.allAttempts(from: entries)
        let successes = attempts.filter(\.isSuccess).count
        let activeMinutes = entries.reduce(0) { $0 + $1.snapshot.activeClimbingSeconds } / 60

        return card(title: "Resumo", icon: "chart.bar.doc.horizontal") {
            HStack(spacing: 0) {
                metric(value: "\(entries.count)", label: "sessões")
                metric(value: "\(attempts.count)", label: "tentativas")
                metric(
                    value: attempts.isEmpty ? "—" : "\(Int((Double(successes) / Double(attempts.count) * 100).rounded()))%",
                    label: "sucesso"
                )
                metric(value: "\(activeMinutes)", label: "min em parede")
            }

            if let hardest = ClimbingAnalytics.hardestSend(from: entries) {
                Divider().overlay(AppTheme.textSecondary.opacity(0.2))
                Label(
                    "Mais difícil: \(hardest.grade.displayLabel) em \(hardest.displayName)",
                    systemImage: "trophy.fill"
                )
                .font(.caption)
                .foregroundStyle(AppTheme.accentSecondary)
            }
        }
    }

    private var weeklyVolumeCard: some View {
        let weeks = ClimbingAnalytics.weeklyVolume(from: entries, weeks: 8)

        return card(title: "Volume semanal", icon: "calendar") {
            if weeks.isEmpty {
                Text("Sem dados suficientes.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Chart(weeks) { week in
                    BarMark(
                        x: .value("Semana", week.label),
                        y: .value("Tentativas", week.attemptCount)
                    )
                    .foregroundStyle(AppTheme.accent)

                    BarMark(
                        x: .value("Semana", week.label),
                        y: .value("Encadenadas", week.successCount)
                    )
                    .foregroundStyle(AppTheme.accentSecondary)
                }
                .frame(height: 160)
                .chartYAxisLabel("Tentativas")

                HStack(spacing: 14) {
                    legend(color: AppTheme.accent, label: "Tentativas")
                    legend(color: AppTheme.accentSecondary, label: "Encadenadas")
                }
            }
        }
    }

    private var degreeProgressCard: some View {
        let progress = ClimbingAnalytics.degreeProgress(from: entries)

        return card(title: "Progressão por grau", icon: "arrow.up.right.circle") {
            if progress.isEmpty {
                Text("Registre o grau das vias para acompanhar a progressão.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(progress) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(item.degree)º grau")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Label(item.trend.label, systemImage: item.trend.icon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(trendColor(item.trend))
                        }

                        ProgressView(value: item.successRate)
                            .tint(AppTheme.accent)

                        Text("\(item.successCount) de \(item.attemptCount) tentativas · \(Int((item.successRate * 100).rounded()))% de sucesso")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var disciplineCard: some View {
        let stats = ClimbingAnalytics.disciplineStats(from: entries)

        return card(title: "Taxa de sucesso por tipo de via", icon: "list.bullet.rectangle") {
            if stats.isEmpty {
                Text("Sem tentativas registradas.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(stats) { stat in
                    HStack {
                        Label(stat.discipline.rawValue, systemImage: stat.discipline.icon)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        Text("\(stat.successPercent)%")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(stat.successRate >= 0.5 ? AppTheme.accent : AppTheme.accentSecondary)
                        Text("(\(stat.attemptCount))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var conditionsCard: some View {
        let temperature = ClimbingAnalytics.temperatureBuckets(from: entries)
        let humidity = ClimbingAnalytics.humidityBuckets(from: entries)

        return card(title: "Desempenho por condição", icon: "thermometer.medium") {
            if temperature.isEmpty && humidity.isEmpty {
                Text("Escale em rocha com o app aberto para eu gravar temperatura e umidade de cada sessão.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                if let best = ClimbingAnalytics.bestBucket(temperature) {
                    Label("Melhor faixa: \(best.label) — \(best.successPercent)%", systemImage: "thermometer.sun")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                if let best = ClimbingAnalytics.bestBucket(humidity) {
                    Label("Melhor umidade: \(best.label) — \(best.successPercent)%", systemImage: "humidity")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }

                ForEach(temperature) { bucket in
                    conditionRow(bucket)
                }
                ForEach(humidity) { bucket in
                    conditionRow(bucket)
                }
            }
        }
    }

    private func conditionRow(_ bucket: ClimbingConditionBucket) -> some View {
        HStack {
            Text(bucket.label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text("\(bucket.successPercent)% (\(bucket.attemptCount))")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    // MARK: - Vias

    @ViewBuilder
    private var routesSection: some View {
        if entries.isEmpty {
            emptyState(
                icon: "list.bullet",
                title: "Nenhuma via registrada",
                message: "As vias que você registrar durante a sessão aparecem aqui, com grau, estilo e quedas."
            )
        } else {
            ForEach(entries) { entry in
                card(
                    title: entry.date.formatted(date: .abbreviated, time: .shortened),
                    icon: entry.snapshot.discipline.icon
                ) {
                    HStack(spacing: 12) {
                        Label(entry.snapshot.discipline.rawValue, systemImage: "figure.climbing")
                        if let area = entry.snapshot.areaName, !area.isEmpty {
                            Label(area, systemImage: "mappin")
                        }
                        if entry.snapshot.startedAutomatically {
                            Label("Auto", systemImage: "applewatch")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)

                    if entry.attempts.isEmpty {
                        Text("Sessão sem vias registradas · \(entry.snapshot.activeClimbingSeconds / 60) min em parede")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        ForEach(entry.attempts) { attempt in
                            HStack(spacing: 8) {
                                Image(systemName: attempt.style.icon)
                                    .foregroundStyle(attempt.style.color)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(attempt.displayName)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("\(attempt.grade.displayLabel) · \(attempt.style.rawValue)\(attempt.falls > 0 ? " · \(attempt.falls) quedas" : "")")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                            }
                        }
                    }

                    if let temp = entry.snapshot.temperatureCelsius {
                        Text(String(format: "%.0f °C · umidade %.0f%%", temp, entry.snapshot.humidityPercent ?? 0))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Equipamento

    @ViewBuilder
    private var gearSection: some View {
        if gearService.items.isEmpty {
            emptyState(
                icon: "shippingbox",
                title: "Inventário vazio",
                message: "Cadastre corda, costuras, cadeirinha e capacete. Cada sessão soma um uso e eu aviso quando um item atingir o limite de usos ou de tempo de serviço."
            )

            VStack(spacing: 8) {
                ForEach(ClimbingDiscipline.allCases) { discipline in
                    Button {
                        gearService.createStarterKit(for: discipline)
                    } label: {
                        Label("Kit de \(discipline.rawValue.lowercased())", systemImage: discipline.icon)
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            if gearService.needsAttention {
                card(title: "Precisa de atenção", icon: "exclamationmark.triangle.fill") {
                    ForEach(gearService.overdueItems + gearService.dueSoonItems) { item in
                        Text("• \(item.alertMessage)")
                            .font(.caption)
                            .foregroundStyle(item.status.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            ForEach(gearService.sortedItems) { item in
                gearRow(item)
            }
        }

        Button {
            showsAddGear = true
        } label: {
            Label("Adicionar equipamento", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
    }

    private func gearRow(_ item: ClimbingGearItem) -> some View {
        card(title: item.name, icon: item.type.icon) {
            HStack {
                Label(item.status.label, systemImage: item.status.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.status.color)
                Spacer()
                Text("\(item.useCount)/\(item.type.inspectionUseLimit) usos · \(item.monthsInService)/\(item.type.serviceLifeMonths) meses")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            ProgressView(value: min(1, item.wearRatio))
                .tint(item.status.color)

            Text(item.type.inspectionChecklist)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("Inspecionei") {
                    gearService.markInspected(item)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
                .foregroundStyle(AppTheme.accent)

                Button(item.isRetired ? "Reativar" : "Aposentar") {
                    gearService.setRetired(item, retired: !item.isRetired)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
                .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Button("Editar") {
                    gearToEdit = item
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - Blocos reutilizáveis

    private func card<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func trendColor(_ trend: ClimbingTrend) -> Color {
        switch trend {
        case .improving: return AppTheme.accent
        case .stable: return AppTheme.textSecondary
        case .declining: return AppTheme.accentSecondary
        case .insufficientData: return AppTheme.textSecondary
        }
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
}

// MARK: - Editor de equipamento

struct ClimbingGearEditorView: View {
    let item: ClimbingGearItem?

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var gearService = ClimbingGearService.shared

    @State private var type: ClimbingGearType = .rope
    @State private var name = ""
    @State private var acquiredAt = Date()
    @State private var useCount = 0
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    Picker("Tipo", selection: $type) {
                        ForEach(ClimbingGearType.allCases) { gearType in
                            Label(gearType.rawValue, systemImage: gearType.icon).tag(gearType)
                        }
                    }
                    TextField("Nome (ex.: Corda 9.8 mm 60 m)", text: $name)
                    DatePicker("Em uso desde", selection: $acquiredAt, displayedComponents: .date)
                    Stepper("Usos: \(useCount)", value: $useCount, in: 0...2000)
                }

                Section("Limites") {
                    LabeledContent("Inspeção por usos", value: "\(type.inspectionUseLimit)")
                    LabeledContent("Tempo de serviço", value: "\(type.serviceLifeMonths) meses")
                    Text(type.inspectionChecklist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Observações") {
                    TextField("Quedas severas, cortes, reparos…", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let item {
                    Section {
                        Button("Remover item", role: .destructive) {
                            gearService.remove(item)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(item == nil ? "Novo equipamento" : "Editar equipamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                }
            }
            .onAppear(perform: loadExisting)
        }
    }

    private func loadExisting() {
        guard let item else { return }
        type = item.type
        name = item.name
        acquiredAt = item.acquiredAt
        useCount = item.useCount
        notes = item.notes
    }

    private func save() {
        if var existing = item {
            existing.type = type
            existing.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? type.rawValue
                : name
            existing.acquiredAt = acquiredAt
            existing.useCount = useCount
            existing.notes = notes
            gearService.update(existing)
        } else {
            gearService.add(
                ClimbingGearItem(
                    type: type,
                    name: name,
                    acquiredAt: acquiredAt,
                    useCount: useCount,
                    notes: notes
                )
            )
        }
        dismiss()
    }
}

/// Rota de navegação para o diário de escalada.
struct ClimbingLogbookRoute: Hashable {}
