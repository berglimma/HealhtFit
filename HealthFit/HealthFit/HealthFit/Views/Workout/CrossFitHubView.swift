import SwiftUI
import HealthKit

/// Rota do hub CrossFit na lista de Treinos / Cardio.
struct CrossFitHubRoute: Hashable {}

/// Rota de uma trilha (WOD ou Hyrox) com escolha de formato.
struct CrossFitTrackRoute: Hashable {
    let track: CrossFitTrack
}

/// Card "CrossFit" na lista de cardio — abre Treino Crossfit e Método Hyrox.
struct CrossFitProgramHeroCard: View {
    private let accent = Color(red: 0.92, green: 0.38, blue: 0.12)
    var lockedByPlan: PlanTier? = nil

    var body: some View {
        WorkoutProgramHeroCard(
            title: "CrossFit",
            subtitle: "WODs e Método Hyrox — metcon, estações e cronômetro no Watch",
            accent: accent,
            imageName: "CrossFitCoverHub",
            systemImage: "figure.cross.training",
            coverColors: [accent, Color(red: 0.28, green: 0.08, blue: 0.04)],
            eyebrow: "FUNCIONAL · METCON",
            eyebrowSystemImage: "bolt.heart.fill",
            footerLabels: [
                (icon: "square.stack.3d.up.fill", text: "\(CrossFitTrack.allCases.count) trilhas"),
                (icon: "stopwatch.fill", text: "AMRAP · EMOM · Hyrox")
            ],
            lockedByPlan: lockedByPlan
        )
    }
}

/// Hub: dois cards reais (Treino Crossfit e Método Hyrox).
struct CrossFitHubView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let accent = Color(red: 0.92, green: 0.38, blue: 0.12)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hubHeader

                VStack(alignment: .leading, spacing: 12) {
                    Text("Escolha a trilha")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Cada trilha tem formatos prontos, cronômetro, Watch e histórico — como nas outras modalidades.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    LazyVStack(spacing: 12) {
                        ForEach(CrossFitTrack.allCases) { track in
                            NavigationLink(value: CrossFitTrackRoute(track: track)) {
                                CrossFitTrackCard(track: track)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle("CrossFit")
        .navigationBarTitleDisplayMode(.inline)
        .requiresSubscription(.advancedModalities)
        .navigationDestination(for: CrossFitTrackRoute.self) { route in
            CrossFitTrackView(track: route.track)
        }
    }

    private var hubHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.cross.training")
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("CROSSFIT")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Metcon, estações Hyrox, BPM e calorias no Apple Watch")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}

/// Card de trilha no hub CrossFit.
struct CrossFitTrackCard: View {
    let track: CrossFitTrack

    var body: some View {
        WorkoutProgramHeroCard(
            title: track.name,
            subtitle: track.summary,
            accent: track.coverColors.first ?? AppTheme.accent,
            imageName: track.coverImageName,
            systemImage: track.icon,
            coverColors: track.coverColors,
            eyebrow: track.eyebrow,
            eyebrowSystemImage: "stopwatch.fill",
            footerLabels: [
                (icon: "list.bullet", text: "\(track.formats.count) formatos"),
                (icon: "flame.fill", text: String(format: "~%.0f kcal/min", track.caloriesPerMinute))
            ]
        )
    }
}

/// Detalhe da trilha: formatos, dicas e início da sessão.
struct CrossFitTrackView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    let track: CrossFitTrack

    @State private var selectedFormat: CrossFitFormat

    init(track: CrossFitTrack) {
        self.track = track
        _selectedFormat = State(initialValue: track.defaultFormat)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                trackHero

                formatSection

                if let stations = track.stationsHint {
                    stationsCard(stations)
                }

                tipsSection

                startButton
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle(track.name)
        .navigationBarTitleDisplayMode(.inline)
        .requiresSubscription(.advancedModalities)
    }

    private var trackHero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(track.eyebrow, systemImage: track.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(track.coverColors.first ?? AppTheme.accent)
            Text(track.summary)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Text("Mesmo fluxo das outras modalidades: setup → sessão ao vivo → resumo → compartilhar.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Formato da sessão")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text("Escolha como quer treinar hoje — a meta de tempo acompanha o formato.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            LazyVStack(spacing: 10) {
                ForEach(track.formats) { format in
                    Button {
                        selectedFormat = format
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedFormat.id == format.id
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .foregroundStyle(
                                    selectedFormat.id == format.id
                                    ? (track.coverColors.first ?? AppTheme.accent)
                                    : AppTheme.textSecondary
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(format.detail)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            if let seconds = format.targetSeconds, seconds > 0 {
                                Text(DurationFormatting.format(seconds: seconds))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(AppTheme.textSecondary)
                            } else {
                                Text("Livre")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .padding(12)
                        .background(
                            (selectedFormat.id == format.id
                             ? (track.coverColors.first ?? AppTheme.accent).opacity(0.12)
                             : AppTheme.cardBackground)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedFormat.id == format.id
                                    ? (track.coverColors.first ?? AppTheme.accent).opacity(0.5)
                                    : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func stationsCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Estações Hyrox", systemImage: "flag.checkered")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Para a melhor experiência")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            ForEach(track.tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(track.coverColors.first ?? AppTheme.accent)
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var startButton: some View {
        Button {
            startSession()
        } label: {
            Label("Iniciar \(selectedFormat.title)", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(track.coverColors.first ?? AppTheme.accent)
    }

    private func startSession() {
        let target = max(0, selectedFormat.targetSeconds ?? 0)
        let config = CardioWorkoutConfig(
            exercise: track.cardioExercise,
            intensity: .high,
            crossFitFormatTitle: selectedFormat.title,
            crossFitTargetSeconds: target
        )
        guard workoutStore.startCardioSession(config: config) else { return }
        watchConnectivity.startCardioOnWatch(
            workoutName: config.title,
            targetSeconds: config.targetDurationSeconds,
            exerciseName: track.name,
            activityType: .highIntensityIntervalTraining,
            locationOutdoor: false,
            crossFitFormatTitle: selectedFormat.title
        )
        NotificationService.shared.deliverCardioStartNotification(
            sessionTitle: config.title,
            athleteName: authService.currentUser?.greetingName ?? "Atleta"
        )
        workoutStore.resumeActiveWorkout()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000)
            dismiss()
        }
    }
}
