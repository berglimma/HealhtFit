import SwiftUI

struct ActiveCardioView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let config: CardioWorkoutConfig

    @State private var elapsedSeconds = 0
    @State private var finishedSession: WorkoutSession?
    @State private var isFinishing = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var progress: Double {
        guard config.targetDurationSeconds > 0 else { return 0 }
        return min(Double(elapsedSeconds) / Double(config.targetDurationSeconds), 1.0)
    }

    private var estimatedCalories: Double {
        config.estimatedCalories(for: elapsedSeconds)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 28) {
                    intensityBadge
                    exerciseInfo
                    timerRing
                    metricsRow
                    Spacer()
                    endButton
                }
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .navigationTitle("Cardio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Encerrar") {
                        finishCardio()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .onReceive(clock) { _ in
            elapsedSeconds += 1
            syncWatchData()
        }
        .fullScreenCover(item: $finishedSession) { session in
            WorkoutSummaryView(session: session) {
                finishedSession = nil
                dismiss()
            }
        }
    }

    private var intensityBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: config.intensity.icon)
            Text("Intensidade \(config.intensity.rawValue)")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(config.intensity.color)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(config.intensity.color.opacity(0.15))
        .clipShape(Capsule())
    }

    private var exerciseInfo: some View {
        VStack(spacing: 8) {
            Image(systemName: config.exercise.icon)
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.accentSecondary)
            Text(config.exercise.name)
                .font(.title.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(config.exercise.description)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 14)
                .frame(width: 220, height: 220)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    config.intensity.color,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            VStack(spacing: 4) {
                Text(DurationFormatting.format(seconds: elapsedSeconds))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Meta: \(DurationFormatting.format(seconds: config.targetDurationSeconds))")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 16) {
            CardioMetricTile(
                icon: "heart.fill",
                value: "\(Int(watchConnectivity.watchHeartRate))",
                label: "BPM",
                color: .red
            )
            CardioMetricTile(
                icon: "flame.fill",
                value: "\(Int(estimatedCalories))",
                label: "kcal",
                color: AppTheme.accentSecondary
            )
            CardioMetricTile(
                icon: "percent",
                value: "\(Int(progress * 100))",
                label: "Meta",
                color: config.intensity.color
            )
        }
    }

    private var endButton: some View {
        Button {
            finishCardio()
        } label: {
            Label("Finalizar Cardio", systemImage: "flag.checkered")
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private func syncWatchData() {
        if watchConnectivity.watchHeartRate > 0 {
            workoutStore.addHeartRateSample(watchConnectivity.watchHeartRate)
        }
        workoutStore.updateCalories(max(estimatedCalories, watchConnectivity.watchCalories))
    }

    private func finishCardio() {
        guard !isFinishing else { return }
        isFinishing = true

        watchConnectivity.stopWorkoutOnWatch()

        guard var session = workoutStore.activeSession else {
            dismiss()
            return
        }

        session.endedAt = .now
        session.caloriesBurned = max(estimatedCalories, session.caloriesBurned)
        session.exerciseRecords = [
            ExerciseSessionRecord(
                exerciseId: config.exercise.id,
                exerciseName: "\(config.exercise.name) (\(config.intensity.rawValue))",
                elapsedSeconds: elapsedSeconds,
                restSeconds: 0,
                isCompleted: elapsedSeconds >= config.targetDurationSeconds / 2
            )
        ]
        session.completedExercises = session.exerciseRecords.filter(\.isCompleted).count

        Task {
            await healthKitManager.saveWorkout(
                duration: session.duration,
                calories: session.caloriesBurned,
                heartRate: session.averageHeartRate
            )
        }

        NotificationService.shared.deliverWorkoutEndNotification(
            session: session,
            athleteName: authService.currentUser?.name ?? "Atleta"
        )

        workoutStore.endSession()
        finishedSession = session
    }
}

private struct CardioMetricTile: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
