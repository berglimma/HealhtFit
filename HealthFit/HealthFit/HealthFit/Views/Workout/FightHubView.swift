import SwiftUI

/// Rota de navegação para as modalidades de luta.
struct FightHubRoute: Hashable {}

/// Card "Luta" na lista de cardio — abre as modalidades de combate.
struct FightProgramHeroCard: View {
    private let accent = Color(red: 0.82, green: 0.20, blue: 0.22)
    var lockedByPlan: PlanTier? = nil

    var body: some View {
        WorkoutProgramHeroCard(
            title: "Luta",
            subtitle: "Boxe, Muay Thai, Jiu-Jitsu, MMA e mais — cronômetro de combate",
            accent: accent,
            imageName: "FightCoverLuta",
            systemImage: "figure.boxing",
            coverColors: [accent, Color(red: 0.30, green: 0.06, blue: 0.10)],
            eyebrow: "CRONÔMETRO DE LUTA",
            eyebrowSystemImage: "stopwatch.fill",
            footerLabels: [
                (icon: "list.bullet", text: "\(FightModality.allCases.count) modalidades")
            ],
            lockedByPlan: lockedByPlan
        )
    }
}

/// Modalidades de luta: tocar em uma já inicia a sessão e abre o cronômetro.
struct FightHubView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dismiss) private var dismiss

    private let accent = Color(red: 0.82, green: 0.20, blue: 0.22)

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                hubHeader

                VStack(alignment: .leading, spacing: 12) {
                    Text("Escolha a modalidade")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("O cronômetro abre na hora, já contando o tempo de luta.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    LazyVStack(spacing: 12) {
                        ForEach(FightModality.allCases) { modality in
                            Button {
                                startFight(modality)
                            } label: {
                                FightModalityCard(modality: modality)
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
        .navigationTitle("Luta")
        .navigationBarTitleDisplayMode(.inline)
        .requiresSubscription(.advancedModalities)
    }

    private var hubHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.boxing")
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text("LUTA")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Tempo de combate, BPM e calorias no Apple Watch")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    /// Abre direto o cronômetro: a luta não tem tela de setup.
    private func startFight(_ modality: FightModality) {
        let config = CardioWorkoutConfig(
            exercise: modality.cardioExercise,
            intensity: .high
        )
        guard workoutStore.startCardioSession(config: config) else { return }

        watchConnectivity.startCardioOnWatch(
            workoutName: config.title,
            targetSeconds: 0,
            exerciseName: modality.name
        )
        NotificationService.shared.deliverCardioStartNotification(
            sessionTitle: config.title,
            athleteName: authService.currentUser?.greetingName ?? "Atleta"
        )
        // MainTabView hospeda a ActiveCardioView durante toda a sessão.
        workoutStore.resumeActiveWorkout()
        dismiss()
    }
}

/// Card de modalidade de luta — mesmo formato hero das modalidades de cardio.
struct FightModalityCard: View {
    let modality: FightModality

    var body: some View {
        WorkoutProgramHeroCard(
            title: modality.name,
            subtitle: modality.summary,
            accent: modality.coverColors.first ?? AppTheme.accent,
            imageName: modality.coverImageName,
            systemImage: modality.icon,
            coverColors: modality.coverColors,
            eyebrow: modality.roundReference.uppercased(),
            eyebrowSystemImage: "stopwatch.fill",
            footerLabels: [
                (icon: "play.fill", text: "Iniciar cronômetro"),
                (icon: "flame.fill", text: String(format: "~%.0f kcal/min", modality.caloriesPerMinute))
            ]
        )
    }
}
