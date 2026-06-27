import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var timerService: RestTimerService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    let sheet: WorkoutSheet
    @State private var completedSets: [UUID: Int] = [:]
    @State private var finishedSession: WorkoutSession?
    @State private var workoutElapsedSeconds = 0
    @State private var isFinishing = false

    private let workoutClock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    progressHeader
                    currentExerciseCard
                    exerciseList
                    bottomBar
                }

                if timerService.isRunning {
                    RestTimerOverlay()
                }
            }
            .navigationTitle(sheet.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Encerrar") {
                        finishWorkout()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            timerService.resetSessionTracking()
            timerService.onRestOvertime = { exerciseName in
                watchConnectivity.sendRestOvertimeAlert(exerciseName: exerciseName)
            }
            updateWorkoutElapsed()
        }
        .onChange(of: timerService.isRunning) { _, isResting in
            workoutStore.setExerciseTimerPaused(isResting)
            if isResting {
                // watch notified in startRest
            } else {
                watchConnectivity.sendRestTimerStop()
            }
        }
        .onReceive(workoutClock) { _ in
            updateWorkoutElapsed()
        }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            syncWatchData()
        }
        .onChange(of: workoutStore.allExercisesCompleted) { _, allDone in
            if allDone && !isFinishing {
                finishWorkout()
            }
        }
        .fullScreenCover(item: $finishedSession) { session in
            WorkoutSummaryView(session: session) {
                finishedSession = nil
                dismiss()
            }
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
                Label(DurationFormatting.format(seconds: workoutElapsedSeconds), systemImage: "clock.fill")
                    .foregroundStyle(AppTheme.accent)
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
                VStack(spacing: 16) {
                    Text("Exercício Atual")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(exercise.name)
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.textPrimary)

                    HStack(spacing: 8) {
                        Image(systemName: timerService.isRunning ? "pause.circle.fill" : "stopwatch.fill")
                            .foregroundStyle(timerService.isRunning ? .orange : AppTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DurationFormatting.format(seconds: record.elapsedSeconds))
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundStyle(timerService.isRunning ? .orange : AppTheme.accent)
                            if timerService.isRunning {
                                Text("Cronômetro pausado")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    HStack(spacing: 24) {
                        VStack {
                            Text("\(completedSets[exercise.id, default: 0])/\(exercise.sets)")
                                .font(.title2.bold())
                            Text("Séries")
                                .font(.caption)
                        }
                        VStack {
                            Text("\(exercise.reps)")
                                .font(.title2.bold())
                            Text("Reps")
                                .font(.caption)
                        }
                        if let weight = exercise.weight {
                            VStack {
                                Text("\(Int(weight))")
                                    .font(.title2.bold())
                                Text("kg")
                                    .font(.caption)
                            }
                        }
                    }
                    .foregroundStyle(AppTheme.textPrimary)

                    HStack(spacing: 12) {
                        Button {
                            completeSet(for: exercise)
                        } label: {
                            Label("Série Completa", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            startRest(for: exercise)
                        } label: {
                            Image(systemName: "timer")
                                .font(.title2)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 50, height: 50)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
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
        }
    }

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(sheet.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseTrackingRow(
                        exercise: exercise,
                        index: index,
                        record: workoutStore.exerciseRecords.first(where: { $0.exerciseId == exercise.id }),
                        isCurrent: index == workoutStore.currentExerciseIndex,
                        isPaused: index == workoutStore.currentExerciseIndex && timerService.isRunning,
                        completedSets: completedSets[exercise.id, default: 0],
                        onMarkComplete: {
                            markExerciseComplete(exercise)
                        }
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 16) {
            NavigationLink {
                VisionWorkoutView()
            } label: {
                Label("Vision", systemImage: "camera.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.accent)
            }

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
        .padding()
        .background(AppTheme.cardBackground)
    }

    private func completeSet(for exercise: Exercise) {
        let current = completedSets[exercise.id, default: 0] + 1
        completedSets[exercise.id] = current

        if current >= exercise.sets {
            startRest(for: exercise)
            markExerciseComplete(exercise)
        } else {
            startRest(for: exercise)
        }
    }

    private func startRest(for exercise: Exercise) {
        timerService.configure(
            restSeconds: exercise.restSeconds,
            maxRest: exercise.restSeconds * 2,
            notifications: true
        )
        timerService.startRest(for: exercise.name, exerciseId: exercise.id)
        workoutStore.setExerciseTimerPaused(true)
        watchConnectivity.sendRestTimerStart(seconds: exercise.restSeconds, exerciseName: exercise.name)
    }

    private func markExerciseComplete(_ exercise: Exercise) {
        guard let index = sheet.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
        workoutStore.markExerciseCompleted(at: index)
    }

    private func updateWorkoutElapsed() {
        guard let startedAt = workoutStore.activeSession?.startedAt else { return }
        workoutElapsedSeconds = max(0, Int(Date.now.timeIntervalSince(startedAt)))
    }

    private func syncWatchData() {
        if watchConnectivity.watchHeartRate > 0 {
            workoutStore.addHeartRateSample(watchConnectivity.watchHeartRate)
        }
        workoutStore.updateCalories(watchConnectivity.watchCalories)
    }

    private func finishWorkout() {
        guard !isFinishing else { return }
        isFinishing = true

        timerService.stopTimer()
        watchConnectivity.sendRestTimerStop()
        watchConnectivity.stopWorkoutOnWatch()
        workoutStore.applyRestSeconds(from: timerService)

        guard var session = workoutStore.activeSession else {
            dismiss()
            return
        }

        session.endedAt = .now
        session.exerciseRecords = workoutStore.exerciseRecords
        session.completedExercises = workoutStore.exerciseRecords.filter(\.isCompleted).count

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

struct ExerciseTrackingRow: View {
    let exercise: Exercise
    let index: Int
    let record: ExerciseSessionRecord?
    let isCurrent: Bool
    let isPaused: Bool
    let completedSets: Int
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
                Text("\(completedSets)/\(exercise.sets) séries")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
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

struct RestTimerOverlay: View {
    @EnvironmentObject var timerService: RestTimerService

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Text("Descanso")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: timerService.progress)
                        .stroke(
                            timerService.isOvertime ? Color.red : AppTheme.accent,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: timerService.progress)

                    Text(timerService.formattedTime)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundStyle(timerService.isOvertime ? .red : AppTheme.textPrimary)
                }

                if timerService.isOvertime {
                    Text("Descanso prolongado — notificações enviadas ao iPhone e Apple Watch")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }

                Button("Pular Descanso") {
                    timerService.stopTimer()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.accent)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding()
        }
    }
}

import Combine
