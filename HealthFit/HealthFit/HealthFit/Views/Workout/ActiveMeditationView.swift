import SwiftUI
import UIKit
import Combine

struct ActiveMeditationView: View {
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var liveMetrics = LiveMetricsHub.shared

    let config: MeditationWorkoutConfig
    var onReturnToWorkoutList: (() -> Void)? = nil
    /// Quando hospedada no MainTab (não como sheet), fecha o overlay.
    var onHostClose: (() -> Void)? = nil

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

    private var liveHeartRateBPM: Double { liveMetrics.heartRateBPM }
    private var liveCalories: Double { max(liveMetrics.liveCalories, watchConnectivity.watchCalories) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 28) {
                    topicBadge
                    liveWatchMetricsBar
                    timerRing
                    guidanceCard
                    Spacer()
                    endButton
                }
                .padding(DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                .adaptiveContentWidth()
            }
            .navigationTitle(isStudyFocusSession ? "Foco em estudo" : "Meditação")
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
        .onAppear {
            // Não reabre o cronômetro depois do resumo (Fechar).
            guard finishedSession == nil, !isFinishing else { return }
            elapsedSeconds = wallClockElapsedSeconds()
            ensureWatchMeditationActive()
            if isStudyFocusSession {
                UIApplication.shared.isIdleTimerDisabled = true
                syncStudyFocusLockScreen()
            }
        }
        .onDisappear {
            if isStudyFocusSession {
                UIApplication.shared.isIdleTimerDisabled = false
                NotificationService.shared.cancelStudyFocusPriorityReminders()
                WorkoutLiveActivityController.shared.end()
            }
        }
        .onReceive(clock) { _ in
            guard finishedSession == nil, !isFinishing else { return }
            elapsedSeconds = wallClockElapsedSeconds()
            // Em background: só encerra por tempo; evita sync Watch a cada segundo.
            if scenePhase == .active {
                ensureWatchMeditationActive()
                syncLiveWatchSamples()
            }
            // Live Activity continua atualizando com o celular bloqueado.
            if isStudyFocusSession {
                syncStudyFocusLockScreen()
            }
            if elapsedSeconds >= config.targetDurationSeconds {
                finishMeditation()
            } else if scenePhase == .active, shouldAutoEndByInactivity {
                finishMeditation(autoEndedByInactivity: true)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Ao voltar do background: atualiza o contador e desbloqueia Encerrar se travou.
            guard phase == .active else { return }
            elapsedSeconds = wallClockElapsedSeconds()
            if isFinishing, finishedSession == nil, workoutStore.activeSession != nil {
                isFinishing = false
            }
            if elapsedSeconds >= config.targetDurationSeconds, finishedSession == nil {
                finishMeditation()
            }
        }
        .onReceive(workoutStore.sessionAutoEnded) { ended in
            guard finishedSession == nil, !isFinishing else { return }
            isFinishing = true
            watchConnectivity.stopWorkoutOnWatch()
            finishedSession = ended
        }
        .onChange(of: watchConnectivity.watchForcedSessionCloseTick) { _, tick in
            guard tick > 0, !isFinishing, finishedSession == nil else { return }
            finishMeditation()
        }
        .fullScreenCover(item: $finishedSession) { session in
            WorkoutSummaryView(
                session: session,
                onFinish: {
                    closeMeditationHost()
                },
                onReturnToWorkoutList: {
                    onReturnToWorkoutList?()
                    closeMeditationHost()
                }
            )
        }
    }

    private func ensureWatchMeditationActive() {
        guard !isFinishing, finishedSession == nil, workoutStore.activeSession != nil else { return }
        if !watchConnectivity.isWorkoutActiveOnWatch {
            watchConnectivity.startMeditationOnWatch(
                workoutName: config.title,
                targetSeconds: config.targetDurationSeconds,
                topicName: config.topic.name,
                topicIcon: config.topic.icon,
                colorName: config.topic.colorName,
                currentPrompt: currentPrompt,
                promptIndex: currentPromptIndex,
                totalPrompts: config.topic.prompts.count
            )
        }
        watchConnectivity.syncMeditationProgress(
            elapsedSeconds: elapsedSeconds,
            targetSeconds: config.targetDurationSeconds,
            currentPrompt: currentPrompt,
            promptIndex: currentPromptIndex
        )
    }

