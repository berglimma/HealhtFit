import CoreLocation
import SwiftUI

/// Diário da bike: pedais, problemas, manutenções e vida útil de peças.
struct BikeLogbookView: View {
    @ObservedObject private var service = BikeMaintenanceService.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showProblemSheet = false
    @State private var showMaintenanceSheet = false
    @State private var problemTitle = ""
    @State private var problemDetail = ""
    @State private var maintenanceTitle = ""
    @State private var maintenanceDetail = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerBanner
                wearSection
                actionButtons
                if service.entries.isEmpty {
                    emptyState
                } else {
                    historySection
                }
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle("Diário da bike")
        .navigationBarTitleDisplayMode(.large)
        .requiresSubscription(.advancedSportAnalytics)
        .sheet(isPresented: $showProblemSheet) {
            logFormSheet(
                title: "Registrar problema",
                titlePlaceholder: "Ex.: Ruído na corrente",
                detailPlaceholder: "Descreva o que aconteceu…",
                titleText: $problemTitle,
                detailText: $problemDetail
            ) {
                service.addProblem(title: problemTitle, detail: problemDetail)
                problemTitle = ""
                problemDetail = ""
                showProblemSheet = false
            }
        }
        .sheet(isPresented: $showMaintenanceSheet) {
            logFormSheet(
                title: "Registrar manutenção",
                titlePlaceholder: "Ex.: Lubrificação da corrente",
                detailPlaceholder: "Oficina, peças, notas…",
                titleText: $maintenanceTitle,
                detailText: $maintenanceDetail
            ) {
                service.addMaintenance(title: maintenanceTitle, detail: maintenanceDetail)
                maintenanceTitle = ""
                maintenanceDetail = ""
                showMaintenanceSheet = false
            }
        }
    }

    private var headerBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: "bicycle")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Diário da bike")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Histórico de pedais, problemas e manutenções. A vida útil avisa troca de corrente, pneus e pastilhas.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var wearSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vida útil das peças")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if !service.partsNeedingAttention.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(wearAlertMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricTile(
                    title: "Pedais no app",
                    value: "\(service.rideEntries.count)",
                    icon: "list.bullet",
                    color: AppTheme.accent
                )
                metricTile(
                    title: "Km totais",
                    value: formatKm(service.lifetimeKm),
                    icon: "road.lanes",
                    color: AppTheme.accentSecondary
                )
            }

            ForEach(BikeWearPart.allCases) { part in
                wearCard(part: part, state: service.wearState(for: part))
            }
        }
    }

    private var wearAlertMessage: String {
        let names = service.partsNeedingAttention.map(\.title).joined(separator: ", ")
        return "Atenção: considere trocar \(names) com base no uso."
    }

    private func wearCard(part: BikeWearPart, state: BikeWearState) -> some View {
        let progress = min(state.progress(for: part), 1)
        let overdue = state.isOverdue(for: part)
        let warning = state.needsAttention(for: part)
        let barColor: Color = overdue ? .red : (warning ? .orange : AppTheme.accent)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(part.title, systemImage: part.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("\(formatKm(state.kmSinceReplace)) / \(formatKm(part.lifeKm))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(barColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(8, geo.size.width * progress), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text(statusLabel(overdue: overdue, warning: warning, remaining: max(0, part.lifeKm - state.kmSinceReplace)))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Button("Troquei") {
                    service.replacePart(part)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func statusLabel(overdue: Bool, warning: Bool, remaining: Double) -> String {
        if overdue { return "Troca recomendada agora" }
        if warning { return "Próximo do limite" }
        return "Restam ~\(formatKm(remaining))"
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                showProblemSheet = true
            } label: {
                Label("Problema", systemImage: "wrench.and.screwdriver")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(AppTheme.textPrimary)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                showMaintenanceSheet = true
            } label: {
                Label("Manutenção", systemImage: "checkmark.seal")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(AppTheme.textSecondary)
            Text("Nenhum registro ainda")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text("Encerre pedais de Bicicleta pedal ou Mountain bike para acumular km e a vida útil das peças.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Histórico")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(service.recentEntries) { entry in
                historyRow(entry)
            }
        }
    }

    private func historyRow(_ entry: BikeLogEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon(for: entry.kind))
                .foregroundStyle(color(for: entry.kind))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if !entry.detail.isEmpty {
                    Text(entry.detail)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button(role: .destructive) {
                service.deleteEntry(entry)
            } label: {
                Label("Apagar", systemImage: "trash")
            }
        }
    }

    private func icon(for kind: BikeLogEntryKind) -> String {
        switch kind {
        case .ride: return "bicycle"
        case .problem: return "exclamationmark.circle"
        case .maintenance: return "wrench"
        case .partReplace: return "arrow.triangle.2.circlepath"
        }
    }

    private func color(for kind: BikeLogEntryKind) -> Color {
        switch kind {
        case .ride: return AppTheme.accent
        case .problem: return .orange
        case .maintenance: return .green
        case .partReplace: return AppTheme.accentSecondary
        }
    }

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatKm(_ km: Double) -> String {
        if abs(km - km.rounded()) < 0.05 {
            return "\(Int(km.rounded())) km"
        }
        return String(format: "%.1f km", km)
    }

    private func logFormSheet(
        title: String,
        titlePlaceholder: String,
        detailPlaceholder: String,
        titleText: Binding<String>,
        detailText: Binding<String>,
        onSave: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            Form {
                Section("Título") {
                    TextField(titlePlaceholder, text: titleText)
                }
                Section("Detalhes") {
                    TextField(detailPlaceholder, text: detailText, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        showProblemSheet = false
                        showMaintenanceSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { onSave() }
                        .disabled(titleText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct BikeLogbookRoute: Hashable {}

// MARK: - Reportar perigo (durante o pedal)

struct ReportRoadHazardSheet: View {
    let coordinate: CLLocationCoordinate2D?
    var onReport: (RoadHazardType, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: RoadHazardType = .pothole
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo de perigo") {
                    Picker("Tipo", selection: $selectedType) {
                        ForEach(RoadHazardType.allCases) { type in
                            Label(type.title, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Nota (opcional)") {
                    TextField("Ex.: buraco profundo na direita", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                if coordinate == nil {
                    Section {
                        Text("Ative o GPS para reportar com localização.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Perigo na pista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reportar") {
                        onReport(selectedType, note)
                    }
                    .disabled(coordinate == nil)
                }
            }
        }
    }
}
