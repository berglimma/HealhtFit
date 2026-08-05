import HealthKit
import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var timerService: RestTimerService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let sheet: WorkoutSheet
    var onReturnToWorkoutList: (() -> Void)? = nil
    /// When hosted as a persistent overlay (MainTabView), close the host instead of `dismiss()`.
    var onHostClose: (() -> Void)? = nil
    /// Incremented by the minimized banner to open Encerrar without re-presenting the UI.
    var openEarlyEndTick: Int = 0
    @State private var finishedSession: WorkoutSession?
    @State private var workoutElapsedSeconds = 0
    @State private var isFinishing = false
    @State private var isShowingExerciseDemo = true
    @State private var demoExerciseId: UUID?
    @State private var showWorkoutStartMotivation = true
    @State private var performedWeightTextByExercise: [UUID: String] = [:]
    @State private var showEarlyEndSheet = false
    @State private var earlyEndJustification = ""
    /// Set when confirming early end; finish runs in sheet `onDismiss` so the summary
    /// fullScreenCover is not blocked by the justification sheet still dismissing.
    @State private var pendingEarlyEndJustification: String?
    @State private var liveExerciseElapsedSeconds = 0
    @State private var showVision = false
    /// Side-effects only (watch sync / auto-end). Display clocks use TimelineView + wall clock.
    private let workoutClock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let watchSyncClock = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    private var trimmedEarlyEndJustification: String {
        earlyEndJustification.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func setsDone(for exerciseId: UUID) -> Int {
        workoutStore.completedSets(for: exerciseId)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                Group {
                    if DeviceLayout.isPad && horizontalSizeClass == .regular {
                        HStack(alignment: .top, spacing: 0) {
                            VStack(spacing: 0) {
                                progressHeader

                                ScrollView {
                                    currentExerciseCard
                                        .padding(.bottom, 8)
                                }
                                .scrollIndicators(.visible)

                                bottomBar
                            }
                            .frame(maxWidth: 420)

                            ScrollView {
                                exerciseListContent
                                    .padding(.vertical, 8)
                            }
                            .scrollIndicators(.visible)
                            .frame(maxWidth: .infinity)
                        }
                        .adaptiveContentWidth(960)
                    } else {
                        VStack(spacing: 0) {
                            progressHeader

                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    currentExerciseCard
                                    exerciseListContent
                                }
                                .padding(.vertical, 8)
                            }
                            .scrollIndicators(.visible)
                        }
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            bottomBar
                        }
                    }
                }

                if timerService.isRunning {
                    RestTimerOverlay()
                        .allowsHitTesting(true)
                }

                if showWorkoutStartMotivation && !workoutStore.hasShownStartMotivation {
                    WorkoutStartMotivationOverlay {
                        workoutStore.markStartMotivationShown()
                        showWorkoutStartMotivation = false
                    }
                }
            }
            .navigationTitle(sheet.title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .numericKeyboardDismiss()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Minimizar") {
                        // Only flip the flag — MainTabView keeps this view mounted and hides it.
                        // Dismiss/re-present via fullScreenCover is inherently flaky for resume.
                        workoutStore.minimizeActiveWorkout()
                    }
                    .disabled(isFinishing)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Encerrar") {
                        requestEarlyEnd()
                    }
                    .foregroundStyle(.red)
                    .disabled(isFinishing)
                }
            }
            .sheet(isPresented: $showEarlyEndSheet, onDismiss: {
                if let reason = pendingEarlyEndJustification {
                    pendingEarlyEndJustification = nil
                    finishWorkout(endedEarly: true, justification: reason)
                }
            }) {
                EarlyEndJustificationSheet(
                    justification: $earlyEndJustification,
                    onCancel: {
                        pendingEarlyEndJustification = nil
                        showEarlyEndSheet = false
                        earlyEndJustification = ""
                    },
                    onConfirm: {
                        pendingEarlyEndJustification = trimmedEarlyEndJustification
                        showEarlyEndSheet = false
                    }
                )
                .presentationDetents([.medium])
            }
            .fullScreenCover(isPresented: $showVision) {
                VisionWorkoutView()
            }
        }
        .onAppear {
            if !workoutStore.hasBoundActiveWorkoutUI {
                if !timerService.isRunning && !timerService.isAwaitingResumeAcknowledgment {
                    timerService.resetSessionTracking()
                }
                workoutStore.markActiveWorkoutUIBound()
            }
            timerService.onRestOvertime = { exerciseName in
                watchConnectivity.sendRestOvertimeAlert(exerciseName: exerciseName)
            }
            prepareDemoForCurrentExercise(force: true)
            syncWatchWorkoutState()
            updateWorkoutElapsed()
            syncLiveExerciseElapsed()
            if workoutStore.hasShownStartMotivation {
                showWorkoutStartMotivation = false
            }
            if timerService.isRunning || timerService.isAwaitingResumeAcknowledgment {
                workoutStore.setExerciseTimerPaused(true)
            }
            syncLockScreenLiveActivity()
        }
        .onChange(of: workoutStore.currentExerciseIndex) { _, _ in
            prepareDemoForCurrentExercise(force: true)
            syncLiveExerciseElapsed()
            syncLockScreenLiveActivity()
        }
        .onChange(of: workoutStore.currentExercise?.id) { _, _ in
            prepareDemoForCurrentExercise(force: true)
        }
        .onChange(of: timerService.isRunning) { _, isResting in
            workoutStore.setExerciseTimerPaused(isResting)
            if isResting {
                // watch notified in startRest
            } else {
                watchConnectivity.sendRestTimerStop()
            }
            syncLockScreenLiveActivity()
        }
        .onChange(of: timerService.isAwaitingResumeAcknowledgment) { _, _ in
            syncLockScreenLiveActivity()
        }
        .onChange(of: timerService.configuredRestSeconds) { _, _ in
            if timerService.isRunning || timerService.isAwaitingResumeAcknowledgment {
                syncLockScreenLiveActivity()
            }
        }
        .onReceive(workoutClock) { _ in
            // Mantém estado leve alinhado ao relógio (TimelineView já redesenha o HH:MM:SS).
            updateWorkoutElapsed()
            liveExerciseElapsedSeconds = workoutStore.liveExerciseElapsedSeconds()
            if let ended = workoutStore.autoEndStaleActiveSessionIfNeeded(
                athleteName: authService.currentUser?.greetingName ?? "Atleta"
            ) {
                presentAutoEndedSession(ended)
            }
        }
        .onReceive(workoutStore.sessionAutoEnded) { ended in
            presentAutoEndedSession(ended)
        }
        .onReceive(workoutStore.exerciseElapsedTick) { seconds in
            liveExerciseElapsedSeconds = seconds
        }
        .onReceive(watchSyncClock) { _ in
            syncWatchData()
        }
        .onChange(of: workoutStore.allExercisesCompleted) { _, allDone in
            if allDone && !isFinishing {
                finishWorkout()
            }
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
        .onChange(of: openEarlyEndTick) { _, tick in
            guard tick > 0, !isFinishing else { return }
            requestEarlyEnd()
        }
    }

    private func closeHostedWorkout() {
        if let onHostClose {
            onHostClose()
        } else {
            dismiss()
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            ProgressView(
                value: Double(workoutStore.exerciseRecords.filter(\.isCompleted).count),
                total: Double(sheet.exercises.count)
            )
            .tint(AppTheme.accent)

            HStack {
                Label("\(Int(watchConnectivity.watchHeartRate)) BPM", systemImage: "heart.fill")
                    .foregroundStyle(.red)
                Spacer()
                Label("\(Int(watchConnectivity.watchCalories)) kcal", systemImage: "flame.fill")
                    .foregroundStyle(AppTheme.accentSecondary)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let seconds = workoutStore.liveWorkoutElapsedSeconds(at: context.date)
                    Label(DurationFormatting.format(seconds: seconds), systemImage: "clock.fill")
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal)
        }
        .padding()
        .background(AppTheme.cardBackground)
    }

    private var currentExerciseCard: some View {
        Group {
            if let exercise = workoutStore.currentExercise,
               let record = workoutStore.exerciseRecords.first(where: { $0.exerciseId == exercise.id }) {
                if isShowingExerciseDemo && demoExerciseId == exercise.id {
                    exerciseDemoCard(for: exercise)
                } else {
                    exerciseExecutionCard(for: exercise, record: record)
                }
            }
        }
    }

    private func exerciseDemoCard(for exercise: Exercise) -> some View {
        VStack(spacing: 16) {
            Text("Assista a demonstração")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Text(exercise.name)
                .font(.title.bold())
                .foregroundStyle(AppTheme.textPrimary)

            if !exercise.notes.isEmpty {
                Text(exercise.notes)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            ExerciseDemoGifView(
                exercise: exercise,
                preferredGender: sheet.resolvedProgramGender,
                compact: false,
                autoAdvanceAfterOneLoop: true,
                onDemoFinished: {
                    beginCurrentExercise(exercise)
                }
            )

            Button {
                beginCurrentExercise(exercise)
            } label: {
                Label("Começar exercício", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text("A demonstração avança automaticamente após um ciclo do GIF.")
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(AppTheme.cardBackground.opacity(0.5))
    }

    private func exerciseExecutionCard(for exercise: Exercise, record: ExerciseSessionRecord) -> some View {
        VStack(spacing: 16) {
            Text("Exercício Atual")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Text(exercise.name)
                .font(.title.bold())
                .foregroundStyle(AppTheme.textPrimary)

            if !exercise.notes.isEmpty {
                Text(exercise.notes)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            ExerciseExecutionGuideView(
                steps: exercise.executionGuide,
                exercise: exercise,
                compact: true,
                showsDemo: false
            )

            HStack(spacing: 8) {
                Image(systemName: timerService.isRunning ? "pause.circle.fill" : "stopwatch.fill")
                    .foregroundStyle(timerService.isRunning ? .orange : AppTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let seconds = timerService.isRunning
                            ? liveExerciseElapsedSeconds
                            : workoutStore.liveExerciseElapsedSeconds(at: context.date)
                        Text(DurationFormatting.format(seconds: seconds))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(timerService.isRunning ? .orange : AppTheme.accent)
                    }
                    if timerService.isRunning {
                        Text("Cronômetro pausado")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }

            HStack(spacing: 24) {
                let done = setsDone(for: exercise.id)
                let total = max(exercise.sets, 1)
                let current = SetProgressFormatting.currentSet(completed: done, totalSets: total)

                VStack(spacing: 4) {
                    Text(SetProgressFormatting.progressLabel(completed: done, totalSets: total))
                        .font(.title3.bold())
                        .monospacedDigit()
                    Text(done >= total ? "Séries concluídas" : "Série \(current)")
                        .font(.caption)
                }

                VStack(spacing: 4) {
                    Text("\(total)")
                        .font(.title2.bold())
                        .monospacedDigit()
                    Text("Total")
                        .font(.caption)
                }

                VStack(spacing: 4) {
                    Text("\(exercise.reps)")
                        .font(.title2.bold())
                    Text("Reps")
                        .font(.caption)
                }
            }
            .foregroundStyle(AppTheme.textPrimary)

            ExerciseLoadEditor(
                recommendedWeight: exercise.recommendedWeight,
                performedWeightText: performedWeightBinding(for: exercise)
            )

            HStack(spacing: 12) {
                Button {
                    completeSet(for: exercise)
                } label: {
                    let done = setsDone(for: exercise.id)
                    let total = max(exercise.sets, 1)
                    let isLast = SetProgressFormatting.isLastSet(completed: done, totalSets: total)
                    Label(
                        isLast ? "Última série · Finalizar" : "Série Completa",
                        systemImage: isLast ? "flag.checkered" : "checkmark.circle.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(setsDone(for: exercise.id) >= max(exercise.sets, 1))
                .opacity(setsDone(for: exercise.id) >= max(exercise.sets, 1) ? 0.5 : 1)

                Button {
                    // Pausa conclui a série atual e inicia o descanso.
                    // Só finaliza o exercício se for a última série.
                    completeSet(for: exercise)
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "timer")
                            .font(.title3)
                        Text("Pausa")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 56, height: 50)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(setsDone(for: exercise.id) >= max(exercise.sets, 1))
                .opacity(setsDone(for: exercise.id) >= max(exercise.sets, 1) ? 0.5 : 1)
                .accessibilityLabel("Concluir série e pausar \(timerService.configuredRestSeconds) segundos")
            }

            Button {
                markExerciseComplete(exercise)
            } label: {
                Label("Concluir Exercício", systemImage: "flag.checkered")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(AppTheme.cardBackground.opacity(0.5))
    }

    private func prepareDemoForCurrentExercise(force: Bool) {
        guard let exercise = workoutStore.currentExercise else { return }
        guard force || demoExerciseId != exercise.id else { return }
        demoExerciseId = exercise.id
        isShowingExerciseDemo = true
        workoutStore.setExerciseTimerPaused(true)
        ensurePerformedWeightText(for: exercise)
    }

    private func beginCurrentExercise(_ exercise: Exercise) {
        guard demoExerciseId == exercise.id else { return }
        ensurePerformedWeightText(for: exercise)
        isShowingExerciseDemo = false
        workoutStore.setExerciseTimerPaused(false)
        syncWatchWorkoutState()
    }

    private func ensurePerformedWeightText(for exercise: Exercise) {
        guard performedWeightTextByExercise[exercise.id] == nil else { return }
        if let recorded = workoutStore.exerciseRecords.first(where: { $0.exerciseId == exercise.id })?.performedWeight {
            performedWeightTextByExercise[exercise.id] = ExerciseLoadEditor.text(from: recorded)
        } else {
            performedWeightTextByExercise[exercise.id] = ExerciseLoadEditor.text(from: exercise.recommendedWeight)
        }
    }

    private func performedWeightBinding(for exercise: Exercise) -> Binding<String> {
        Binding(
            get: {
                performedWeightTextByExercise[exercise.id]
                    ?? ExerciseLoadEditor.text(from: exercise.recommendedWeight)
            },
            set: { newValue in
                performedWeightTextByExercise[exercise.id] = newValue
                workoutStore.updatePerformedWeight(
                    exerciseId: exercise.id,
                    weight: ExerciseLoadEditor.weight(from: newValue)
                )
            }
        )
    }

    private func syncWatchWorkoutState() {
        guard let session = workoutStore.activeSession else { return }
        let exerciseName = workoutStore.currentExercise?.name ?? ""
        let exerciseElapsed = workoutStore.exerciseRecords
            .first(where: { $0.exerciseId == workoutStore.currentExercise?.id })?
            .elapsedSeconds ?? 0

        if !watchConnectivity.isWorkoutActiveOnWatch {
            watchConnectivity.startWorkoutOnWatch(
                workoutName: session.workoutTitle,
                exerciseName: exerciseName
            )
        } else {
            watchConnectivity.syncWorkoutProgress(
                workoutElapsedSeconds: workoutElapsedSeconds,
                exerciseName: exerciseName,
                exerciseElapsedSeconds: exerciseElapsed
            )
        }
    }

    private var exerciseListContent: some View {
        LazyVStack(spacing: 8) {
            Text("Toque em um exercício para treiná-lo agora (sem precisar seguir a ordem).")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            ForEach(Array(sheet.exercises.enumerated()), id: \.element.id) { index, exercise in
                ExerciseTrackingRow(
                    exercise: exercise,
                    index: index,
                    record: workoutStore.exerciseRecords.first(where: { $0.exerciseId == exercise.id }),
                    isCurrent: index == workoutStore.currentExerciseIndex,
                    isPaused: index == workoutStore.currentExerciseIndex && timerService.isRunning,
                    completedSets: setsDone(for: exercise.id),
                    onSelect: {
                        selectExercise(at: index)
                    },
                    onMarkComplete: {
                        markExerciseComplete(exercise)
                    }
                )
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Button {
                requestEarlyEnd()
            } label: {
                Label("Encerrar treino sem concluir", systemImage: "xmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isFinishing)
            .accessibilityHint("Encerra o treino antes de concluir todos os exercícios e pede uma justificativa")

            HStack(spacing: 16) {
                Button {
                    showVision = true
                } label: {
                    Label("Vision", systemImage: "camera.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                }
                .accessibilityHint("Abre a câmera com Vision AI")

                Spacer()

                if timerService.isRunning {
                    Label("Descanso: \(timerService.formattedTime)", systemImage: "timer")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accentSecondary)
                } else {
                    Text("Descanso acumulado: \(DurationFormatting.format(seconds: timerService.totalRestSeconds))")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func requestEarlyEnd() {
        guard !isFinishing else { return }
        pendingEarlyEndJustification = nil
        earlyEndJustification = ""
        showEarlyEndSheet = true
    }

    private func presentAutoEndedSession(_ session: WorkoutSession) {
        guard finishedSession == nil else { return }
        isFinishing = true
        if workoutStore.isActiveWorkoutMinimized {
            workoutStore.resumeActiveWorkout()
        }
        timerService.stopTimer()
        watchConnectivity.sendRestTimerStop()
        watchConnectivity.stopWorkoutOnWatch()
        WorkoutLiveActivitySync.end()
        // Mesma ordem do finishWorkout: resumo primeiro, para não perder o host.
        finishedSession = session
    }

    private func completeSet(for exercise: Exercise) {
        let total = max(exercise.sets, 1)
        let current = workoutStore.recordSetCompleted(exerciseId: exercise.id, totalSets: total)

        if current >= total {
            // Última série (3/3, 4/4, 5/5…): finaliza o exercício.
            markExerciseComplete(exercise)
            // Descanso opcional após a última série.
            startRest(for: exercise)
        } else {
            startRest(for: exercise)
        }
    }

    private func startRest(for exercise: Exercise) {
        // Usa o descanso configurado no Perfil (não sobrescreve com o valor do exercício).
        timerService.startRest(for: exercise.name, exerciseId: exercise.id)
        workoutStore.setExerciseTimerPaused(true)
        watchConnectivity.sendRestTimerStart(
            seconds: timerService.remainingSeconds > 0
                ? timerService.remainingSeconds
                : timerService.configuredRestSeconds,
            exerciseName: exercise.name
        )
        syncLockScreenLiveActivity()
    }

    private func markExerciseComplete(_ exercise: Exercise) {
        guard let index = sheet.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        workoutStore.markExerciseCompleted(at: index)
        prepareDemoForCurrentExercise(force: true)
        syncWatchWorkoutState()
        syncLockScreenLiveActivity()
    }

    private func selectExercise(at index: Int) {
        guard sheet.exercises.indices.contains(index) else { return }
        guard workoutStore.selectExercise(at: index) else { return }
        prepareDemoForCurrentExercise(force: true)
        syncLiveExerciseElapsed()
        syncWatchWorkoutState()
        syncLockScreenLiveActivity()
    }

    private func syncLockScreenLiveActivity() {
        WorkoutLiveActivitySync.push(
            workoutStore: workoutStore,
            timerService: timerService,
            sheet: sheet
        )
    }

    private func updateWorkoutElapsed() {
        workoutElapsedSeconds = workoutStore.liveWorkoutElapsedSeconds()

        let exerciseName = workoutStore.currentExercise?.name ?? ""
        let exerciseElapsed = workoutStore.liveExerciseElapsedSeconds()

        watchConnectivity.syncWorkoutProgress(
            workoutElapsedSeconds: workoutElapsedSeconds,
            exerciseName: exerciseName,
            exerciseElapsedSeconds: exerciseElapsed
        )
    }

    private func syncLiveExerciseElapsed() {
        liveExerciseElapsedSeconds = workoutStore.liveExerciseElapsedSeconds()
    }

    private func syncWatchData() {
        if watchConnectivity.watchHeartRate > 0 {
            workoutStore.addHeartRateSample(watchConnectivity.watchHeartRate)
        }
        workoutStore.updateCalories(watchConnectivity.watchCalories)
    }

    private func finishWorkout(endedEarly: Bool = false, justification: String? = nil) {
        guard !isFinishing else { return }
        isFinishing = true

        timerService.stopTimer()
        watchConnectivity.sendRestTimerStop()
        watchConnectivity.stopWorkoutOnWatch()
        workoutStore.applyRestSeconds(from: timerService)
        WorkoutLiveActivitySync.end()

        guard var session = workoutStore.activeSession else {
            closeHostedWorkout()
            return
        }

        // Summary covers must be visible even if the user had minimized the workout.
        if workoutStore.isActiveWorkoutMinimized {
            workoutStore.resumeActiveWorkout()
        }

        session.endedAt = .now
        session.exerciseRecords = workoutStore.exerciseRecords
        session.completedExercises = workoutStore.exerciseRecords.filter(\.isCompleted).count
        session.endedEarly = endedEarly
        session.earlyEndJustification = endedEarly
            ? justification?.trimmingCharacters(in: .whitespacesAndNewlines)
            : nil

        Task {
            await healthKitManager.saveWorkout(
                duration: session.duration,
                calories: session.caloriesBurned,
                heartRate: session.averageHeartRate,
                activityType: .traditionalStrengthTraining
            )
        }
        NotificationService.shared.deliverWorkoutEndNotification(
            session: session,
            athleteName: authService.currentUser?.greetingName ?? "Atleta"
        )

        // Define o resumo ANTES de limpar activeSession, para o fullScreenCover
        // aparecer mesmo se o MainTabView reagir ao fim da sessão.
        finishedSession = session
        workoutStore.endSession(persisting: session)
    }
}

private struct EarlyEndJustificationSheet: View {
    @Binding var justification: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var canConfirm: Bool {
        !justification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Por que você está encerrando o treino antes de concluir todos os exercícios?")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)

                TextEditor(text: $justification)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.textSecondary.opacity(0.25), lineWidth: 1)
                    )

                Text("Essa justificativa será enviada no relatório ao personal.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)

                Spacer()

                Button {
                    onConfirm()
                } label: {
                    Text("Confirmar encerramento")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canConfirm ? Color.red : Color.red.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!canConfirm)
            }
            .padding()
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Encerrar antecipadamente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: onCancel)
                }
            }
        }
    }
}

struct ExerciseTrackingRow: View {
    let exercise: Exercise
    let index: Int
    let record: ExerciseSessionRecord?
    let isCurrent: Bool
    let isPaused: Bool
    let completedSets: Int
    var onSelect: (() -> Void)? = nil
    let onMarkComplete: () -> Void

    private var isCompleted: Bool {
        record?.isCompleted ?? false
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCompleted || isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary)
                Text(SetProgressFormatting.progressLabel(completed: completedSets, totalSets: exercise.sets))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("Total \(max(exercise.sets, 1)) séries")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.85))
                if let weightLabel = record?.weightComparisonLabel {
                    Text(weightLabel)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                } else if exercise.recommendedWeight != nil {
                    Text("Rec. \(exercise.recommendedWeightLabel)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }

            Spacer()

            Text(DurationFormatting.format(seconds: record?.elapsedSeconds ?? 0))
                .font(.system(.caption, design: .monospaced).weight(.medium))
                .foregroundStyle(isPaused ? .orange : (isCurrent ? AppTheme.accent : AppTheme.textSecondary))

            if isCurrent && !isCompleted {
                Button(action: onMarkComplete) {
                    Image(systemName: "checkmark.circle")
                        .font(.title3)
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            } else if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(isCurrent ? AppTheme.accent.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isCurrent else { return }
            onSelect?()
        }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityHint(isCurrent ? "Exercício atual" : "Toque para treinar este exercício agora")
    }

    private var statusIcon: String {
        if isCompleted { return "checkmark.circle.fill" }
        if isCurrent { return "play.circle.fill" }
        return "circle"
    }

    private var statusColor: Color {
        if isCompleted || isCurrent { return AppTheme.accent }
        return AppTheme.textSecondary
    }
}

struct WorkoutStartMotivationOverlay: View {
    let onContinue: () -> Void

    private let cardMaxWidth: CGFloat = 310
    private let cardMaxHeight: CGFloat = 240

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)

                Text("Hora de treinar!")
                    .font(.callout.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)

                ScrollView {
                    Text(MotivationMessages.workoutStartFocusMessage)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 80)
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)

                Button(action: onContinue) {
                    Label("Vamos lá!", systemImage: "play.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: cardMaxWidth)
            .frame(maxHeight: cardMaxHeight)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 40)
        }
    }
}

struct RestTimerOverlay: View {
    @EnvironmentObject var timerService: RestTimerService
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Text(timerService.isAwaitingResumeAcknowledgment ? "Descanso encerrado!" : "Pausa")
                    .font(.headline)
                    .foregroundStyle(timerService.isAwaitingResumeAcknowledgment ? AppTheme.accentSecondary : AppTheme.textSecondary)

                if !timerService.currentExerciseName.isEmpty {
                    Text(timerService.currentExerciseName)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Circle()
                            .trim(
                                from: 0,
                                to: timerService.isAwaitingResumeAcknowledgment
                                    ? 1
                                    : timerService.progress(at: context.date)
                            )
                            .stroke(
                                timerService.isAwaitingResumeAcknowledgment
                                    || timerService.isOvertime(at: context.date)
                                    ? Color.red
                                    : AppTheme.accent,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                    }

                    if timerService.isAwaitingResumeAcknowledgment {
                        VStack(spacing: 4) {
                            Image(systemName: "bell.badge.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            Text("00:00")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundStyle(.red)
                        }
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text(timerService.formattedTime(at: context.date))
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .foregroundStyle(timerService.isOvertime(at: context.date) ? .red : AppTheme.textPrimary)
                        }
                    }
                }

                if !timerService.isAwaitingResumeAcknowledgment {
                    VStack(spacing: 8) {
                        Text("Tempo configurado: \(timerService.configuredRestSeconds)s")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)

                        HStack(spacing: 20) {
                            Button {
                                timerService.adjustConfiguredRestSeconds(by: -15)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .disabled(timerService.configuredRestSeconds <= 15)
                            .accessibilityLabel("Diminuir pausa 15 segundos")

                            Button {
                                timerService.adjustConfiguredRestSeconds(by: 15)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppTheme.accent)
                            }
                            .disabled(timerService.configuredRestSeconds >= 300)
                            .accessibilityLabel("Aumentar pausa 15 segundos")
                        }
                    }
                }

                if timerService.isAwaitingResumeAcknowledgment {
                    Button {
                        timerService.acknowledgeRestAndResume()
                        watchConnectivity.sendRestTimerStop()
                    } label: {
                        Text("OK vamos lá")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else {
                    Button("Pular Descanso") {
                        timerService.stopTimer()
                        watchConnectivity.sendRestTimerStop()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding()
        }
    }
}

import Combine