    private func closeMeditationHost() {
        // Remove o overlay do MainTab (cronômetro + resumo juntos).
        if let onHostClose {
            onHostClose()
        } else {
            dismiss()
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

    private var liveWatchMetricsBar: some View {
        HStack(spacing: 16) {
            Label {
                Text(liveHeartRateBPM > 0 ? "\(Int(liveHeartRateBPM)) BPM" : "— BPM")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            } icon: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
            }
            Label {
                Text("\(Int(liveCalories)) kcal")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
            } icon: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
            }
            if watchConnectivity.isWatchConnected {
                Image(systemName: "applewatch")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground)
        .clipShape(Capsule())
        .accessibilityLabel("Batimentos e calorias do Apple Watch")
    }

    private func syncLiveWatchSamples() {
        if liveHeartRateBPM > 0 {
            workoutStore.addHeartRateSample(liveHeartRateBPM)
        }
        if liveCalories > 0 {
            workoutStore.updateCalories(liveCalories)
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
                    config.topic.color,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            VStack(spacing: 4) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(DurationFormatting.format(seconds: max(config.targetDurationSeconds - wallClockElapsedSeconds(at: context.date), 0)))
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                }
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
            Label(
                isStudyFocusSession ? "Finalizar foco" : "Finalizar Meditação",
                systemImage: "checkmark.circle.fill"
            )
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var isStudyFocusSession: Bool {
        config.isStudyFocus
    }

    private func syncStudyFocusLockScreen() {
        guard isStudyFocusSession, !isFinishing, finishedSession == nil,
              let session = workoutStore.activeSession else { return }
        // Fim absoluto da sessão — a Live Activity conta sozinha com o celular bloqueado.
        let endDate = session.startedAt.addingTimeInterval(TimeInterval(config.targetDurationSeconds))
        WorkoutLiveActivityController.shared.startOrUpdate(
            session: session,
            exerciseName: config.topic.name,
            setsLabel: "estudo restante",
            exerciseElapsedSeconds: elapsedSeconds,
            isResting: true,
            restEndDate: endDate,
            modalitySystemImage: "book.fill"
        )
    }

    private var shouldAutoEndByInactivity: Bool {
        // Sessão de estudo pode durar o tempo escolhido sem auto-fim por “inatividade”.
        guard !isStudyFocusSession else { return false }
        guard let startedAt = workoutStore.activeSession?.startedAt, !isFinishing else { return false }
        return Date.now.timeIntervalSince(startedAt) >= WorkoutStore.autoEndInactivityLimit
    }

    private func wallClockElapsedSeconds(at date: Date = Date()) -> Int {
        guard let startedAt = workoutStore.activeSession?.startedAt else {
            return max(0, elapsedSeconds)
        }
        return max(0, Int(date.timeIntervalSince(startedAt)))
    }

    private func finishMeditation(autoEndedByInactivity: Bool = false) {
        // Evita deadlock: se já finalizou e o sheet sumiu, ainda permite fechar o host.
        if finishedSession != nil {
            closeMeditationHost()
            return
        }
        guard !isFinishing else {
            // Estado preso após background — força encerramento do host.
            if workoutStore.activeSession == nil {
                closeMeditationHost()
            }
            return
        }
        isFinishing = true

        watchConnectivity.stopWorkoutOnWatch()
        if isStudyFocusSession {
            WorkoutLiveActivityController.shared.end()
        }

        elapsedSeconds = wallClockElapsedSeconds()

        guard var session = workoutStore.activeSession else {
            if let last = workoutStore.sessionHistory.first,
               last.autoEndedByInactivity {
                finishedSession = last
            } else {
                isFinishing = false
                closeMeditationHost()
            }
            return
        }

        session.endedAt = .now
        session.exerciseRecords = [
            ExerciseSessionRecord(
                exerciseId: config.topic.id,
                exerciseName: config.topic.name,
                elapsedSeconds: elapsedSeconds,
                restSeconds: 0,
                isCompleted: !autoEndedByInactivity && elapsedSeconds >= config.targetDurationSeconds / 2
            )
        ]
        session.completedExercises = session.exerciseRecords.filter(\.isCompleted).count
        if autoEndedByInactivity {
            session.endedEarly = true
            session.autoEndedByInactivity = true
            session.earlyEndJustification = WorkoutStore.autoEndJustification
        }

        NotificationService.shared.deliverWorkoutEndNotification(
            session: session,
            athleteName: authService.currentUser?.greetingName ?? "Atleta"
        )

        if isStudyFocusSession || config.isStudyFocus {
            StudyFocusStore.shared.recordCompletedSession(
                cardName: config.topic.name,
                durationSeconds: elapsedSeconds,
                prioritiesCount: config.topic.prompts.filter { $0.localizedCaseInsensitiveContains("prioridade") }.count
            )
            NotificationService.shared.deliverStudyFocusProgressNotification(
                athleteName: authService.currentUser?.greetingName ?? "Atleta",
                sessions: workoutStore.sessionHistory + [session]
            )
        }

        finishedSession = session
        workoutStore.endSession(persisting: session)
    }
}
