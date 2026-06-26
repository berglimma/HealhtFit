import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var timerService: RestTimerService
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @Environment(\.dismiss) private var dismiss

    let sheet: WorkoutSheet
    @State private var showRestTimer = false
    @State private var completedSets: [UUID: Int] = [:]

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
                        endWorkout()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            syncWatchData()
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            ProgressView(
                value: Double(workoutStore.activeSession?.completedExercises ?? 0),
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
                Label(timerService.formattedTime, systemImage: "timer")
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
            if let exercise = workoutStore.currentExercise {
                VStack(spacing: 16) {
                    Text("Exercício Atual")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)

                    Text(exercise.name)
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.textPrimary)

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
                            timerService.configure(
                                restSeconds: exercise.restSeconds,
                                maxRest: exercise.restSeconds * 2,
                                notifications: true
                            )
                            timerService.startRest(for: exercise.name)
                            watchConnectivity.sendRestTimer(seconds: exercise.restSeconds)
                        } label: {
                            Image(systemName: "timer")
                                .font(.title2)
                                .foregroundStyle(AppTheme.accent)
                                .frame(width: 50, height: 50)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
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
                    HStack {
                        Image(systemName: index == workoutStore.currentExerciseIndex ? "play.circle.fill" : "circle")
                            .foregroundStyle(index == workoutStore.currentExerciseIndex ? AppTheme.accent : AppTheme.textSecondary)
                        Text(exercise.name)
                            .foregroundStyle(index <= workoutStore.currentExerciseIndex ? AppTheme.textPrimary : AppTheme.textSecondary)
                        Spacer()
                        Text("\(completedSets[exercise.id, default: 0])/\(exercise.sets)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
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

            Text("Descanso: \(workoutStore.currentExercise?.restSeconds ?? 60)s")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding()
        .background(AppTheme.cardBackground)
    }

    private func completeSet(for exercise: Exercise) {
        let current = completedSets[exercise.id, default: 0] + 1
        completedSets[exercise.id] = current

        if current >= exercise.sets {
            workoutStore.completeExercise()
            timerService.configure(
                restSeconds: exercise.restSeconds,
                maxRest: exercise.restSeconds * 2,
                notifications: true
            )
            timerService.startRest(for: exercise.name)
        }
    }

    private func syncWatchData() {
        if watchConnectivity.watchHeartRate > 0 {
            workoutStore.addHeartRateSample(watchConnectivity.watchHeartRate)
        }
        workoutStore.updateCalories(watchConnectivity.watchCalories)
    }

    private func endWorkout() {
        timerService.stopTimer()
        watchConnectivity.stopWorkoutOnWatch()

        if let session = workoutStore.activeSession {
            Task {
                await healthKitManager.saveWorkout(
                    duration: session.duration,
                    calories: session.caloriesBurned,
                    heartRate: session.averageHeartRate
                )
            }
            NotificationService.shared.scheduleWorkoutComplete(title: session.workoutTitle)
        }

        workoutStore.endSession()
        dismiss()
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
                    Text("Descanso prolongado — notificação enviada")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
