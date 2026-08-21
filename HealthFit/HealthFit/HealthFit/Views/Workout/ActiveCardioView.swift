import Charts
import Combine
import CoreLocation
import HealthKit
import SwiftUI
import UIKit

struct ActiveCardioView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var liveMetrics: LiveMetricsHub
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    let config: CardioWorkoutConfig
    var onReturnToWorkoutList: (() -> Void)? = nil
    /// When hosted as a persistent overlay (MainTabView), close the host instead of `dismiss()`.
    var onHostClose: (() -> Void)? = nil
    /// Incremented by conflict alert / banner to finish without re-presenting the UI.
    var openFinishTick: Int = 0

    @StateObject private var runTracker = RunTrackingService()
    @StateObject private var jumpMetrics = JumpMetricsService()
    @StateObject private var rowingMetrics = RowingMetricsService()
    @StateObject private var climbingMotion = ClimbingMotionService()
    @ObservedObject private var climbingWeather = ClimbingWeatherService.shared
    @State private var climbingAttempts: [ClimbingAttempt] = []
    @State private var showsAttemptSheet = false
    @State private var climbingHealth: HealthKitManager.ClimbingHealthSnapshot?
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
    @State private var swimLapCount = 0
    @State private var lastWatchJumpTick = 0
    @State private var lastWatchSwimLapTick = 0
    @State private var isSyncingWatch = false
    @State private var watchSyncStatus: String?
    @ObservedObject private var roadHazards = RoadHazardService.shared
    @State private var activeHazardAlert: RoadHazard?
    @State private var showReportHazardSheet = false
    @State private var alertedHazardIds = Set<UUID>()
    @State private var lastHazardCheckAt: Date = .distantPast
    @State private var clockTickCount = 0
    @State private var treadmillInclinePercent: Double = 0

    /// Side-effects; display uses wall clock from session start minus pauses.
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isRunningSession: Bool { config.isRunningSession }
    private var isOutdoorGPS: Bool { config.isOutdoorGPSCardio }
    private var isOutdoorCycling: Bool { config.isOutdoorCyclingSession }
    private var isOutdoorWalking: Bool { config.isOutdoorWalkingSession }
    private var isSwimming: Bool { config.isSwimmingSession }
    private var isWaterSport: Bool { config.isWaterSportSession }
    private var isRowing: Bool { config.isRowingSession }
    private var isClimbing: Bool { config.isClimbingSession }
    private var isFight: Bool { config.isFightSession }
    private var isTreadmill: Bool { config.isTreadmillSession }
    private var treadmillHasElevation: Bool { config.treadmillSetup?.hasElevation == true }
    private var climbingSetup: ClimbingSetup { config.climbingSetup ?? .default }
    private var trackingModality: OutdoorCardioModality {
        config.outdoorTrackingModality
    }

    private var swimDistanceMeters: Double {
        config.swimDistanceMeters(laps: swimLapCount)
    }

    private var completedDistanceKm: Double {
        if isSwimming {
            return swimDistanceMeters / 1000.0
        }
        if isOutdoorGPS, let gpsKm = runTracker.gpsDistanceKmIfAvailable {
            if config.hasDistanceTarget {
                return min(gpsKm, config.targetDistanceKm)
            }
            return gpsKm
        }
        if config.hasDistanceTarget {
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
        if isSwimming {
            let weight = authService.currentUser?.weight ?? 70
            return config.estimatedSwimCalories(
                elapsedSeconds: elapsedSeconds,
                distanceMeters: swimDistanceMeters,
                weightKg: weight
            )
        }
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
        var indoor = config.estimatedCalories(for: elapsedSeconds)
        if isTreadmill, treadmillHasElevation {
            // `estimatedCalories` já inclui a inclinação inicial; reescala para o valor ao vivo.
            let setupIncline = config.treadmillSetup?.resolvedInclinePercent ?? 0
            let setupFactor = 1.0 + setupIncline * 0.03
            let liveFactor = 1.0 + treadmillInclinePercent * 0.03
            indoor = indoor / max(setupFactor, 0.01) * liveFactor
        }
        return indoor
    }

    private var hasWatchMetrics: Bool {
        watchConnectivity.hasLiveWatchMetrics
            || watchConnectivity.watchCalories > 0
            || liveMetrics.heartRateBPM > 0
            || BluetoothHeartRateService.shared.isConnected
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
        // Luta é cronômetro puro: sem meta, o anel fica só como moldura do tempo.
        if isFight { return 0 }
        if config.hasCalorieGoal {
            return calorieProgressClamped
        }
        if isSwimming, let targetLaps = config.targetSwimLaps, targetLaps > 0 {
            return min(Double(swimLapCount) / Double(targetLaps), 1.0)
        }
        if config.isFreeRun {
            return 0
        }
        if config.hasDistanceTarget, config.targetDistanceKm > 0 {
            return min(completedDistanceKm / config.targetDistanceKm, 1.0)
        }
        guard config.targetDurationSeconds > 0 else { return 0 }
        return min(Double(elapsedSeconds) / Double(config.targetDurationSeconds), 1.0)
    }

    private var showsRunningUI: Bool {
        config.isRunningSession
    }

    private var navigationTitleText: String {
        if isFight { return config.exercise.name }
        if isSwimming { return "Natação" }
        if isWaterSport {
            return config.isKitesurfSession ? "Kitesurf" : "Surf"
        }
        if showsRunningUI { return "Corrida" }
        if isOutdoorCycling || isOutdoorWalking { return config.exercise.name }
        return "Cardio"
    }

    private var currentSwimPaceSecondsPer100m: Int? {
        config.swimPaceSecondsPer100m(elapsedSeconds: elapsedSeconds, distanceMeters: swimDistanceMeters)
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
        if config.hasDistanceTarget && !isOutdoorCycling {
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
                            if isWaterSport {
                                waterSportLiveSection
                            }
                            if isRowing {
                                rowingLiveSection
                            }
                            if isOutdoorCycling, let hazard = activeHazardAlert {
                                potholeAlertBanner(hazard)
                            }
                        }
                        intensityBadge
                        if !isOutdoorGPS {
                            exerciseInfo
                            if isTreadmill {
                                treadmillLiveSection
                            }
                            if isRowing {
                                rowingLiveSection
                            }
                            if isClimbing {
                                climbingWeatherSection
                                climbingLiveSection
                                climbingAttemptsSection
                            }
                        }
                        progressRing
                        if isSwimming {
                            swimmingLapControls
                            swimWatchSyncButton
                        }
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
                        if isRowing {
                            rowingExtraMetricsGrid
                            rowingSymmetrySection
                        }
                        if isWaterSport {
                            waterSportChartsSection
                            waterSportWatchSyncButton
                        }
                        if isOutdoorCycling {
                            reportHazardButton
                        }
                        if isSwimming {
                            swimExtraMetricsRow
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
            clockTickCount += 1
            if !isPaused {
                elapsedSeconds = activeElapsedSeconds()
                if isRowing {
                    syncRowingKinematics()
                }
            }

            let minimized = workoutStore.isActiveWorkoutMinimized
            let inBackground = scenePhase != .active
            // Minimizado ou em background: trabalho pesado bem menos frequente (GPS/sensores seguem ativos).
            let runHeavyWork = (!minimized && !inBackground)
                || (inBackground && clockTickCount % 15 == 0)
                || (!inBackground && minimized && clockTickCount % 5 == 0)

            if runHeavyWork {
                syncWithWatch()
                if !isPaused {
                    updateCalorieMotivation()
                    if isOutdoorCycling {
                        evaluateNearbyHazards()
                    }
                    if isWaterSport {
                        pollWatchWaterSportEvents()
                        watchConnectivity.syncWaterSportJumpSummary(
                            jumpCount: jumpMetrics.jumpCount,
                            maxHeightMeters: jumpMetrics.maxJumpHeightMeters,
                            liveAccelG: jumpMetrics.liveAccelerationG
                        )
                    }
                    if isRowing, watchConnectivity.lastWatchAccelG > 0 {
                        // Watch acel. como reforço de carga lateral (simetria).
                        let g = watchConnectivity.lastWatchAccelG
                        rowingMetrics.ingestWatchSideLoad(lateralG: (g - 1.0) * 0.4)
                    }
                    if isSwimming {
                        applyAutomaticSwimLapsFromWatch()
                    }
                }
                syncWatchData()
            }

            // Meta de calorias: nunca encerra sozinho (nem por inatividade) — só Finalizar/Encerrar.
            if !config.hasCalorieGoal, shouldAutoEndByInactivity {
                finishCardio(autoEndedByInactivity: true)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                elapsedSeconds = activeElapsedSeconds()
                if isOutdoorGPS {
                    runTracker.handleAppBecameActive()
                }
                UIApplication.shared.isIdleTimerDisabled = isOutdoorGPS && !isPaused && finishedSession == nil
            } else if phase == .background || phase == .inactive {
                // Mantém GPS em background; idle timer volta ao normal fora da tela ativa.
                if isOutdoorGPS {
                    runTracker.handleAppBecameActive()
                }
            }
        }
        .onReceive(workoutStore.sessionAutoEnded) { ended in
            guard finishedSession == nil, !isFinishing else { return }
            isFinishing = true
            if workoutStore.isActiveWorkoutMinimized {
                workoutStore.resumeActiveWorkout()
            }
            runTracker.stop()
            jumpMetrics.stop()
            rowingMetrics.stop()
            watchConnectivity.stopWorkoutOnWatch()
            finishedSession = ended
        }
        .onAppear {
            elapsedSeconds = activeElapsedSeconds()
            syncWithWatch()
            if isOutdoorGPS {
                UIApplication.shared.isIdleTimerDisabled = true
                runTracker.prepareForSession(modality: trackingModality)
                runTracker.start(modality: trackingModality)
                if isOutdoorCycling {
                    roadHazards.refreshSeedIfNeeded(near: runTracker.currentLocation?.coordinate)
                }
            }
            if isWaterSport {
                jumpMetrics.configure(locationProvider: { [weak runTracker] in
                    runTracker?.currentLocation
                })
                jumpMetrics.start()
                Task {
                    _ = await watchConnectivity.attemptSyncWithWatch()
                    watchConnectivity.requestWatchWaterSportSync()
                }
            }
            if isRowing {
                let boat = config.rowingSetup?.boatType ?? .singleSkiff
                rowingMetrics.start(boat: boat)
                Task {
                    _ = await watchConnectivity.attemptSyncWithWatch()
                }
            }
            if isClimbing {
                Task { await startClimbingSupport() }
            }
            if isTreadmill {
                treadmillInclinePercent = config.treadmillSetup?.resolvedInclinePercent ?? 0
            }
            if isSwimming {
                Task {
                    _ = await watchConnectivity.attemptSyncWithWatch()
                    watchConnectivity.requestWatchSwimSync()
                }
            }
            handleExternalFinishTickIfNeeded()
        }
        .onChange(of: watchConnectivity.watchSwimLapTick) { _, tick in
            guard isSwimming, tick > lastWatchSwimLapTick else { return }
            lastWatchSwimLapTick = tick
            applyAutomaticSwimLapsFromWatch()
        }
        .onChange(of: watchConnectivity.watchJumpTick) { _, tick in
            guard isWaterSport, tick > lastWatchJumpTick else { return }
            lastWatchJumpTick = tick
            if let event = watchConnectivity.lastWatchJumpEvent {
                jumpMetrics.ingestWatchJump(
                    heightMeters: event.height,
                    peakG: event.peakG,
                    airtime: event.airtime
                )
            }
        }
        .onChange(of: watchConnectivity.lastWatchAccelG) { _, g in
            guard isWaterSport, g > 0 else { return }
            jumpMetrics.ingestWatchAcceleration(g)
        }
        .sheet(isPresented: $showReportHazardSheet) {
            ReportRoadHazardSheet(
                coordinate: runTracker.currentLocation?.coordinate,
                onReport: { type, note in
                    if let coord = runTracker.currentLocation?.coordinate {
                        roadHazards.report(type: type, coordinate: coord, note: note)
                    }
                    showReportHazardSheet = false
                }
            )
            .presentationDetents([.medium])
        }
        .onDisappear {
            // Hosted minimize keeps this view mounted; only stop if the session is gone.
            guard finishedSession == nil else { return }
            if workoutStore.activeSession != nil { return }
            UIApplication.shared.isIdleTimerDisabled = false
            runTracker.stop()
            jumpMetrics.stop()
            rowingMetrics.stop()
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
                    userCoordinate: runTracker.currentLocation?.coordinate
                        ?? config.waterSportSetup?.spot.coordinate,
                    followUser: true,
                    showsUserLocation: true,
                    height: isWaterSport ? 300 : 260,
                    performanceMetric: config.routePerformanceMetric,
                    jumpEvents: isWaterSport ? jumpMetrics.jumps : [],
                    allows3DMode: true,
                    spotCoordinate: isWaterSport ? config.waterSportSetup?.spot.coordinate : nil,
                    spotTitle: isWaterSport ? config.waterSportSetup?.spot.name : nil,
                    prefers3DInitially: false
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                if runTracker.routePoints.count >= 2 {
                    performanceLegend
                } else if isWaterSport, let name = config.waterSportSetup?.spot.name, !name.isEmpty {
                    Text("SPOT: \(name) · aguardando pontos GPS da sessão")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                if isWaterSport, !jumpMetrics.jumps.isEmpty {
                    Text("\(jumpMetrics.jumps.count) salto(s) · curva subida/descida no mapa GPS")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private var waterSportLiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let setup = config.waterSportSetup {
                VStack(alignment: .leading, spacing: 6) {
                    Label(
                        config.isKitesurfSession ? "Kitesurf ao vivo" : "Surf ao vivo",
                        systemImage: config.isKitesurfSession
                            ? CardioExercise.kitesurfSystemImage
                            : CardioExercise.surfSystemImage
                    )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    if !setup.spot.name.isEmpty {
                        Text("SPOT: \(setup.spot.name)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.accent)
                    }
                    HStack(spacing: 12) {
                        Label(setup.conditions.windSummary, systemImage: "wind")
                        Label(setup.conditions.tideSummary, systemImage: "water.waves")
                    }
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    if let mode = setup.ridingMode {
                        Text("Modo: \(mode.rawValue)")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }

            HStack(spacing: 16) {
                waterMetricTile(
                    title: "Saltos",
                    value: "\(jumpMetrics.jumpCount)",
                    icon: "arrow.up.to.line"
                )
                waterMetricTile(
                    title: "Maior",
                    value: String(format: "%.1f m", jumpMetrics.maxJumpHeightMeters),
                    icon: "arrow.up.circle"
                )
                waterMetricTile(
                    title: "Acel.",
                    value: String(format: "%.1f g", jumpMetrics.liveAccelerationG),
                    icon: "waveform.path.ecg"
                )
            }

            if let status = jumpMetrics.lastStatusMessage {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            if let watchSyncStatus {
                Text(watchSyncStatus)
                    .font(.caption2)
                    .foregroundStyle(watchConnectivity.isWatchConnected ? AppTheme.accent : AppTheme.textSecondary)
            }

            Button {
                jumpMetrics.markJump(
                    source: .manual,
                    at: runTracker.currentLocation
                )
            } label: {
                Label("Marcar salto no iPhone", systemImage: "hand.tap.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accentSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Remo ao vivo

    private var rowingLiveSection: some View {
        let zone = rowingMetrics.spmZone
        let splitText: String = {
            if let s = rowingMetrics.splitSecondsPer500m {
                return RowingMetricsMath.formatSplit(seconds: s) + " /500 m"
            }
            return "— /500 m"
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Remo ao vivo", systemImage: "figure.rower")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if let boat = config.rowingSetup?.boatType {
                    Text(boat.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            HStack(spacing: 12) {
                waterMetricTile(
                    title: "SPM",
                    value: RowingMetricsMath.formatSPM(rowingMetrics.strokeRateSPM),
                    icon: "metronome.fill"
                )
                waterMetricTile(
                    title: "Split",
                    value: splitText.replacingOccurrences(of: " /500 m", with: ""),
                    icon: "timer"
                )
                waterMetricTile(
                    title: "Remadas",
                    value: "\(rowingMetrics.strokeCount)",
                    icon: "arrow.left.arrow.right"
                )
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(zone.color)
                    .frame(width: 8, height: 8)
                Text("\(zone.rawValue) · \(zone.rangeLabel) SPM")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(zone.color)
                Spacer()
                Text(zone.tip)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
            }

            if let status = rowingMetrics.lastStatusMessage {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var rowingExtraMetricsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Eficiência e barco")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                rowingStatTile(
                    title: "m / remada",
                    value: rowingMetrics.metersPerStroke > 0
                        ? String(format: "%.1f m", rowingMetrics.metersPerStroke)
                        : "—"
                )
                rowingStatTile(
                    title: "Eficiência",
                    value: String(format: "%.0f", rowingMetrics.efficiencyScore)
                )
                rowingStatTile(
                    title: "Velocidade",
                    value: String(format: "%.1f km/h", max(liveSpeedKmh, rowingMetrics.speedMps * 3.6))
                )
                rowingStatTile(
                    title: "Estabilidade",
                    value: String(format: "%.0f", rowingMetrics.stabilityScore)
                )
                rowingStatTile(
                    title: "Aceleração",
                    value: String(format: "%.2f m/s²", rowingMetrics.accelerationMps2)
                )
                rowingStatTile(
                    title: "Desaceleração",
                    value: String(format: "%.2f m/s²", rowingMetrics.decelerationMps2)
                )
                rowingStatTile(
                    title: "Equilíbrio",
                    value: String(format: "%.0f", rowingMetrics.balanceScore)
                )
                rowingStatTile(
                    title: "Melhor split",
                    value: {
                        if let s = rowingMetrics.bestSplitSecondsPer500m {
                            return RowingMetricsMath.formatSplit(seconds: s)
                        }
                        return "—"
                    }()
                )
            }
        }
    }

    private var rowingSymmetrySection: some View {
        let leftPct = Int((rowingMetrics.leftSideShare * 100).rounded())
        let rightPct = Int((rowingMetrics.rightSideShare * 100).rounded())
        let asym = rowingMetrics.asymmetryPercent
        let riskColor: Color = asym < 8 ? .green : (asym < 15 ? AppTheme.accentSecondary : .orange)

        return VStack(alignment: .leading, spacing: 10) {
            Label("Simetria · esquerda × direita", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            GeometryReader { geo in
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.cyan.opacity(0.85))
                        .frame(width: max(8, geo.size.width * rowingMetrics.leftSideShare))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.accent.opacity(0.9))
                        .frame(width: max(8, geo.size.width * rowingMetrics.rightSideShare))
                }
            }
            .frame(height: 14)

            HStack {
                Label("Esq. \(leftPct)%", systemImage: "l.circle.fill")
                    .foregroundStyle(.cyan)
                Spacer()
                Label("Dir. \(rightPct)%", systemImage: "r.circle.fill")
                    .foregroundStyle(AppTheme.accent)
            }
            .font(.caption.weight(.semibold))

            HStack {
                Text(String(format: "Assimetria %.0f%%", asym))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(riskColor)
                Spacer()
                Text(String(format: "Equilíbrio %.0f", rowingMetrics.balanceScore))
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Text(RowingSessionSnapshot(
                leftSideShare: rowingMetrics.leftSideShare,
                rightSideShare: rowingMetrics.rightSideShare,
                asymmetryPercent: asym
            ).symmetryInsight)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Acelerômetro + giroscópio (iPhone) e reforço do Apple Watch.")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func rowingStatTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func syncRowingKinematics() {
        guard isRowing else { return }
        let meters = completedDistanceKm * 1000.0
        let speed = max(runTracker.currentSpeedMetersPerSecond, 0)
        // Erg sem GPS: estima velocidade pelo ritmo se já houver remadas e tempo.
        let resolvedSpeed: Double = {
            if speed > 0.2 { return speed }
            if meters > 5, elapsedSeconds > 5 {
                return meters / Double(elapsedSeconds)
            }
            return 0
        }()
        rowingMetrics.updateKinematics(
            distanceMeters: meters,
            speedMetersPerSecond: resolvedSpeed,
            elapsedSeconds: Double(max(elapsedSeconds, 1))
        )
    }

    private func waterMetricTile(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.accent)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(AppTheme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var waterSportChartsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Aceleração e saltos", systemImage: "chart.xyaxis.line")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)

            if jumpMetrics.accelerationSamples.count >= 2 {
                Chart(jumpMetrics.accelerationSamples.suffix(80)) { sample in
                    LineMark(
                        x: .value("t", sample.timestamp),
                        y: .value("g", sample.accelerationG)
                    )
                    .foregroundStyle(AppTheme.accent)
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxisLabel("g")
                .frame(height: 140)
            } else {
                Text("Aguardando amostras de aceleração…")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !jumpMetrics.jumps.isEmpty {
                Chart(jumpMetrics.jumps) { jump in
                    BarMark(
                        x: .value("#", jump.timestamp),
                        y: .value("m", jump.heightMeters)
                    )
                    .foregroundStyle(Color.orange.gradient)
                }
                .chartYAxisLabel("m")
                .frame(height: 120)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var waterSportWatchSyncButton: some View {
        Button {
            Task {
                isSyncingWatch = true
                let result = await watchConnectivity.attemptSyncWithWatch()
                watchConnectivity.requestWatchWaterSportSync()
                isSyncingWatch = false
                switch result {
                case .synced:
                    watchSyncStatus = "Watch sincronizado"
                case .notPaired:
                    watchSyncStatus = "Watch não emparelhado"
                case .unreachable:
                    watchSyncStatus = "Watch fora de alcance — dados na fila"
                case .appNotInstalled:
                    watchSyncStatus = "App HealthFit não instalado no Watch"
                case .activationFailed, .notSupported:
                    watchSyncStatus = "Watch Connectivity indisponível"
                }
            }
        } label: {
            HStack {
                if isSyncingWatch {
                    ProgressView()
                } else {
                    Image(systemName: "applewatch.and.arrow.forward")
                }
                Text(watchConnectivity.isWatchConnected ? "Sincronizar Apple Watch" : "Tentar sincronizar Watch")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .disabled(isSyncingWatch)
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
            if isWaterSport {
                Image(systemName: config.isKitesurfSession
                      ? CardioExercise.kitesurfSystemImage
                      : CardioExercise.surfSystemImage)
                Text(config.isKitesurfSession ? "Kitesurf" : "Surf")
                    .font(.subheadline.weight(.semibold))
                if let mode = config.waterSportSetup?.ridingMode {
                    Text("·")
                    Text(mode.rawValue)
                        .font(.subheadline.weight(.semibold))
                } else if let board = config.waterSportSetup?.boardType {
                    Text("·")
                    Text(board.rawValue)
                        .font(.subheadline.weight(.semibold))
                }
            } else if let modality = config.fightModality {
                Image(systemName: modality.icon)
                Text(modality.name)
                    .font(.subheadline.weight(.semibold))
            } else {
                Image(systemName: config.intensity.icon)
                Text("Intensidade \(config.intensity.rawValue)")
                    .font(.subheadline.weight(.semibold))
                if config.isFreeRun {
                    Text("·")
                    Text("Livre")
                        .font(.subheadline.weight(.semibold))
                } else if config.hasDistanceTarget {
                    Text("·")
                    Text(String(format: abs(config.targetDistanceKm - config.targetDistanceKm.rounded()) < 0.05
                                   ? "%.0f km"
                                   : "%.1f km",
                                 config.targetDistanceKm))
                        .font(.subheadline.weight(.semibold))
                } else if isSwimming {
                    Text("·")
                    Text("\(Int(config.resolvedPoolLengthMeters)) m")
                        .font(.subheadline.weight(.semibold))
                }
            }
            if config.hasCalorieGoal, let target = config.targetCalories {
                Text("·")
                Text("\(target) kcal")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .foregroundStyle(isWaterSport ? AppTheme.accent : config.intensity.color)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background((isWaterSport ? AppTheme.accent : config.intensity.color).opacity(0.15))
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
            if isWaterSport {
                let sportName = config.isKitesurfSession ? "Kitesurf" : "Surf"
                Text("\(sportName) — GPS, condições e encerre quando quiser")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            } else if config.isFreeRun {
                Text(isOutdoorCycling
                      ? "Pedal livre — encerre quando quiser"
                      : isOutdoorWalking
                      ? "Caminhada livre — encerre quando quiser · Ritmo ref. \(config.intensity.formattedPace())"
                      : "Corrida livre — encerre quando quiser · Ritmo ref. \(config.intensity.formattedPace())")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            } else if config.hasDistanceTarget {
                let kmLabel = String(format: abs(config.targetDistanceKm - config.targetDistanceKm.rounded()) < 0.05
                                       ? "%.0f"
                                       : "%.1f",
                                     config.targetDistanceKm)
                if isOutdoorCycling {
                    Text("Meta: \(kmLabel) km · GPS outdoor")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Meta: \(kmLabel) km · Ritmo \(config.intensity.formattedPace())")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            } else if isSwimming {
                let pool = Int(config.resolvedPoolLengthMeters)
                if let target = config.targetSwimLaps, target > 0 {
                    Text("Piscina \(pool) m · Meta \(target) voltas · \(config.intensity.formattedSwimPace())")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Piscina \(pool) m · Conte as voltas · \(config.intensity.formattedSwimPace())")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            } else if let modality = config.fightModality {
                Text("\(modality.roundReference) · encerre quando a luta acabar")
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
                } else if config.isFreeRun || config.hasDistanceTarget || isOutdoorCycling || isOutdoorWalking {
                    Text(String(format: "%.2f km", completedDistanceKm))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    if config.hasDistanceTarget {
                        Text("Meta: \(String(format: abs(config.targetDistanceKm - config.targetDistanceKm.rounded()) < 0.05 ? "%.0f" : "%.1f", config.targetDistanceKm)) km")
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
                } else if isSwimming {
                    Text("\(swimLapCount)")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                    if let target = config.targetSwimLaps, target > 0 {
                        Text("de \(target) voltas")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        Text("voltas")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Text(swimDistanceMeters >= 1000
                          ? String(format: "%.2f km", completedDistanceKm)
                          : "\(Int(swimDistanceMeters.rounded())) m")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                    Text(DurationFormatting.formatElapsedClock(seconds: elapsedSeconds))
                        .font(.caption.weight(.semibold).monospaced())
                        .foregroundStyle(isPaused ? AppTheme.textSecondary : AppTheme.accentSecondary)
                    if isPaused || totalPausedSeconds > 0 {
                        pauseChronometer
                    }
                } else {
                    Text(DurationFormatting.formatElapsedClock(seconds: elapsedSeconds))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(isPaused ? AppTheme.textSecondary : AppTheme.textPrimary)
                    Text(isFight
                          ? (isPaused ? "Luta pausada" : "Tempo de luta")
                          : "Meta: \(DurationFormatting.format(seconds: config.targetDurationSeconds))")
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
                } else if isSwimming {
                    Label("Estimativa natação", systemImage: "figure.pool.swim")
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
                        : isSwimming
                            ? "Estimativa por tempo, distância em volta e intensidade."
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
                value: "\(Int(liveHeartRateBPM))",
                label: "BPM",
                color: .red
            )
            CardioMetricTile(
                icon: "flame.fill",
                value: "\(Int(liveCalories))",
                label: "kcal",
                color: hasExceededCalorieGoal ? .orange : AppTheme.accentSecondary
            )
            if isOutdoorCycling {
                CardioMetricTile(
                    icon: "speedometer",
                    value: String(format: "%.1f", liveSpeedKmh),
                    label: "km/h",
                    color: config.intensity.color
                )
            } else if config.hasDistanceTarget || (isOutdoorGPS && !isOutdoorCycling) {
                CardioMetricTile(
                    icon: "speedometer",
                    value: PaceFormatting.format(secondsPerKm: currentPaceSecondsPerKm).replacingOccurrences(of: " /km", with: ""),
                    label: "Ritmo",
                    color: config.intensity.color
                )
            } else if isSwimming {
                CardioMetricTile(
                    icon: "speedometer",
                    value: {
                        if let pace = currentSwimPaceSecondsPer100m {
                            return PaceFormatting.formatSwimPace(secondsPer100m: pace)
                                .replacingOccurrences(of: " /100m", with: "")
                        }
                        return "—"
                    }(),
                    label: "/100m",
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

    private var swimmingLapControls: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Contagem de voltas")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if watchConnectivity.watchSwimLapCount > 0 || watchConnectivity.isWatchConnected {
                    Label(
                        watchConnectivity.watchSwimLapCount > 0 ? "Automático · Watch" : "Aguardando Watch",
                        systemImage: "applewatch"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(swimAutoCountCaption)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button {
                    swimLapCount = max(0, swimLapCount - 1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(swimLapCount > 0 ? AppTheme.accentSecondary : AppTheme.textSecondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(isPaused || swimLapCount <= 0)

                VStack(spacing: 4) {
                    Text("\(swimLapCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                        .contentTransition(.numericText())
                    Text("voltas · \(Int(config.resolvedPoolLengthMeters)) m")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Button {
                    swimLapCount += 1
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(isPaused ? AppTheme.textSecondary.opacity(0.4) : AppTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(isPaused)
            }

            HStack(spacing: 8) {
                ForEach([1, 2, 5], id: \.self) { delta in
                    Button {
                            swimLapCount += delta
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("+\(delta)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .disabled(isPaused)
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var swimAutoCountCaption: String {
        if watchConnectivity.watchSwimLapCount > 0 {
            return "Voltas do Apple Watch: \(watchConnectivity.watchSwimLapCount). Você ainda pode ajustar manualmente."
        }
        if watchConnectivity.isWatchConnected {
            return "Watch emparelhado — as voltas serão atualizadas automaticamente a partir da natação no relógio."
        }
        return "Sem Watch emparelhado — conte as voltas com os botões abaixo."
    }

    private var swimWatchSyncButton: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    isSyncingWatch = true
                    let result = await watchConnectivity.attemptSyncWithWatch()
                    watchConnectivity.requestWatchSwimSync()
                    applyAutomaticSwimLapsFromWatch()
                    isSyncingWatch = false
                    switch result {
                    case .synced:
                        watchSyncStatus = "Watch sincronizado · voltas automáticas"
                    case .notPaired:
                        watchSyncStatus = "Watch não emparelhado — contagem manual"
                    case .unreachable:
                        watchSyncStatus = "Watch fora de alcance — dados na fila"
                    case .appNotInstalled:
                        watchSyncStatus = "Instale o HealthFit no Apple Watch"
                    case .activationFailed, .notSupported:
                        watchSyncStatus = "Watch Connectivity indisponível"
                    }
                }
            } label: {
                HStack {
                    if isSyncingWatch {
                        ProgressView()
                    } else {
                        Image(systemName: "applewatch.and.arrow.forward")
                    }
                    Text(watchConnectivity.isWatchConnected ? "Sincronizar voltas do Watch" : "Tentar sincronizar Watch")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .disabled(isSyncingWatch)

            if let watchSyncStatus {
                Text(watchSyncStatus)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Aceita o máximo entre contagem local e do Watch, sem reduzir voltas já contadas manualmente.
    /// Aceita o maior valor entre contagem local e do Watch (nunca reduz voltas já registradas).
    private func applyAutomaticSwimLapsFromWatch() {
        let watchLaps = max(0, watchConnectivity.watchSwimLapCount)
        guard watchLaps > swimLapCount else { return }
        swimLapCount = watchLaps
    }

    private var swimExtraMetricsRow: some View {
        HStack(spacing: 12) {
            CardioMetricTile(
                icon: "arrow.triangle.2.circlepath",
                value: "\(swimLapCount)",
                label: "Voltas",
                color: AppTheme.accent
            )
            CardioMetricTile(
                icon: "ruler",
                value: swimDistanceMeters >= 1000
                    ? String(format: "%.2f", completedDistanceKm)
                    : "\(Int(swimDistanceMeters.rounded()))",
                label: swimDistanceMeters >= 1000 ? "km" : "m",
                color: config.intensity.color
            )
            CardioMetricTile(
                icon: "flame.fill",
                value: "\(Int(liveCalories.rounded()))",
                label: "kcal est.",
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
                    if isSwimming { return "Finalizar Natação" }
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
            UIApplication.shared.isIdleTimerDisabled = false
        }
        if isWaterSport {
            jumpMetrics.setPaused(true)
        }
        if isRowing {
            rowingMetrics.setPaused(true)
        }
        if isClimbing {
            climbingMotion.setPaused(true)
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
            UIApplication.shared.isIdleTimerDisabled = true
        }
        if isWaterSport {
            jumpMetrics.setPaused(false)
        }
        if isRowing {
            rowingMetrics.setPaused(false)
        }
        if isClimbing {
            climbingMotion.setPaused(false)
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

        // Atingir a meta só celebra — o treino continua até o usuário tocar em Finalizar.
        if hasExceededCalorieGoal {
            if !didCelebrateCalorieGoal {
                didCelebrateCalorieGoal = true
                let celebration = MotivationMessages.cardioCalorieExceededMessage(
                    currentCalories: Int(liveCalories),
                    targetCalories: target
                )
                superationMessage = "\(celebration) Continue ou toque em Finalizar quando quiser encerrar."
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

    /// Prioridade: Apple Watch → Bluetooth → HealthKit (via LiveMetricsHub).
    private var liveHeartRateBPM: Double {
        liveMetrics.heartRateBPM
    }

    private func syncWatchData() {
        if liveHeartRateBPM > 0 {
            workoutStore.addHeartRateSample(liveHeartRateBPM)
        }
        workoutStore.updateCalories(liveCalories)
    }

    private func pollWatchWaterSportEvents() {
        guard isWaterSport else { return }
        let tick = watchConnectivity.watchJumpTick
        if tick > lastWatchJumpTick {
            lastWatchJumpTick = tick
            if let event = watchConnectivity.lastWatchJumpEvent {
                jumpMetrics.ingestWatchJump(
                    heightMeters: event.height,
                    peakG: event.peakG,
                    airtime: event.airtime
                )
            }
        }
        if watchConnectivity.lastWatchAccelG > 0 {
            jumpMetrics.ingestWatchAcceleration(watchConnectivity.lastWatchAccelG)
        }
    }

    private var shouldAutoEndByInactivity: Bool {
        guard let startedAt = workoutStore.activeSession?.startedAt, !isFinishing else { return false }
        return Date.now.timeIntervalSince(startedAt) >= WorkoutStore.autoEndInactivityLimit
    }

    // MARK: - Escalada

    @ViewBuilder
    private var climbingWeatherSection: some View {
        if climbingSetup.discipline.isOutdoor {
            VStack(alignment: .leading, spacing: 10) {
                if let snapshot = climbingWeather.snapshot {
                    HStack {
                        Label(snapshot.alertLevel.label, systemImage: snapshot.alertLevel.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(snapshot.alertLevel.color)
                        Spacer()
                        Text(snapshot.updatedAtText)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Text(snapshot.summaryLine)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    ForEach(snapshot.alerts, id: \.self) { alert in
                        Label(alert, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(snapshot.alertLevel.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let friction = snapshot.frictionNote {
                        Label(friction, systemImage: "hand.raised.fingers.spread")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if climbingWeather.isLoading {
                    Label("Buscando condições do tempo…", systemImage: "cloud")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Label(
                        climbingWeather.errorMessage ?? "Sem dados de clima para este setor.",
                        systemImage: "cloud.slash"
                    )
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                (climbingWeather.snapshot?.alertLevel.color ?? AppTheme.textSecondary).opacity(0.12),
                in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
            )
        }
    }

    private var treadmillLiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Esteira indoor", systemImage: "house.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Text("Sem mapa GPS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }

            if treadmillHasElevation {
                HStack {
                    Label("Elevação", systemImage: "arrow.up.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(String(format: "%.0f%%", treadmillInclinePercent))
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(AppTheme.accent)
                }

                Slider(value: $treadmillInclinePercent, in: 0...15, step: 0.5)
                    .tint(AppTheme.accent)
                    .disabled(isPaused || isFinishing)

                Text("Ajuste a inclinação conforme a esteira. O gasto calórico estimado acompanha a elevação.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Text("Esteira sem elevação — ritmo plano. Distância estimada pelo tempo e intensidade (sem GPS).")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var climbingLiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(climbingMotion.phase.label, systemImage: climbingMotion.phase.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(climbingMotion.phase == .climbing ? AppTheme.accent : AppTheme.textSecondary)
                Spacer()
                if climbingSetup.usesMotionDetection {
                    ProgressView(value: climbingMotion.motionIntensity)
                        .frame(width: 70)
                        .tint(AppTheme.accent)
                }
            }

            HStack(spacing: 0) {
                climbingMetric(
                    value: formattedDuration(climbingMotion.activeClimbingSeconds),
                    label: "em parede"
                )
                climbingMetric(
                    value: formattedDuration(climbingMotion.restSeconds),
                    label: "descanso"
                )
                climbingMetric(
                    value: "\(max(climbingMotion.detectedAttempts, climbingAttempts.count))",
                    label: "tentativas"
                )
                climbingMetric(
                    value: climbingAttempts.isEmpty
                        ? "—"
                        : "\(climbingAttempts.filter(\.isSuccess).count)",
                    label: "encadenadas"
                )
            }

            if !climbingSetup.usesMotionDetection {
                Text("Detecção por sensores desligada nesta sessão — registre as vias manualmente.")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var climbingAttemptsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Vias da sessão")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    showsAttemptSheet = true
                } label: {
                    Label("Registrar", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }

            if climbingAttempts.isEmpty {
                Text("Nenhuma via registrada ainda. Toque em Registrar ao terminar cada tentativa.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(climbingAttempts) { attempt in
                    HStack(spacing: 8) {
                        Image(systemName: attempt.style.icon)
                            .foregroundStyle(attempt.style.color)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(attempt.displayName)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("\(attempt.grade.displayLabel) · \(attempt.style.rawValue)")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Button {
                            climbingAttempts.removeAll { $0.id == attempt.id }
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .sheet(isPresented: $showsAttemptSheet) {
            ClimbingAttemptEditorView(setup: climbingSetup) { attempt in
                climbingAttempts.append(attempt)
            }
        }
    }

    private func climbingMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remaining = seconds % 60
        return String(format: "%d:%02d", minutes, remaining)
    }

    /// Sobe os sensores e busca clima e recuperação, fora do caminho crítico de abertura da tela.
    private func startClimbingSupport() async {
        if climbingSetup.usesMotionDetection {
            climbingMotion.start()
        }

        // Sono e HRV lidos no início descrevem a recuperação *antes* da escalada.
        climbingHealth = await healthKitManager.climbingHealthSnapshot(
            from: Date().addingTimeInterval(-3600)
        )

        guard climbingSetup.discipline.isOutdoor else { return }

        let coordinate = climbingSetup.coordinate ?? runTracker.currentLocation?.coordinate
        guard let coordinate else { return }
        await climbingWeather.refresh(
            coordinate: coordinate,
            locationLabel: climbingSetup.areaName.isEmpty ? "Setor" : climbingSetup.areaName
        )
    }

    /// Snapshot final: sensores, vias registradas, clima e contexto de saúde.
    private func buildClimbingSnapshot(session: WorkoutSession) -> ClimbingSessionSnapshot {
        let motion = climbingMotion.exportSnapshotValues()
        let weather = climbingWeather.snapshot

        var snapshot = session.climbing ?? climbingSetup.snapshot()
        snapshot.attempts = climbingAttempts
        snapshot.activeClimbingSeconds = motion.active
        snapshot.detectedRestSeconds = motion.rest
        snapshot.autoDetectedAttemptCount = motion.attempts
        snapshot.heartRateAverage = session.averageHeartRate > 0 ? session.averageHeartRate : nil
        snapshot.caloriesBurned = session.caloriesBurned > 0 ? session.caloriesBurned : nil
        snapshot.sleepHoursBefore = climbingHealth?.sleepHours
        snapshot.hrvMsBefore = climbingHealth?.hrvMs
        snapshot.temperatureCelsius = weather?.temperatureCelsius
        snapshot.humidityPercent = weather?.humidityPercent
        return snapshot
    }

    private func finishCardio(autoEndedByInactivity: Bool = false) {
        guard !isFinishing else { return }
        isFinishing = true
        UIApplication.shared.isIdleTimerDisabled = false

        // Summary must be visible even if the user had minimized the workout.
        if workoutStore.isActiveWorkoutMinimized {
            workoutStore.resumeActiveWorkout()
        }

        runTracker.stop()
        jumpMetrics.stop()
        rowingMetrics.stop()
        climbingMotion.stop()
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
        let swimPace = config.swimPaceSecondsPer100m(elapsedSeconds: elapsedSeconds, distanceMeters: swimDistanceMeters)
        let goalReached: Bool = {
            if autoEndedByInactivity { return false }
            if config.hasCalorieGoal, let target = config.targetCalories {
                return liveCalories >= Double(target) * 0.98
            }
            if isSwimming {
                if let target = config.targetSwimLaps, target > 0 {
                    return swimLapCount >= Int(Double(target) * 0.98)
                }
                return swimLapCount >= 1 || elapsedSeconds >= 60
            }
            if config.isFreeRun {
                return elapsedSeconds >= 60
            }
            if config.hasDistanceTarget {
                return distanceKm >= config.targetDistanceKm * 0.98
            }
            return elapsedSeconds >= config.targetDurationSeconds / 2
        }()

        session.endedAt = .now
        session.caloriesBurned = liveCalories
        session.completedDistanceKm = (config.hasDistanceTarget || config.isFreeRun || isOutdoorGPS || isSwimming || isTreadmill)
            ? distanceKm
            : nil
        session.averagePaceSecondsPerKm = {
            if isOutdoorCycling { return nil }
            if config.hasDistanceTarget || config.isFreeRun || isOutdoorGPS || isTreadmill { return pace }
            return nil
        }()
        if config.hasDistanceTarget {
            session.targetDistanceKm = config.targetDistanceKm
        }
        if isSwimming {
            session.poolLengthMeters = config.resolvedPoolLengthMeters
            session.swimLapCount = swimLapCount
            session.targetSwimLaps = config.targetSwimLaps
            session.swimPaceSecondsPer100m = swimPace
            if let swimPace {
                // Compatibilidade com gráficos que usam ritmo "por km" (~10 × /100m).
                session.averagePaceSecondsPerKm = swimPace * 10
            }
            if let targetLaps = config.targetSwimLaps, targetLaps > 0 {
                session.targetDistanceKm = config.targetDistanceKm
            }
        }
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
        if isWaterSport {
            let exported = jumpMetrics.exportSnapshot()
            var water = session.waterSport
                ?? config.waterSportSetup?.snapshot(isKitesurf: config.isKitesurfSession)
                ?? WaterSportSessionSnapshot(isKitesurf: config.isKitesurfSession)
            water.jumps = exported.jumps
            water.accelerationSamples = exported.samples
            if water.spot == nil, let setupSpot = config.waterSportSetup?.spot {
                water.spot = setupSpot
            }
            session.waterSport = water
        }
        if isRowing {
            syncRowingKinematics()
            session.rowing = rowingMetrics.exportSnapshot()
        }
        if isClimbing {
            session.climbing = buildClimbingSnapshot(session: session)
            ClimbingGearService.shared.registerSessionUse(discipline: climbingSetup.discipline)
        }
        if isTreadmill {
            session.treadmill = config.treadmillSetup?.snapshot(finalInclinePercent: treadmillInclinePercent)
                ?? TreadmillSessionSnapshot(
                    hasElevation: treadmillHasElevation,
                    inclinePercent: treadmillHasElevation ? treadmillInclinePercent : 0
                )
        }
        session.exerciseRecords = [
            ExerciseSessionRecord(
                exerciseId: config.exercise.id,
                exerciseName: {
                    if isWaterSport {
                        return config.isKitesurfSession ? "Kitesurf" : "Surf"
                    }
                    if isRowing {
                        let boat = config.rowingSetup?.boatType.rawValue ?? "Remo"
                        return "Remo · \(boat) (\(config.intensity.rawValue))"
                    }
                    if config.isFreeRun {
                        return "\(config.exercise.name) livre (\(config.intensity.rawValue))"
                    }
                    if config.hasDistanceTarget {
                        let km = String(format: abs(config.targetDistanceKm - config.targetDistanceKm.rounded()) < 0.05
                                          ? "%.0f"
                                          : "%.1f",
                                        config.targetDistanceKm)
                        return "\(config.exercise.name) \(km) km (\(config.intensity.rawValue))"
                    }
                    if isSwimming {
                        let pool = Int(config.resolvedPoolLengthMeters)
                        return "Natação \(pool) m · \(swimLapCount) voltas (\(config.intensity.rawValue))"
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
            if config.isSwimmingSession { return .swimming }
            if config.isOutdoorCyclingSession { return .cycling }
            if config.isRunningSession || config.isDistanceRun { return .running }
            if config.isOutdoorWalkingSession { return .walking }
            if config.isRowingSession { return .rowing }
            if config.isKitesurfSession || config.isSurfSession {
                // HealthKit não tem modalidade kite dedicada; use paddle sports / other.
                if #available(iOS 14.0, *) {
                    return .paddleSports
                }
                return .other
            }
            if config.exercise.isStationaryBike { return .cycling }
            if config.isTreadmillSession { return .running }
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

        if isOutdoorCycling, distanceKm > 0.05 {
            BikeMaintenanceService.shared.recordRide(
                distanceKm: distanceKm,
                title: session.workoutTitle,
                intensity: config.intensity.rawValue
            )
        }

        finishedSession = session
        workoutStore.endSession(persisting: session)
    }

    private func evaluateNearbyHazards() {
        let now = Date()
        guard now.timeIntervalSince(lastHazardCheckAt) >= 2 else { return }
        lastHazardCheckAt = now
        guard let coordinate = runTracker.currentLocation?.coordinate else { return }
        roadHazards.refreshSeedIfNeeded(near: coordinate)
        if let nearby = roadHazards.nearestHazard(
            to: coordinate,
            withinMeters: RoadHazardService.alertRadiusMeters,
            excluding: alertedHazardIds
        ) {
            alertedHazardIds.insert(nearby.id)
            activeHazardAlert = nearby
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
                if activeHazardAlert?.id == nearby.id {
                    activeHazardAlert = nil
                }
            }
        }
    }

    private func potholeAlertBanner(_ hazard: RoadHazard) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(hazard.type.alertTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(hazard.alertSubtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer(minLength: 0)
            Button {
                activeHazardAlert = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.orange.opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.55), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var reportHazardButton: some View {
        Button {
            showReportHazardSheet = true
        } label: {
            Label("Reportar perigo na pista", systemImage: "exclamationmark.bubble.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)
                .background(Color.orange.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(runTracker.currentLocation == nil)
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
