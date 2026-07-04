import SwiftUI

struct CardioSetupView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let exercise: CardioExercise
    @State private var selectedIntensity: CardioIntensity = .medium
    @State private var selectedDistance: RunningDistance = .five
    @State private var useDistanceGoal = true
    @State private var useCalorieGoal = false
    @State private var selectedCalorieGoal = 300
    @State private var showActiveCardio = false

    private static let caloriePresets = [100, 150, 200, 250, 300, 350, 400, 500, 600, 800]

    private var config: CardioWorkoutConfig {
        CardioWorkoutConfig(
            exercise: exercise,
            intensity: selectedIntensity,
            runningDistance: exercise.supportsDistanceGoals && useDistanceGoal ? selectedDistance : nil,
            targetCalories: useCalorieGoal ? selectedCalorieGoal : nil
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                if exercise.supportsDistanceGoals {
                    distanceSection
                }
                calorieGoalSection
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

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Distância da corrida")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Toggle("Por km", isOn: $useDistanceGoal)
                    .labelsHidden()
                    .tint(AppTheme.accent)
            }

            Text(useDistanceGoal ? "Escolha a meta em quilômetros para preparação de maratona." : "Modo por tempo — use a intensidade abaixo.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            if useDistanceGoal {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(RunningDistance.allCases) { distance in
                        Button {
                            selectedDistance = distance
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: distance.icon)
                                    .font(.title2)
                                Text(distance.label)
                                    .font(.headline)
                                Text(distance.marathonRole)
                                    .font(.caption2)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .foregroundStyle(selectedDistance == distance ? .white : AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(selectedDistance == distance ? AppTheme.accent : AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var calorieGoalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Meta de calorias")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Toggle("Meta kcal", isOn: $useCalorieGoal)
                    .labelsHidden()
                    .tint(AppTheme.accentSecondary)
            }

            if useCalorieGoal {
                Text("Defina quantas calorias pretende gastar neste cardio.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Self.caloriePresets, id: \.self) { kcal in
                        Button {
                            selectedCalorieGoal = kcal
                        } label: {
                            Text("\(kcal)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedCalorieGoal == kcal ? .white : AppTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedCalorieGoal == kcal ? AppTheme.accentSecondary : AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Stepper(value: $selectedCalorieGoal, in: 50...1200, step: 25) {
                    HStack {
                        Label("Personalizado", systemImage: "flame.fill")
                        Spacer()
                        Text("\(selectedCalorieGoal) kcal")
                            .font(.headline)
                            .foregroundStyle(AppTheme.accentSecondary)
                    }
                }
                .foregroundStyle(AppTheme.textPrimary)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "applewatch")
                        .foregroundStyle(AppTheme.accent)
                    Text("Sem meta definida — as calorias serão acompanhadas em tempo real pelo Apple Watch durante o treino.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
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
                            if exercise.supportsDistanceGoals && useDistanceGoal {
                                Text("Ritmo alvo: \(intensity.formattedPace())")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(selectedIntensity == intensity ? .white.opacity(0.9) : intensity.color)
                            } else {
                                Text("\(intensity.durationMinutes) min sugeridos")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(selectedIntensity == intensity ? .white.opacity(0.9) : intensity.color)
                            }
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
            if config.isDistanceRun {
                HStack {
                    Label("Distância meta", systemImage: "figure.run")
                    Spacer()
                    Text(selectedDistance.label)
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
                HStack {
                    Label("Tempo estimado", systemImage: "clock.fill")
                    Spacer()
                    Text(PaceFormatting.formatDuration(seconds: config.targetDurationSeconds))
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
                HStack {
                    Label("Ritmo alvo", systemImage: "speedometer")
                    Spacer()
                    Text(selectedIntensity.formattedPace())
                        .font(.headline)
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            } else {
                HStack {
                    Label("Duração sugerida", systemImage: "clock.fill")
                    Spacer()
                    Text("\(selectedIntensity.durationMinutes) min")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
            }
            HStack {
                Label("Calorias estimadas", systemImage: "flame.fill")
                Spacer()
                Text("~\(Int(config.estimatedCalories(for: config.targetDurationSeconds))) kcal")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accentSecondary)
            }
            if config.hasCalorieGoal {
                HStack {
                    Label("Meta de calorias", systemImage: "target")
                    Spacer()
                    Text("\(config.targetCalories ?? 0) kcal")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
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
            watchConnectivity.startCardioOnWatch(
                workoutName: config.title,
                targetSeconds: config.targetDurationSeconds,
                exerciseName: config.exercise.name,
                targetCalories: config.targetCalories
            )
            let athleteName = authService.currentUser?.name ?? "Atleta"
            NotificationService.shared.deliverWorkoutStartNotification(
                workoutTitle: config.title,
                athleteName: athleteName
            )
            showActiveCardio = true
        } label: {
            Label(config.isDistanceRun ? "Iniciar Corrida" : "Iniciar Cardio", systemImage: "play.fill")
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
                Text(exercise.supportsDistanceGoals
                     ? "\(exercise.description) · 5–25 km"
                     : exercise.description)
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
