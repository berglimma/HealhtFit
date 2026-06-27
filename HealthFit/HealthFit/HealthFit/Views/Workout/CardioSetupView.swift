import SwiftUI

struct CardioSetupView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let exercise: CardioExercise
    @State private var selectedIntensity: CardioIntensity = .medium
    @State private var showActiveCardio = false

    private var config: CardioWorkoutConfig {
        CardioWorkoutConfig(exercise: exercise, intensity: selectedIntensity)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                intensitySection
                summarySection
                startButton
            }
            .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .adaptiveContentWidth()
        }
        .background(AppTheme.background)
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(isPresented: $showActiveCardio) {
            ActiveCardioView(config: config)
        }
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.2))
                    .frame(width: 72, height: 72)
                Image(systemName: exercise.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                Text(exercise.description)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                Label(String(format: "~%.0f kcal/min (média)", exercise.caloriesPerMinute), systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.accentSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Intensidade")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(CardioIntensity.allCases) { intensity in
                Button {
                    selectedIntensity = intensity
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: intensity.icon)
                            .font(.title2)
                            .foregroundStyle(selectedIntensity == intensity ? .white : intensity.color)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(intensity.rawValue)
                                .font(.headline)
                                .foregroundStyle(selectedIntensity == intensity ? .white : AppTheme.textPrimary)
                            Text(intensity.description)
                                .font(.caption)
                                .foregroundStyle(selectedIntensity == intensity ? .white.opacity(0.85) : AppTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                            Text("\(intensity.durationMinutes) min sugeridos")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(selectedIntensity == intensity ? .white.opacity(0.9) : intensity.color)
                        }

                        Spacer()

                        if selectedIntensity == intensity {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding()
                    .background(selectedIntensity == intensity ? intensity.color : AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summarySection: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Duração sugerida", systemImage: "clock.fill")
                Spacer()
                Text("\(selectedIntensity.durationMinutes) min")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
            }
            HStack {
                Label("Calorias estimadas", systemImage: "flame.fill")
                Spacer()
                Text("~\(Int(config.estimatedCalories(for: config.targetDurationSeconds))) kcal")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accentSecondary)
            }
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var startButton: some View {
        Button {
            workoutStore.startCardioSession(config: config)
            watchConnectivity.startWorkoutOnWatch(workoutName: config.title)
            let athleteName = authService.currentUser?.name ?? "Atleta"
            NotificationService.shared.deliverWorkoutStartNotification(
                workoutTitle: config.title,
                athleteName: athleteName
            )
            showActiveCardio = true
        } label: {
            Label("Iniciar Cardio", systemImage: "play.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

struct CardioExerciseCard: View {
    let exercise: CardioExercise

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.accentSecondary.opacity(0.2))
                    .frame(width: 52, height: 52)
                Image(systemName: exercise.icon)
                    .font(.title2)
                    .foregroundStyle(AppTheme.accentSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Text(exercise.description)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}
