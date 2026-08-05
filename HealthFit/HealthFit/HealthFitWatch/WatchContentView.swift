import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject var workoutManager: WatchWorkoutManager

    var body: some View {
        TabView {
            activeWorkoutTab
            metricsTab
        }
        .tabViewStyle(.verticalPage)
    }

    private var activeWorkoutTab: some View {
        VStack(spacing: 10) {
            if workoutManager.isActive {
                Text(workoutManager.workoutName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if workoutManager.isResting {
                    restSection
                } else if workoutManager.isMeditationWorkout {
                    meditationSection
                } else if workoutManager.isCardioWorkout {
                    cardioSection
                } else {
                    strengthSection
                }

                if !workoutManager.isMeditationWorkout {
                    compactMetricsRow
                }

                Button("Encerrar") {
                    workoutManager.stopWorkout()
                }
                .tint(.red)
                .font(.caption2)
            } else {
                Image(systemName: "heart.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("HealthFit")
                    .font(.headline)
                Text("Aguardando treino do iPhone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private var strengthSection: some View {
        VStack(spacing: 6) {
            Label("Cronômetro", systemImage: "stopwatch.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(formatDuration(workoutManager.workoutElapsedSeconds))
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(.green)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if !workoutManager.currentExerciseName.isEmpty {
                Text(workoutManager.currentExerciseName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(formatDuration(workoutManager.exerciseElapsedSeconds))
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var meditationSection: some View {
        let accent = meditationColor(from: workoutManager.meditationColorName)
        let remaining = max(workoutManager.meditationTargetSeconds - workoutManager.workoutElapsedSeconds, 0)
        let progress = workoutManager.meditationTargetSeconds > 0
            ? Double(workoutManager.workoutElapsedSeconds) / Double(workoutManager.meditationTargetSeconds)
            : 0

        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: workoutManager.meditationTopicIcon)
                    .font(.caption)
                Text(workoutManager.meditationTopicName)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(accent.opacity(0.2))
            .clipShape(Capsule())

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(formatDuration(remaining))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(accent)
                    Text("restante")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Etapa \(workoutManager.meditationPromptIndex + 1)/\(workoutManager.meditationTotalPrompts)")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(accent.opacity(0.85))

            if !workoutManager.meditationPrompt.isEmpty {
                Text(workoutManager.meditationPrompt)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func meditationColor(from name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "pink": return .pink
        case "indigo": return .indigo
        case "teal": return .teal
        default: return .purple
        }
    }

    private var cardioSection: some View {
        let hasCalorieGoal = workoutManager.cardioTargetCalories > 0
        let calorieProgress = hasCalorieGoal
            ? min(workoutManager.calories / Double(workoutManager.cardioTargetCalories), 1.0)
            : 0

        return VStack(spacing: 6) {
            if workoutManager.isWaterSportMode {
                waterSportCardioExtras
            }

            if hasCalorieGoal {
                Label("Meta calórica", systemImage: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)

                Text("\(Int(workoutManager.calories))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(workoutManager.calories >= Double(workoutManager.cardioTargetCalories) ? .orange : .primary)

                Text("de \(workoutManager.cardioTargetCalories) kcal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ProgressView(value: calorieProgress)
                    .tint(workoutManager.calories >= Double(workoutManager.cardioTargetCalories) ? .orange : .orange.opacity(0.8))

                if !workoutManager.cardioSuperationMessage.isEmpty {
                    Text(workoutManager.cardioSuperationMessage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
            } else {
                Label("Cronômetro", systemImage: "stopwatch.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(formatDuration(workoutManager.workoutElapsedSeconds))
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)

                if workoutManager.cardioTargetSeconds > 0 {
                    Text("Meta: \(formatDuration(workoutManager.cardioTargetSeconds))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ProgressView(
                        value: Double(workoutManager.workoutElapsedSeconds),
                        total: Double(workoutManager.cardioTargetSeconds)
                    )
                    .tint(.orange)
                }
            }

            Text(formatDuration(workoutManager.workoutElapsedSeconds))
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            if !workoutManager.currentExerciseName.isEmpty {
                Text(workoutManager.currentExerciseName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
    }

    private var waterSportCardioExtras: some View {
        VStack(spacing: 6) {
            Text(workoutManager.isKitesurfMode ? "Kitesurf" : "Surf")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.cyan)

            HStack(spacing: 10) {
                VStack(spacing: 1) {
                    Text("\(workoutManager.waterJumpCount)")
                        .font(.title3.bold())
                    Text("saltos")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", workoutManager.waterMaxJumpMeters))
                        .font(.title3.bold())
                    Text("m max")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 1) {
                    Text(String(format: "%.1f", workoutManager.waterLiveAccelG))
                        .font(.title3.bold())
                    Text("g")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            Button("Marcar salto") {
                workoutManager.markWaterSportJump()
            }
            .tint(.orange)
            .font(.caption2)

            Button("Sincronizar") {
                workoutManager.requestPhoneSyncFromWatch()
            }
            .font(.caption2)

            if !workoutManager.watchSyncStatus.isEmpty {
                Text(workoutManager.watchSyncStatus)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var restSection: some View {
        VStack(spacing: 6) {
            Text(formatDuration(workoutManager.workoutElapsedSeconds))
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("Descanso")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !workoutManager.restExerciseName.isEmpty {
                Text(workoutManager.restExerciseName)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Text(restTimeText)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundStyle(workoutManager.isRestOvertime ? .red : .green)

            if workoutManager.isRestOvertime {
                Text("Hora de voltar!")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var compactMetricsRow: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(Int(workoutManager.heartRate))")
                    .font(.title3.bold())
                    .foregroundStyle(.red)
                Text("BPM")
                    .font(.caption2)
            }

            VStack(spacing: 2) {
                Text("\(Int(workoutManager.calories))")
                    .font(.title3.bold())
                Text("kcal")
                    .font(.caption2)
            }
        }
    }

    private var restTimeText: String {
        if workoutManager.isRestOvertime {
            let seconds = workoutManager.restOvertimeSeconds
            let minutes = max(seconds, 0) / 60
            let secs = max(seconds, 0) % 60
            return String(format: "+%02d:%02d", minutes, secs)
        }
        let seconds = workoutManager.restRemainingSeconds
        let minutes = max(seconds, 0) / 60
        let secs = max(seconds, 0) % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let total = max(seconds, 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }

    private var metricsTab: some View {
        VStack(spacing: 8) {
            Label("Sincronizado", systemImage: "iphone.and.arrow.forward")
                .font(.caption)
            Text("Treino, cardio, meditação e cronômetro sincronizados com o iPhone.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

#Preview {
    WatchContentView()
        .environmentObject(WatchWorkoutManager())
}
