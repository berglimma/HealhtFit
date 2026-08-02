import SwiftUI

struct CardioSetupView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let exercise: CardioExercise
    @State private var selectedIntensity: CardioIntensity = .medium
    @State private var selectedDistance: RunningDistance = .five
    @State private var runningMode: RunningSetupMode = .distance(.five)
    @State private var useCalorieGoal = false
    @State private var selectedCalorieGoal = 300
    @Environment(\.dismiss) private var dismiss

    private static let caloriePresets = [100, 150, 200, 250, 300, 350, 400, 500, 600, 800]

    private enum RunningSetupMode: Hashable {
        case freeRun
        case distance(RunningDistance)

        var isFreeRun: Bool {
            if case .freeRun = self { return true }
            return false
        }
    }

    private var config: CardioWorkoutConfig {
        let distance: RunningDistance? = {
            guard exercise.supportsDistanceGoals, case .distance(let value) = runningMode else { return nil }
            return value
        }()

        return CardioWorkoutConfig(
            exercise: exercise,
            intensity: selectedIntensity,
            runningDistance: distance,
            targetCalories: useCalorieGoal ? selectedCalorieGoal : nil,
            isFreeRun: exercise.supportsDistanceGoals && runningMode.isFreeRun
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
            Text("Modo da corrida")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            Button {
                runningMode = .freeRun
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(runningMode.isFreeRun ? AppTheme.accent.opacity(0.25) : AppTheme.cardBackground)
                            .frame(width: 52, height: 52)
                        Image(systemName: "figure.run")
                            .font(.title2)
                            .foregroundStyle(runningMode.isFreeRun ? AppTheme.accent : AppTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sem meta")
                            .font(.headline)
                            .foregroundStyle(runningMode.isFreeRun ? AppTheme.accent : AppTheme.textPrimary)
                        Text("Apenas corrida — sem distância ou tempo fixo. Encerre quando quiser.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    if runningMode.isFreeRun {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .padding()
                .background(runningMode.isFreeRun ? AppTheme.accent.opacity(0.12) : AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .stroke(runningMode.isFreeRun ? AppTheme.accent : Color.clear, lineWidth: 2)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            }
            .buttonStyle(.plain)

            Text("Ou escolha uma meta em quilômetros:")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.top, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(RunningDistance.allCases) { distance in
                    Button {
                        selectedDistance = distance
                        runningMode = .distance(distance)
                    } label: {
                        let isSelected = runningMode == .distance(distance)
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
                        .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isSelected ? AppTheme.accent : AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
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
                            if exercise.supportsDistanceGoals && !runningMode.isFreeRun {
                                Text("Ritmo alvo: \(intensity.formattedPace())")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(selectedIntensity == intensity ? .white.opacity(0.9) : intensity.color)
                            } else if exercise.supportsDistanceGoals && runningMode.isFreeRun {
                                Text("Ritmo de referência: \(intensity.formattedPace())")
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
            if config.isFreeRun {
                HStack {
                    Label("Modo", systemImage: "figure.run")
                    Spacer()
                    Text("Apenas corrida")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
                HStack {
                    Label("Ritmo de referência", systemImage: "speedometer")
                    Spacer()
                    Text(selectedIntensity.formattedPace())
                        .font(.headline)
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            } else if config.isDistanceRun {
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
            } else if config.isOutdoorCyclingSession {
                HStack {
                    Label("Modo", systemImage: "bicycle")
                    Spacer()
                    Text("Outdoor com GPS")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
                }
                HStack {
                    Label("Duração sugerida", systemImage: "clock.fill")
                    Spacer()
                    Text("\(selectedIntensity.durationMinutes) min")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accent)
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
            if config.isFreeRun || config.isDistanceRun || config.isOutdoorCyclingSession {
                HStack {
                    Label("Calorias (referência)", systemImage: "flame.fill")
                    Spacer()
                    Text("Acompanhe durante o treino")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                }
            } else {
                HStack {
                    Label("Calorias estimadas", systemImage: "flame.fill")
                    Spacer()
                    Text("~\(Int(config.estimatedCalories(for: config.targetDurationSeconds))) kcal")
                        .font(.headline)
                        .foregroundStyle(AppTheme.accentSecondary)
                }
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
            guard workoutStore.startCardioSession(config: config) else { return }
            watchConnectivity.startCardioOnWatch(
                workoutName: config.title,
                targetSeconds: config.targetDurationSeconds,
                exerciseName: config.exercise.name,
                targetCalories: config.targetCalories
            )
            let athleteName = authService.currentUser?.greetingName ?? "Atleta"
            NotificationService.shared.deliverCardioStartNotification(
                sessionTitle: config.title,
                athleteName: athleteName
            )
            // MainTabView hosts ActiveCardioView for the whole session (minimize-safe).
            workoutStore.resumeActiveWorkout()
            dismiss()
        } label: {
            Label(
                {
                    if config.isDistanceRun || config.isFreeRun { return "Iniciar Corrida" }
                    if config.isOutdoorCyclingSession { return "Iniciar Pedal" }
                    return "Iniciar Cardio"
                }(),
                systemImage: "play.fill"
            )
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
                Text({
                    if exercise.supportsDistanceGoals {
                        return "\(exercise.description) · livre ou 5–40 km"
                    }
                    if exercise.supportsOutdoorGPS {
                        return "\(exercise.description) · mapa GPS"
                    }
                    return exercise.description
                }())
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
