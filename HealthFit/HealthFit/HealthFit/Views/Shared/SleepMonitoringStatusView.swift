import SwiftUI

/// Status do monitoramento de sono via Apple Watch / Saúde + quando o card atualiza.
struct SleepMonitoringStatusView: View {
    @EnvironmentObject private var healthKitManager: HealthKitManager

    var entry: DailyWellnessEntry?
    var style: Style = .card

    enum Style {
        case card
        case compact
    }

    private var isMonitoringActive: Bool {
        healthKitManager.isHealthKitAvailable && healthKitManager.isAuthorized
    }

    private var lastUpdateText: String? {
        guard let at = entry?.sleepUpdatedAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.timeZone = .autoupdatingCurrent
        if Calendar.current.isDateInToday(at) {
            formatter.setLocalizedDateFormatFromTemplate("Hm")
            return "Hoje às \(formatter.string(from: at))"
        }
        formatter.setLocalizedDateFormatFromTemplate("dMMMHm")
        return formatter.string(from: at)
    }

    private var updateHint: String {
        if let entry, entry.sleepHours != nil {
            switch entry.sleepSource {
            case .appleHealth:
                if let last = lastUpdateText {
                    return "Card atualizado \(last). Nova sincronização ocorre após a próxima noite no Apple Watch."
                }
                return "Card sincronizado com o Apple Watch. Atualiza de novo após a próxima noite no Saúde."
            case .manual:
                return "Registro manual. O monitoramento pelo Watch continua ativo e atualiza o card após a próxima noite."
            case nil:
                break
            }
        }

        if isMonitoringActive {
            return "O card atualiza pela manhã ao abrir o app e quando o Apple Watch sincronizar a noite no Saúde."
        }
        return "Autorize o Saúde para sincronizar o sono do Apple Watch automaticamente neste card."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style == .compact ? 4 : 6) {
            HStack(spacing: 8) {
                Image(systemName: isMonitoringActive ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isMonitoringActive ? AppTheme.accent : .orange)

                Text(isMonitoringActive ? "Monitoramento de sono ativado" : "Monitoramento de sono pendente")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer(minLength: 0)

                if isMonitoringActive {
                    Label("Watch", systemImage: "applewatch")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accent.opacity(0.14))
                        .clipShape(Capsule())
                }
            }

            Text(updateHint)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(style == .compact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: style == .compact ? 10 : 12, style: .continuous)
                .fill(
                    isMonitoringActive
                        ? AppTheme.accent.opacity(0.10)
                        : Color.orange.opacity(0.10)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isMonitoringActive ? "Monitoramento de sono ativado" : "Monitoramento de sono pendente"). \(updateHint)")
    }
}
