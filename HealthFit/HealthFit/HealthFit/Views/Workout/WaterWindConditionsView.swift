import CoreLocation
import SwiftUI

/// Tela/sheet de vento e maré (Open-Meteo) exibida antes de iniciar Surf ou Kitesurf.
struct WaterWindConditionsView: View {
    let title: String
    let preferredCoordinate: CLLocationCoordinate2D?
    let locationHint: String?
    let startButtonTitle: String
    /// `true` = kite; `false` = surf (mensagens e favorabilidade).
    var isKitesurf: Bool = false
    let onStart: (OpenMeteoWindService.Snapshot?) -> Void
    let onCancel: () -> Void

    @StateObject private var locator = SpotLocationHelper()
    @State private var snapshot: OpenMeteoWindService.Snapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resolvedLabel = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    conditionsCard
                    if let snapshot {
                        metricsGrid(snapshot)
                        if snapshot.hasMarineData {
                            marineSection(snapshot)
                        }
                        Text("Horário da atualização: \(snapshot.updatedAtText)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    actionButtons
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { onCancel() }
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .task {
                if preferredCoordinate == nil {
                    locator.requestLocation()
                }
                await loadWind(force: false)
            }
            .onChange(of: locator.coordinate?.latitude) { _, _ in
                if preferredCoordinate == nil, locator.coordinate != nil {
                    Task { await loadWind(force: false) }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: isKitesurf
                      ? CardioExercise.kitesurfSystemImage
                      : CardioExercise.surfSystemImage)
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(isKitesurf ? "Vento e maré — Kitesurf" : "Vento e maré — Surf")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Open-Meteo (vento + Marine): altura real estimada com sua localização.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var conditionsCard: some View {
        ZStack {
            TransparentOceanWavesView(
                tint: Color.cyan,
                baseOpacity: 0.18,
                waveCount: 3
            )
            .frame(height: 150)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .clipped()

            // Animação de vento no centro do card
            TransparentWindLinesView(
                directionDegrees: snapshot?.windDirectionDegrees ?? 90,
                speedKmh: snapshot?.windSpeedKmh ?? 18,
                tint: Color.cyan.opacity(0.95),
                baseOpacity: 0.7,
                lineCount: 8
            )
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .opacity(0.9)

            VStack(alignment: .leading, spacing: 10) {
                Label(resolvedLabel.isEmpty ? "Localizando…" : resolvedLabel, systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(AppTheme.accent)
                        Text("Buscando vento e maré…")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else if let errorMessage {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "wifi.slash")
                            .foregroundStyle(AppTheme.accentSecondary)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                } else if let snap = snapshot {
                    Text(snap.beachSportMessage(isKitesurf: isKitesurf))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Condições atualizadas. Revise e inicie quando estiver pronto.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .frame(minHeight: 168)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private func metricsGrid(_ snap: OpenMeteoWindService.Snapshot) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricTile(
                title: "Vento",
                value: String(format: "%.0f km/h", snap.windSpeedKmh),
                icon: "wind"
            )
            metricTile(
                title: "Direção",
                value: "\(Int(snap.windDirectionDegrees.rounded()))° · \(snap.windLabel)",
                icon: "safari"
            )
            if let gusts = snap.windGustsKmh {
                metricTile(
                    title: "Rajadas",
                    value: String(format: "%.0f km/h", gusts),
                    icon: "tornado"
                )
            }
        }
    }

    private func marineSection(_ snap: OpenMeteoWindService.Snapshot) -> some View {
        let fav = snap.favorability(isKitesurf: isKitesurf)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Maré e ondas")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            // Card de maré com favorabilidade embutida
            tideCard(snap: snap, favorability: fav)

            Text("Nível do mar via Open-Meteo Marine (estimado — não é tábua de porto).")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                if let phase = snap.estimatedPhaseLabel {
                    metricTile(
                        title: "Tendência",
                        value: phase,
                        icon: "arrow.up.arrow.down"
                    )
                }
                if let h = snap.waveHeightMeters {
                    metricTile(
                        title: "Altura das ondas",
                        value: String(format: "%.1f m", h),
                        icon: "water.waves"
                    )
                }
                if let p = snap.wavePeriodSeconds {
                    metricTile(
                        title: "Período",
                        value: String(format: "%.0f s", p),
                        icon: "timer"
                    )
                }
            }

            if !snap.tideExtrema.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Extremos estimados")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    ForEach(snap.tideExtrema) { ext in
                        HStack {
                            Label(ext.kindLabel, systemImage: ext.kind == .high ? "arrow.up.to.line" : "arrow.down.to.line")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            Text(String(format: "%.2f m · %@", ext.heightMeters, hourString(ext.time)))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if !snap.marineHours.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Próximas horas")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(snap.marineHours) { hour in
                                hourChip(hour)
                            }
                        }
                    }
                }
            }
        }
    }

    private func tideCard(
        snap: OpenMeteoWindService.Snapshot,
        favorability: TideWindFavorability
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Maré", systemImage: "water.waves")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                favorabilityBadge(favorability)
            }

            if let level = snap.seaLevelHeightMeters {
                Text(String(format: "%+.2f m MSL", level))
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
            } else if let h = snap.displayTideHeightMeters {
                Text(String(format: "%.2f m", h))
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
            } else {
                Text(snap.estimatedTideLabel)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Text(snap.estimatedTideLabel)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            if favorability == .favorable {
                Text(isKitesurf
                     ? "Maré e vento no ponto para kite — boa janela de sessão."
                     : "Maré favorável para o surf — boas chances no pico.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.green)
            } else if let reason = favorability.shortReason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(favorability == .favorable
                      ? Color.green.opacity(0.12)
                      : AppTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(
                    favorability == .favorable ? Color.green.opacity(0.45) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    private func favorabilityBadge(_ fav: TideWindFavorability) -> some View {
        Text(fav.badgeLabel)
            .font(.caption2.weight(.bold))
            .foregroundStyle(badgeForeground(fav))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(badgeBackground(fav))
            .clipShape(Capsule())
    }

    private func badgeForeground(_ fav: TideWindFavorability) -> Color {
        switch fav {
        case .favorable: return .green
        case .moderate: return AppTheme.accentSecondary
        case .unfavorable: return .orange
        case .unknown: return AppTheme.textSecondary
        }
    }

    private func badgeBackground(_ fav: TideWindFavorability) -> Color {
        switch fav {
        case .favorable: return Color.green.opacity(0.18)
        case .moderate: return AppTheme.accentSecondary.opacity(0.18)
        case .unfavorable: return Color.orange.opacity(0.18)
        case .unknown: return AppTheme.textSecondary.opacity(0.12)
        }
    }

    private func hourChip(_ hour: OpenMeteoWindService.MarineHourPoint) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(hour.hourLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            if let sea = hour.seaLevelMeters {
                Text(String(format: "%+.2f m", sea))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AppTheme.textPrimary)
            }
            if let wave = hour.waveHeightMeters {
                Text(String(format: "ondas %.1f m", wave))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func hourString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func metricTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task { await loadWind(force: true) }
            } label: {
                Label("Atualizar", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.accent)
            .disabled(isLoading)

            Button {
                onStart(snapshot)
            } label: {
                Label(startButtonTitle, systemImage: "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoading)
        }
        .padding(.top, 4)
    }

    @MainActor
    private func loadWind(force: Bool) async {
        isLoading = true
        errorMessage = nil

        let preferred = preferredCoordinate ?? locator.coordinate
        let hint = locationHint?.trimmingCharacters(in: .whitespacesAndNewlines)
        let (coord, label) = OpenMeteoWindService.shared.resolveLocation(
            preferred: preferred,
            preferredLabel: (hint?.isEmpty == false) ? hint : nil
        )
        resolvedLabel = label

        do {
            let result = try await OpenMeteoWindService.shared.fetch(
                latitude: coord.latitude,
                longitude: coord.longitude,
                locationLabel: label,
                forceRefresh: force
            )
            snapshot = result
            resolvedLabel = result.locationLabel
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "Sem conexão. Verifique a internet e tente novamente."
        }

        isLoading = false
    }
}
