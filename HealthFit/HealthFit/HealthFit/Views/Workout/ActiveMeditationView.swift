import SwiftUI

struct ActiveMeditationView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let config: MeditationWorkoutConfig

    @State private var elapsedSeconds = 0
    @State private var finishedSession: WorkoutSession?
    @State private var isFinishing = false

    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var progress: Double {
        guard config.targetDurationSeconds > 0 else { return 0 }
        return min(Double(elapsedSeconds) / Double(config.targetDurationSeconds), 1.0)
    }

    private var currentPromptIndex: Int {
        guard !config.topic.prompts.isEmpty else { return 0 }
        let interval = max(config.targetDurationSeconds / config.topic.prompts.count, 1)
        return min(elapsedSeconds / interval, config.topic.prompts.count - 1)
    }

    private var currentPrompt: String {
        config.topic.prompts[currentPromptIndex]
    }

    private var remainingSeconds: Int {
        max(config.targetDurationSeconds - elapsedSeconds, 0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 28) {
                    topicBadge
                    timerRing
                    guidanceCard
                    Spacer()
                    endButton
                }
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .navigationTitle("Meditação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Encerrar") {
                        finishMeditation()
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .onReceive(clock) { _ in
            elapsedSeconds += 1
            watchConnectivity.syncMeditationProgress(
                elapsedSeconds: elapsedSeconds,
                targetSeconds: config.targetDurationSeconds,
                currentPrompt: currentPrompt,
                promptIndex: currentPromptIndex
            )
            if elapsedSeconds >= config.targetDurationSeconds && !isFinishing {
                finishMeditation()
            }
        }
        .onAppear {
            watchConnectivity.syncMeditationProgress(
                elapsedSeconds: elapsedSeconds,
                targetSeconds: config.targetDurationSeconds,
                currentPrompt: currentPrompt,
                promptIndex: currentPromptIndex
            )
        }
        .fullScreenCover(item: $finishedSession) { session in
            WorkoutSummaryView(session: session) {
                finishedSession = nil
                dismiss()
            }
        }
    }

    private var topicBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: config.topic.icon)
            Text(config.topic.name)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(config.topic.color)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(config.topic.color.opacity(0.15))
        .clipShape(Capsule())
    }

    private var timerRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 14)
                .frame(width: 220, height: 220)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    config.topic.color,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            VStack(spacing: 4) {
                Text(DurationFormatting.format(seconds: remainingSeconds))
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("restantes")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var guidanceCard: some View {
        VStack(spacing: 12) {
            Text("Etapa \(currentPromptIndex + 1) de \(config.topic.prompts.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(config.topic.color)

            Text(currentPrompt)
                .font(.title3)
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.5), value: currentPromptIndex)
                .frame(minHeight: 80)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }

    private var endButton: some View {
        Button {
            finishMeditation()
        } label: {
            Label("Finalizar Meditação", systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private func finishMeditation() {
        guard !isFinishing else { return }
        isFinishing = true

        watchConnectivity.stopWorkoutOnWatch()

        guard var session = workoutStore.activeSession else {
            dismiss()
            return
        }

        session.endedAt = .now
        session.exerciseRecords = [
            ExerciseSessionRecord(
                exerciseId: config.topic.id,
                exerciseName: config.topic.name,
                elapsedSeconds: elapsedSeconds,
                restSeconds: 0,
                isCompleted: elapsedSeconds >= config.targetDurationSeconds / 2
            )
        ]
        session.completedExercises = session.exerciseRecords.filter(\.isCompleted).count

        NotificationService.shared.deliverWorkoutEndNotification(
            session: session,
            athleteName: authService.currentUser?.name ?? "Atleta"
        )

        workoutStore.endSession()
        finishedSession = session
    }
}
