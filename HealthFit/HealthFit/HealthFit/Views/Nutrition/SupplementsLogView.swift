import SwiftUI

struct SupplementsLogView: View {
    @EnvironmentObject private var wellnessService: DailyWellnessService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedCatalogId: String = SupplementCatalog.items.first?.id ?? "whey"
    @State private var customName: String = ""
    @State private var quantityText: String = "30"
    @State private var selectedUnit: SupplementUnit = .grams

    private var selectedCatalogItem: SupplementCatalogItem? {
        SupplementCatalog.item(id: selectedCatalogId)
    }

    private var isCustomSelected: Bool {
        selectedCatalogItem?.isCustom == true
    }

    private var parsedQuantity: Double? {
        let normalized = quantityText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private var resolvedName: String {
        if isCustomSelected {
            return customName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return selectedCatalogItem?.name ?? ""
    }

    private var canLog: Bool {
        guard parsedQuantity != nil else { return false }
        return !resolvedName.isEmpty
    }

    private var todayIntakes: [SupplementIntakeEntry] {
        wellnessService.todaySupplementIntakes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            pickerSection
            quantitySection
            logButton
            todayListSection
        }
        .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
        .padding(.top, 8)
        .padding(.bottom, 24)
        .adaptiveContentWidth()
        .onAppear {
            applyDefaults(for: selectedCatalogId)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Suplementos de hoje")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Registre o que você ingeriu hoje. Os dados ficam salvos no dia atual.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Escolha o suplemento")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
                spacing: 8
            ) {
                ForEach(SupplementCatalog.items) { item in
                    Button {
                        selectedCatalogId = item.id
                        applyDefaults(for: item.id)
                    } label: {
                        Text(item.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selectedCatalogId == item.id ? .white : AppTheme.textPrimary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 10)
                            .background(
                                selectedCatalogId == item.id
                                    ? AppTheme.accent
                                    : AppTheme.background
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }

            if isCustomSelected {
                TextField("Nome do suplemento", text: $customName)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quantidade ingerida")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 12) {
                TextField("Qtd", text: $quantityText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .frame(width: 88)
                    .background(AppTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(AppTheme.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SupplementUnit.allCases) { unit in
                            Button {
                                selectedUnit = unit
                            } label: {
                                Text(unit.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(selectedUnit == unit ? .white : AppTheme.textPrimary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(selectedUnit == unit ? AppTheme.accent : AppTheme.background)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if let item = selectedCatalogItem, !item.isCustom {
                Text("Sugestão: \(formatQuantity(item.defaultQuantity)) \(item.defaultUnit.label)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var logButton: some View {
        Button {
            logSelectedSupplement()
        } label: {
            Label("Registrar ingestão", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle(isEnabled: canLog))
        .disabled(!canLog)
    }

    private var todayListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Registrados hoje")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text(todayIntakes.isEmpty ? "Nenhum" : "\(todayIntakes.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if todayIntakes.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "pills")
                        .foregroundStyle(AppTheme.accent.opacity(0.8))
                    Text("Nenhum suplemento registrado hoje.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(todayIntakes) { intake in
                    SupplementIntakeRow(intake: intake) {
                        wellnessService.removeSupplementIntake(id: intake.id)
                    }
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func applyDefaults(for catalogId: String) {
        guard let item = SupplementCatalog.item(id: catalogId) else { return }
        selectedUnit = item.defaultUnit
        quantityText = formatQuantity(item.defaultQuantity)
        if !item.isCustom {
            customName = ""
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        if value == floor(value) {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }

    private func logSelectedSupplement() {
        guard let quantity = parsedQuantity, !resolvedName.isEmpty else { return }
        let catalogId = selectedCatalogItem?.id ?? SupplementCatalog.customId
        let entry = SupplementIntakeEntry(
            catalogId: catalogId,
            name: resolvedName,
            quantity: quantity,
            unit: selectedUnit
        )
        wellnessService.logSupplementIntake(entry)
        if isCustomSelected {
            customName = ""
        }
        applyDefaults(for: selectedCatalogId)
    }
}

private struct SupplementIntakeRow: View {
    let intake: SupplementIntakeEntry
    let onRemove: () -> Void

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: intake.loggedAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pills.fill")
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32, height: 32)
                .background(AppTheme.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(intake.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(intake.quantityDisplay) · \(timeLabel)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 0)

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "trash")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remover \(intake.name)")
        }
        .padding(10)
        .background(AppTheme.background.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
