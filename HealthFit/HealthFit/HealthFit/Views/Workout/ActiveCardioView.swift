import HealthKit
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
    /// When hosted as a persistent overlay (MainTabView), close the host instead of `dismiss()`.
    var onHostClose: (() -> Void)? = nil
    /// Incremented by conflict alert / banner to finish without re-presenting the UI.
    var openFinishTick: Int = 0

    @StateObject private var runTracker = RunTrackingService()
    @State private var elapsedSeconds = 0
    @State private var isPaused = false
    @State private var pauseStartedAt: Date?
    @State private var totalPausedSeconds = 0
    @State private var finishedSession: WorkoutSession?
    @State private var isFinishing = false
    @State private var superationMessage: String?
    @State private var progressMessage: String?
    @State private var didCelebrateCalorieGoal = false
    @State private var lastProgressMilestone = -1
    @State private var lastHandledFinishTick = 0

    /// Side-effects; display uses wall clock from session start minus pauses.
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isRunningSession: Bool { config.isRunningSession }
    private var isOutdoorGPS: Bool { config.isOutdoorGPSCardio }
    private var isOutdoorCycling: Bool { config.isOutdoorCyclingSession }
    private var isOutdoorWalking: Bool { config.isOutdoorWalkingSession }
    private var trackingModality: OutdoorCardioModality {
        config.outdoorTrackingModality
    }

    private var completedDistanceKm: Double {
        if isOutdoorGPS, let gpsKm = runTracker.gpsDistanceKmIfAvailable {
            if config.isDistanceRun {
                return min(gpsKm, config.targetDistanceKm)
            }
            return gpsKm
        }
        if config.isDistanceRun {
            return min(config.estimatedDistanceKm(elapsedSeconds: elapsedSeconds), config.targetDistanceKm)
        }
        if isOutdoorCycling {
            return 0
        }
        return config.estimatedDistanceKm(elapsedSeconds: elapsedSeconds)
    }

    /// Watch quando disponível; no outdoor, estima por MET × peso × tempo.
    private var liveCalories: Double {
        let watch = max(0, watchConnectivity.watchCalories)
        if watch > 0 { return watch }
        if isOutdoorGPS {
            let weight = authService.currentUser?.weight ?? 70
            let estimated = RunTrackingMath.estimatedCalories(
                weightKg: weight,
                elapsedSeconds: elapsedSeconds,
                activityState: runTracker.activityState,
                speedMetersPerSecond: runTracker.currentSpeedMetersPerSecond > 0
                    ? runTracker.currentSpeedMetersPerSecond
                    : nil,
                modality: trackingModality
            )
            let paceBased = config.estimatedCalories(for: elapsedSeconds)
            return max(estimated, paceBased * 0.85)
        }
        return 0
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
        if config.isFreeRun || isOutdoorCycling {
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

    private var navigationTitleText: String {
        if showsRunningUI { return "Corrida" }
        if isOutdoorCycling || isOutdoorWalking { return config.exercise.name }
        return "Cardio"
    }

    private var progressRingColor: Color {
        if hasExceededCalorieGoal { return .orange }
        if config.hasCalorieGoal { return AppTheme.accentSecondary }
        return config.intensity.color
    }

    private var currentPaceSecondsPerKm: Int {
        if isOutdoorGPS, completedDistanceKm > 0.05 {
            return config.paceSecondsPerKm(
                elapsedSeconds: elapsedSeconds,
                distanceKm: completedDistanceKm
            )
        }
        if config.isDistanceRun {
            return config.intensity.paceSecondsPerKm
        }
        return config.paceSecondsPerKm(
            elapsedSeconds: elapsedSeconds,
            distanceKm: max(completedDistanceKm, 0.01)
        )
    }

    private var liveSpeedKmh: Double {
        max(0, runTracker.currentSpeedMetersPerSecond * 3.6)
    }

    private var liveSteps: Int {
        if runTracker.stepCount > 0 { return runTracker.stepCount }
        return RunTrackingMath.estimatedSteps(distanceKm: completedDistanceKm)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if isOutdoorGPS {
                            runMapSection
                            activityStateBanner
                            liveTimerBanner
                        }
                        intensityBadge
                        if !isOutdoorGPS {
                            exerciseInfo
                        }
                        progressRing
                        calorieEvolutionSection
                        if let superationMessage {
                            superationBanner(message: superationMessage)
                        } else if let progressMessage, config.hasCalorieGoal {
                            progressBanner(message: progressMessage)
                        }
                        metricsRow
                        if isOutdoorGPS {
                            runExtraMetricsRow
                        }
                        pauseControls
                        endButton
                    }
                    .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                    .adaptiveContentWidth()
                }
            }
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Minimizar") {
                        // Only flip the flag — MainTabView keeps this view mounted and hides it.
                        workoutStore.minimizeActiveWorkout()
                    }
                    .disabled(isFinishing)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Encerrar") {
                        finishCardio()
                    }
                    .foregroundStyle(.red)
                    .disabled(isFinishing)
                }
            }
        }
        .onReceive(clock) { _ in
            if !isPaused {
                elapsedSeconds = activeElapsedSeconds()
            }
            syncWithWatch()
            if !isPaused {
                updateCalorieMotivation()
            }
            syncWatchData()
            if shouldAutoEndByInactivity {
                finishCardio(autoEndedByInactivity: true)
            }
        }
        .onReceive(workoutStore.sessionAutoEnded) { ended in
            guard finishedSession == nil, !isFinishing else { return }
            isFinishing = true
            if workoutStore.isActiveWorkoutMinimized {
                workoutStore.resumeActiveWorkout()
            }
            runTracker.stop()
            watchConnectivity.stopWorkoutOnWatch()
            finishedSession = ended
        }
        .onAppear {
            elapsedSeconds = activeElapsedSeconds()
            syncWithWatch()
            if isOutdoorGPS {
                runTracker.prepareForSession(modality: trackingModality)
                runTracker.start(modality: trackingModality)
            }
            handleExternalFinishTickIfNeeded()
        }
        .onDisappear {
            // Hosted minimize keeps this view mounted; only stop if the session is gone.
            guard finishedSession == nil else { return }
            if workoutStore.activeSession != nil { return }
            runTracker.stop()
        }
        .onChange(of: openFinishTick) { _, tick in
            guard tick > 0 else { return }
            handleExternalFinishTickIfNeeded()
        }
        .fullScreenCover(item: $finishedSession) { session in
            WorkoutSummaryView(
                session: session,
                onFinish: {
                    finishedSession = nil
                    closeHostedWorkout()
                },
                onReturnToWorkoutList: {
                    onReturnToWorkoutList?()
                    finishedSession = nil
                    DispatchQueue.main.async {
                        closeHostedWorkout()
                    }
                }
            )
        }
    }

    private func closeHostedWorkout() {
        if let onHostClose {
            onHostClose()
        } else {
            dismiss()
        }
    }

    private func handleExternalFinishTickIfNeeded() {
        guard openFinishTick > lastHandledFinishTick, !isFinishing else { return }
        lastHandledFinishTick = openFinishTick
        finishCardio()
    }

    private var runMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let message = runTracker.locationDeniedMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "location.slash.fill")
                        .foregroundStyle(AppTheme.accentSecondary)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RunRouteMapView(
                    routePoints: runTracker.routePoints,
                    userCoordinate: runTracker.currentLocation?.coordinate,
                    followUser: true,
                    showsUserLocation: true,
                    height: 240,
                    performanceMetric: config.routePerformanceMetric
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                if runTracker.routePoints.count >= 2 {
                    performanceLegend
                }
            }
        }
    }

    private var performanceLegend: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(RoutePerformanceColoring.color(for: .optimal))
                .frame(width: 7, height: 7)
            Circle()
                .fill(RoutePerformanceColoring.color(for: .intermediate))
                .frame(width: 7, height: 7)
            Circle()
                .fill(RoutePerformanceColoring.color(for: .below))
                .frame(width: 7, height: 7)
            Circle()
                .fill(RoutePerformanceColoring.color(for: .paused))
                .frame(width: 7, height: 7)
            Text(RoutePerformanceColoring.legendText)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 4)
    }

    private var activityStateBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: isPaused ? "pause.circle.fill" : runTracker.activityState.systemImage)
                .font(.title3)
            Text(isPaused ? "Pausado" : runTracker.activityState.label)
                .font(.headline)
            Spacer()
            if !isPaused, runTracker.currentSpeedMetersPerSecond > 0 {
                Text(String(format: "%.1f km/h", runTracker.currentSpeedMetersPerSecond * 3.6))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .foregroundStyle(activityStateColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(activityStateColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var activityStateColor: Color {
        if isPaused {
            return Color(red: 0.20, green: 0.48, blue: 0.96)
        }
        switch runTracker.activityState {
        case .running, .hardCycling: return AppTheme.accent
        case .walking, .lightCycling, .moving: return AppTheme.accentSecondary
        case .stationary: return .gray
        case .unknown: return AppTheme.textSecondary
        }
    }

    private var liveTimerBanner: some View {
        VStack(spacing: 4) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(DurationFormatting.formatElapsedClock(seconds: activeElapsedSeconds(at: context.date)))
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(isPaused ? AppTheme.textSecondary : AppTheme.textPrimary)
                    .contentTransition(.numericText())
            }
            Text(isPaused ? "Treino pausado" : "Tempo em tempo real")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            if isPaused || totalPausedSeconds > 0 {
                pauseChronometer
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var pauseChronometer: some View {
        VStack(spacing: 2) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(DurationFormatting.formatElapsedClock(seconds: pauseElapsedSeconds(at: context.date)))
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.35, green: 0.58, blue: 1.0))
                    .contentTransition(.numericText())
            }
            Text("Tempo de pausa")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(.top, 6)
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
                .frame(width: 200, height: 200)
            Circle()
                .trim(from: 0, to: primaryProgress)
                .stroke(
                    progressRingColor,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: primaryProgress)

            if hasExceededCalorieGoal && config.hasCalorieGoal {
                Circle()
                    .trim(from: 0, to: min(calorieProgress - 1.0, 0.5))
                    .stroke(
                        Color.orange.opacity(0.6),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 216, height: 216)
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 4) {
                if config.hasCalorieGoal {
                    Text("\(Int(liveCalories))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(hasExceededCalorieGoal ? .orange : AppTheme.textPrimary)
                    Text("de \(config.targetCalories ?? 0) kcal")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("\(Int(calorieProgressClamped * 100))%")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accentSecondary)
                } else if config.isFreeRun || config.isDistanceRun || isOutdoorCycling {
                    Text(String(format: "%.2f km", completedDistanceKm))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    if config.isDistanceRun {
                        Text("Meta: \(String(format: "%.0f", config.targetDistanceKm)) km")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        Text(runTracker.gpsDistanceKmIfAvailable != nil ? "GPS" : "Estimado")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    if !isOutdoorGPS {
                        Text(DurationFormatting.formatElapsedClock(seconds: elapsedSeconds))
                            .font(.caption.weight(.semibold).monospaced())
                            .foregroundStyle(isPaused ? AppTheme.textSecondary : AppTheme.accent)
                        if isPaused || totalPausedSeconds > 0 {
                            pauseChronometer
                        }
                    }
                } else {
                    Text(DurationFormatting.formatElapsedClock(seconds: elapsedSeconds))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(isPaused ? AppTheme.textSecondary : AppTheme.textPrimary)
                    Text("Meta: \(DurationFormatting.format(seconds: config.targetDurationSeconds))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    if isPaused || totalPausedSeconds > 0 {
                        pauseChronometer
                    }
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
                } else if isOutdoorGPS {
                    Label("Estimativa ao vivo", systemImage: "flame")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
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
                        Text(DurationFormatting.formatElapsedClock(seconds: elapsedSeconds))
                            .font(.headline.monospaced())
                        Text("tempo")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                ProgressView(value: min(liveCalories / max(config.estimatedCalories(for: max(config.targetDurationSeconds, 1)), 1), 1.0))
                    .tint(AppTheme.accentSecondary)
                Text(
                    isOutdoorGPS
                        ? "Calorias ao vivo via Watch ou estimativa MET × peso × tempo."
                        : "Acompanhe a queima em tempo real — dados do relógio quando conectado."
                )
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
        HStack(spacing: 12) {
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
            if config.isDistanceRun || (isOutdoorGPS && !isOutdoorCycling) {
                CardioMetricTile(
                    icon: "speedometer",
                    value: PaceFormatting.format(secondsPerKm: currentPaceSecondsPerKm).replacingOccurrences(of: " /km", with: ""),
                    label: "Ritmo",
                    color: config.intensity.color
                )
            } else if isOutdoorCycling {
                CardioMetricTile(
                    icon: "speedometer",
                    value: String(format: "%.1f", liveSpeedKmh),
                    label: "km/h",
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

    private var runExtraMetricsRow: some View {
        HStack(spacing: 12) {
            if isOutdoorCycling {
                CardioMetricTile(
                    icon: "bicycle",
                    value: String(format: "%.1f", liveSpeedKmh),
                    label: "km/h",
                    color: AppTheme.accent
                )
            } else {
                CardioMetricTile(
                    icon: "figure.walk",
                    value: "\(liveSteps)",
                    label: "Passos",
                    color: AppTheme.accent
                )
            }
            CardioMetricTile(
                icon: "map.fill",
                value: String(format: "%.2f", completedDistanceKm),
                label: "km",
                color: config.intensity.color
            )
            CardioMetricTile(
                icon: "clock.fill",
                value: DurationFormatting.formatElapsedClock(seconds: elapsedSeconds),
                label: "Tempo",
                color: AppTheme.accentSecondary
            )
        }
    }

    private var endButton: some View {
        Button {
            finishCardio()
        } label: {
            Label(
                {
                    if showsRunningUI { return "Finalizar Corrida" }
                    if isOutdoorCycling { return "Finalizar Pedal" }
                    if isOutdoorWalking { return "Finalizar Caminhada" }
                    return "Finalizar Cardio"
                }(),
                systemImage: "flag.checkered"
            )
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(isFinishing)
    }

    private var pauseControls: some View {
        Button {
            togglePause()
        } label: {
            Label(
                isPaused ? "Retomar" : "Pausar",
                systemImage: isPaused ? "play.fill" : "pause.fill"
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .font(.headline)
            .foregroundStyle(isPaused ? AppTheme.accent : AppTheme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isPaused ? AppTheme.accent.opacity(0.18) : AppTheme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isPaused ? AppTheme.accent.opacity(0.45) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isFinishing)
        .accessibilityLabel(isPaused ? "Retomar treino" : "Pausar treino")
    }

    /// Tempo ativo: parede desde o início menos todos os intervalos de pausa (inclui pausa aberta).
    private func activeElapsedSeconds(at date: Date = Date()) -> Int {
        guard let startedAt = workoutStore.activeSession?.startedAt else {
            return max(0, elapsedSeconds)
        }
        let wall = max(0, Int(date.timeIntervalSince(startedAt)))
        return max(0, wall - pausedSecondsAccumulated(at: date))
    }

    private func pausedSecondsAccumulated(at date: Date = Date()) -> Int {
        var total = max(0, totalPausedSeconds)
        if let pauseStartedAt {
            total += max(0, Int(date.timeIntervalSince(pauseStartedAt)))
        }
        return total
    }

    /// Cronômetro de pausa: só a pausa atual se aberta; senão o total acumulado.
    private func pauseElapsedSeconds(at date: Date = Date()) -> Int {
        if let pauseStartedAt {
            return max(0, totalPausedSeconds) + max(0, Int(date.timeIntervalSince(pauseStartedAt)))
        }
        return max(0, totalPausedSeconds)
    }

    private func togglePause() {
        if isPaused {
            resumeCardio()
        } else {
            pauseCardio()
        }
    }

    private func pauseCardio() {
        guard !isPaused, !isFinishing else { return }
        isPaused = true
        pauseStartedAt = .now
        if isOutdoorGPS {
            runTracker.setPaused(true)
        }
    }

    private func resumeCardio() {
        guard isPaused else { return }
        if let pauseStartedAt {
            totalPausedSeconds += max(0, Int(Date().timeIntervalSince(pauseStartedAt)))
        }
        pauseStartedAt = nil
        isPaused = false
        if isOutdoorGPS {
            runTracker.setPaused(false)
        }
        elapsedSeconds = activeElapsedSeconds()
    }

    private func finalizedPausedSeconds() -> Int {
        if isPaused, let pauseStartedAt {
            return max(0, totalPausedSeconds) + max(0, Int(Date().timeIntervalSince(pauseStartedAt)))
        }
        return max(0, totalPausedSeconds)
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
        workoutStore.updateCalories(liveCalories)
    }

    private var shouldAutoEndByInactivity: Bool {
        guard let startedAt = workoutStore.activeSession?.startedAt, !isFinishing else { return false }
        return Date.now.timeIntervalSince(startedAt) >= WorkoutStore.autoEndInactivityLimit
    }

    private func finishCardio(autoEndedByInactivity: Bool = false) {
        guard !isFinishing else { return }
        isFinishing = true

        // Summary must be visible even if the user had minimized the workout.
        if workoutStore.isActiveWorkoutMinimized {
            workoutStore.resumeActiveWorkout()
        }

        runTracker.stop()
        watchConnectivity.stopWorkoutOnWatch()

        let finalPausedSeconds = finalizedPausedSeconds()
        // Congela cronômetros ativos antes de gravar.
        if isPaused {
            totalPausedSeconds = finalPausedSeconds
            pauseStartedAt = nil
            isPaused = false
        }
        elapsedSeconds = activeElapsedSeconds()

        guard var session = workoutStore.activeSession else {
            if finishedSession == nil,
               let last = workoutStore.sessionHistory.first,
               last.autoEndedByInactivity {
                finishedSession = last
            } else if finishedSession == nil {
                closeHostedWorkout()
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
            if config.isFreeRun || isOutdoorCycling {
                return elapsedSeconds >= 60
            }
            if config.isDistanceRun {
                return distanceKm >= config.targetDistanceKm * 0.98
            }
            return elapsedSeconds >= config.targetDurationSeconds / 2
        }()

        session.endedAt = .now
        session.caloriesBurned = liveCalories
        session.completedDistanceKm = (config.isDistanceRun || config.isFreeRun || isOutdoorGPS) ? distanceKm : nil
        session.averagePaceSecondsPerKm = (config.isDistanceRun || config.isFreeRun || (isOutdoorGPS && !isOutdoorCycling))
            ? pace
            : nil
        session.cardioIntensityLabel = config.intensity.rawValue
        session.targetCalories = config.targetCalories
        session.pausedDurationSeconds = finalPausedSeconds
        if isOutdoorGPS {
            session.routePoints = runTracker.routePoints
            // Passos na corrida e na caminhada (pedômetro / estimativa).
            if isRunningSession || isOutdoorWalking || trackingModality.usesFootTracking {
                session.stepCount = liveSteps
            }
        }
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

        let hkActivity: HKWorkoutActivityType = {
            if config.isOutdoorCyclingSession { return .cycling }
            if config.isRunningSession || config.isDistanceRun { return .running }
            if config.isOutdoorWalkingSession { return .walking }
            if config.exercise.isStationaryBike { return .cycling }
            return .walking
        }()

        Task {
            await healthKitManager.saveWorkout(
                duration: TimeInterval(session.activeDurationSeconds),
                calories: session.caloriesBurned,
                heartRate: session.averageHeartRate,
                activityType: hkActivity
            )
        }

        NotificationService.shared.deliverWorkoutEndNotification(
            session: session,
            athleteName: authService.currentUser?.greetingName ?? "Atleta"
        )

        finishedSession = session
        workoutStore.endSession(persisting: session)
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
