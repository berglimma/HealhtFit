import SwiftUI

struct ActiveCardioView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let config: CardioWorkoutConfig
    var onReturnToWorkoutList: (() -> Void)? = nil

    @State private var elapsedSeconds = 0
    @State private var finishedSession: WorkoutSession?
    @State private var isFinishing = false
    @State private var superationMessage: String?
    @State private var progressMessage: String?
    @State private var didCelebrateCalorieGoal = false
    @State private var lastProgressMilestone = -1

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var completedDistanceKm: Double {
        if config.isDistanceRun {
            return min(config.estimatedDistanceKm(elapsedSeconds: elapsedSeconds), config.targetDistanceKm)
        }
        return config.estimatedDistanceKm(elapsedSeconds: elapsedSeconds)
    }

    /// Prioriza apenas calorias do Apple Watch; sem Watch sincronizado fica 0.
    private var liveCalories: Double {
        max(0, watchConnectivity.watchCalories)
    }

    private var hasWatchMetrics: Bool {
        watchConnectivity.hasLiveWatchMetrics || watchConnectivity.watchCalories > 0 || watchConnectivity.watchHeartRate > 0
    }

    private var calorieProgress: Double {
        guard config.hasCalorieGoal, let target = config.targetCalories, target > 0 else { return 0 }
        return min(liveCalories / Double(target), 1.5)
    }

    private var calorieProgressClamped: Double {
        min(calorieProgress, 1.0)
    }

    private var hasExceededCalorieGoal: Bool {
        guard config.hasCalorieGoal, let target = config.targetCalories else { return false }
        return liveCalories >= Double(target)
    }

    private var primaryProgress: Double {
        if config.hasCalorieGoal {
            return calorieProgressClamped
        }
        if config.isFreeRun {
            return 0
        }
        if config.isDistanceRun, config.targetDistanceKm > 0 {
            return min(completedDistanceKm / config.targetDistanceKm, 1.0)
        }
        guard config.targetDurationSeconds > 0 else { return 0 }
        return min(Double(elapsedSeconds) / Double(config.targetDurationSeconds), 1.0)
    }

    private var showsRunningUI: Bool {
        config.isDistanceRun || config.isFreeRun
    }

    private var progressRingColor: Color {
        if hasExceededCalorieGoal { return .orange }
        if config.hasCalorieGoal { return AppTheme.accentSecondary }
        return config.intensity.color
    }

    private var currentPaceSecondsPerKm: Int {
        if config.isDistanceRun {
            return config.intensity.paceSecondsPerKm
        }
        return config.paceSecondsPerKm(
            elapsedSeconds: elapsedSeconds,
            distanceKm: max(completedDistanceKm, 0.01)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    intensityBadge
                    exerciseInfo
                    progressRing
                    calorieEvolutionSection
                    if let superationMessage {
                        superationBanner(message: superationMessage)
                    } else if let progressMessage, config.hasCalorieGoal {
                        progressBanner(message: progressMessage)
                    }
                    metricsRow
                    Spacer()
                    endButton
                }
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .navigationTitle(showsRunningUI ? "Corrida" : "Cardio")
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
            syncWithWatch()
            updateCalorieMotivation()
            syncWatchData()
            if shouldAutoEndByInactivity {
                finishCardio(autoEndedByInactivity: true)
            }
        }
        .onReceive(workoutStore.sessionAutoEnded) { ended in
            guard finishedSession == nil, !isFinishing else { return }
            isFinishing = true
            watchConnectivity.stopWorkoutOnWatch()
            finishedSession = ended
        }
        .onAppear {
            syncWithWatch()
        }
        .fullScreenCover(item: $finishedSession) { session in
            WorkoutSummaryView(
                session: session,
                onFinish: {
                    finishedSession = nil
                    dismiss()
                },
                onReturnToWorkoutList: {
                    onReturnToWorkoutList?()
                    finishedSession = nil
                    DispatchQueue.main.async {
                        dismiss()
                    }
                }
            )
        }
    }

    private var intensityBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: config.intensity.icon)
            Text("Intensidade \(config.intensity.rawValue)")
                .font(.subheadline.weight(.semibold))
            if config.isFreeRun {
                Text("·")
                Text("Livre")
                    .font(.subheadline.weight(.semibold))
            } else if config.isDistanceRun, let distance = config.runningDistance {
                Text("·")
                Text(distance.label)
                    .font(.subheadline.weight(.semibold))
            }
            if config.hasCalorieGoal, let target = config.targetCalories {
                Text("·")
                Text("\(target) kcal")
                    .font(.subheadline.weight(.semibold))
            }
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
            if config.isFreeRun {
                Text("Corrida livre — encerre quando quiser · Ritmo ref. \(config.intensity.formattedPace())")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            } else if config.isDistanceRun {
                Text("Meta: \(String(format: "%.0f", config.targetDistanceKm)) km · Ritmo \(config.intensity.formattedPace())")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            } else if config.hasCalorieGoal {
                Text("Meta calórica: \(config.targetCalories ?? 0) kcal · sincronizado com Apple Watch")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Calorias em tempo real via Apple Watch")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 14)
                .frame(width: 220, height: 220)
            Circle()
                .trim(from: 0, to: primaryProgress)
                .stroke(
                    progressRingColor,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: primaryProgress)

            if hasExceededCalorieGoal && config.hasCalorieGoal {
                Circle()
                    .trim(from: 0, to: min(calorieProgress - 1.0, 0.5))
                    .stroke(
                        Color.orange.opacity(0.6),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 236, height: 236)
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 4) {
                if config.hasCalorieGoal {
                    Text("\(Int(liveCalories))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(hasExceededCalorieGoal ? .orange : AppTheme.textPrimary)
                    Text("de \(config.targetCalories ?? 0) kcal")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("\(Int(calorieProgressClamped * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                } else if config.isFreeRun || config.isDistanceRun {
                    Text(String(format: "%.2f km", completedDistanceKm))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    if config.isDistanceRun {
                        Text("Meta: \(String(format: "%.0f", config.targetDistanceKm)) km")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        Text("Sem meta")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Text(DurationFormatting.format(seconds: elapsedSeconds))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                } else {
                    Text(DurationFormatting.format(seconds: elapsedSeconds))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Meta: \(DurationFormatting.format(seconds: config.targetDurationSeconds))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private var calorieEvolutionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Evolução calórica", systemImage: "flame.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if hasWatchMetrics {
                    Label("Apple Watch", systemImage: "applewatch")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                } else {
                    Label("Sem Apple Watch · 0 kcal", systemImage: "applewatch.slash")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            if config.hasCalorieGoal, let target = config.targetCalories {
                ProgressView(value: calorieProgressClamped)
                    .tint(hasExceededCalorieGoal ? .orange : AppTheme.accentSecondary)
                HStack {
                    Text("\(Int(liveCalories)) kcal")
                        .font(.headline)
                        .foregroundStyle(hasExceededCalorieGoal ? .orange : AppTheme.accentSecondary)
                    Spacer()
                    Text("Meta: \(target) kcal")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            } else {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(liveCalories))")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.accentSecondary)
                        Text("kcal queimadas")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(DurationFormatting.format(seconds: elapsedSeconds))
                            .font(.headline.monospaced())
                        Text("tempo")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                ProgressView(value: min(liveCalories / max(config.estimatedCalories(for: config.targetDurationSeconds), 1), 1.0))
                    .tint(AppTheme.accentSecondary)
                Text("Acompanhe a queima em tempo real — dados do relógio quando conectado.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func superationBanner(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.25), AppTheme.accentSecondary.opacity(0.15)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.45), value: superationMessage)
    }

    private func progressBanner(message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .foregroundStyle(AppTheme.accentSecondary)
            Text(message)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
                value: "\(Int(liveCalories))",
                label: "kcal",
                color: hasExceededCalorieGoal ? .orange : AppTheme.accentSecondary
            )
            if config.isDistanceRun {
                CardioMetricTile(
                    icon: "speedometer",
                    value: PaceFormatting.format(secondsPerKm: currentPaceSecondsPerKm).replacingOccurrences(of: " /km", with: ""),
                    label: "Ritmo",
                    color: config.intensity.color
                )
            } else if config.isFreeRun {
                CardioMetricTile(
                    icon: "map.fill",
                    value: String(format: "%.2f", completedDistanceKm),
                    label: "km",
                    color: config.intensity.color
                )
            } else if config.hasCalorieGoal {
                CardioMetricTile(
                    icon: "percent",
                    value: "\(Int(calorieProgressClamped * 100))",
                    label: "Meta kcal",
                    color: progressRingColor
                )
            } else {
                CardioMetricTile(
                    icon: "percent",
                    value: "\(Int(primaryProgress * 100))",
                    label: "Meta",
                    color: config.intensity.color
                )
            }
        }
    }

    private var endButton: some View {
        Button {
            finishCardio()
        } label: {
            Label(
                showsRunningUI ? "Finalizar Corrida" : "Finalizar Cardio",
                systemImage: "flag.checkered"
            )
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private func syncWithWatch() {
        watchConnectivity.syncCardioProgress(
            elapsedSeconds: elapsedSeconds,
            targetSeconds: config.targetDurationSeconds,
            currentCalories: liveCalories,
            targetCalories: config.targetCalories
        )
    }

    private func updateCalorieMotivation() {
        guard config.hasCalorieGoal, let target = config.targetCalories else { return }

        let percent = Int((liveCalories / Double(target)) * 100)

        if hasExceededCalorieGoal {
            if !didCelebrateCalorieGoal {
                didCelebrateCalorieGoal = true
                superationMessage = MotivationMessages.cardioCalorieExceededMessage(
                    currentCalories: Int(liveCalories),
                    targetCalories: target
                )
                progressMessage = nil
            }
            return
        }

        superationMessage = nil
        let milestone = (percent / 25) * 25
        if milestone > lastProgressMilestone && milestone > 0 {
            lastProgressMilestone = milestone
            progressMessage = MotivationMessages.cardioCalorieProgressMessage(percent: milestone)
        }
    }

    private func syncWatchData() {
        if watchConnectivity.watchHeartRate > 0 {
            workoutStore.addHeartRateSample(watchConnectivity.watchHeartRate)
        }
        workoutStore.updateCalories(watchConnectivity.watchCalories)
    }

    private var shouldAutoEndByInactivity: Bool {
        guard let startedAt = workoutStore.activeSession?.startedAt, !isFinishing else { return false }
        return Date.now.timeIntervalSince(startedAt) >= WorkoutStore.autoEndInactivityLimit
    }

    private func finishCardio(autoEndedByInactivity: Bool = false) {
        guard !isFinishing else { return }
        isFinishing = true

        watchConnectivity.stopWorkoutOnWatch()

        guard var session = workoutStore.activeSession else {
            if finishedSession == nil,
               let last = workoutStore.sessionHistory.first,
               last.autoEndedByInactivity {
                finishedSession = last
            } else if finishedSession == nil {
                dismiss()
            }
            return
        }

        let distanceKm = completedDistanceKm
        let pace = config.paceSecondsPerKm(elapsedSeconds: elapsedSeconds, distanceKm: max(distanceKm, 0.01))
        let goalReached: Bool = {
            if autoEndedByInactivity { return false }
            if config.hasCalorieGoal, let target = config.targetCalories {
                return liveCalories >= Double(target) * 0.98
            }
            if config.isFreeRun {
                return elapsedSeconds >= 60
            }
            if config.isDistanceRun {
                return distanceKm >= config.targetDistanceKm * 0.98
            }
            return elapsedSeconds >= config.targetDurationSeconds / 2
        }()

        session.endedAt = .now
        session.caloriesBurned = watchConnectivity.watchCalories
        session.completedDistanceKm = (config.isDistanceRun || config.isFreeRun) ? distanceKm : nil
        session.averagePaceSecondsPerKm = (config.isDistanceRun || config.isFreeRun) ? pace : nil
        session.cardioIntensityLabel = config.intensity.rawValue
        session.targetCalories = config.targetCalories
        session.exerciseRecords = [
            ExerciseSessionRecord(
                exerciseId: config.exercise.id,
                exerciseName: {
                    if config.isFreeRun {
                        return "Corrida livre (\(config.intensity.rawValue))"
                    }
                    if config.isDistanceRun {
                        return "\(config.exercise.name) \(String(format: "%.0f", config.targetDistanceKm)) km (\(config.intensity.rawValue))"
                    }
                    return "\(config.exercise.name) (\(config.intensity.rawValue))"
                }(),
                elapsedSeconds: elapsedSeconds,
                restSeconds: 0,
                isCompleted: goalReached
            )
        ]
        session.completedExercises = session.exerciseRecords.filter(\.isCompleted).count
        if autoEndedByInactivity {
            session.endedEarly = true
            session.autoEndedByInactivity = true
            session.earlyEndJustification = WorkoutStore.autoEndJustification
        }

        Task {
            await healthKitManager.saveWorkout(
                duration: session.duration,
                calories: session.caloriesBurned,
                heartRate: session.averageHeartRate,
                activityType: config.isDistanceRun ? .running : .walking
            )
        }

        NotificationService.shared.deliverWorkoutEndNotification(
            session: session,
            athleteName: authService.currentUser?.greetingName ?? "Atleta"
        )

        workoutStore.endSession(persisting: session)
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
                .minimumScaleFactor(0.7)
                .lineLimit(1)
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
