import SwiftUI

struct HealthChatView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var mealPlanService: MealPlanService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var assistant = HealthAssistantService()
    @ObservedObject private var checkInService = PostWorkoutCheckInService.shared
    @ObservedObject private var dailyMorningService = DailyMorningCheckInService.shared
    @ObservedObject private var dailyEveningService = DailyEveningCheckInService.shared
    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    private var context: HealthAssistantContext {
        let user = authService.currentUser
        let weeklyReport = WeeklyProgressAnalyzer.buildReport(
            sessions: workoutStore.sessionHistory,
            goal: user?.goal ?? .maintenance
        )
        let hoursSinceLastWorkout: Double? = workoutStore.lastCompletedWorkoutAt.map {
            Date().timeIntervalSince($0) / 3600
        }

        let todayWorkouts = DailyEveningCheckInEngine.completedSessionsToday(
            from: workoutStore.sessionHistory
        )

        return HealthAssistantContext(
            user: user,
            waterIntakeMl: wellnessService.todayEntry.waterIntakeMl,
            sleepHours: wellnessService.todayEntry.sleepHours,
            weeklyWorkoutCount: weeklyReport.currentWeek.workoutCount,
            hoursSinceLastWorkout: hoursSinceLastWorkout,
            todayWorkoutSessions: todayWorkouts,
            dailyCalorieTarget: mealPlanService.dailyCalorieTarget > 0
                ? mealPlanService.dailyCalorieTarget
                : (user?.dailyCalorieTarget ?? 0),
            basalMetabolicRate: mealPlanService.basalMetabolicRate > 0
                ? mealPlanService.basalMetabolicRate
                : (user?.basalMetabolicRate ?? 0),
            estimatedTDEE: mealPlanService.estimatedTDEE > 0
                ? mealPlanService.estimatedTDEE
                : (user?.estimatedTDEE ?? 0),
            caloricDeficit: mealPlanService.caloricDeficit > 0
                ? mealPlanService.caloricDeficit
                : (user?.caloricDeficit ?? 0),
            sweetConsumption: mealPlanService.customMenuSelection.sweetConsumption,
            lactoseTolerance: mealPlanService.customMenuSelection.lactoseTolerance
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(assistant.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            if assistant.isTyping {
                                TypingIndicatorBubble()
                                    .id("typing-indicator")
                            }
                        }
                        .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .onTapGesture {
                        dismissChatKeyboard()
                    }
                    .onChange(of: assistant.messages.count) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onChange(of: assistant.isTyping) { _, isTyping in
                        if isTyping {
                            dismissChatKeyboard()
                            scrollToBottom(proxy)
                        }
                    }
                }

                suggestionStrip

                Text(HealthAssistantEngine.healthSafetyDisclaimer)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
                    .padding(.bottom, 6)

                inputBar
            }
            .background(AppTheme.background)
            .navigationTitle("Assistente")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismissChatKeyboard()
                        assistant.clear(context: context)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Limpar conversa")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Fechar teclado") {
                        dismissChatKeyboard()
                    }
                    .fontWeight(.semibold)
                    Spacer()
                    if canSendDraft {
                        Button("Enviar") {
                            sendDraftIfPossible()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                bootstrapOrResumeCheckIn()
                assistant.handleTabReturn()
                assistant.checkCardioMeditationNudgeIfNeeded(
                    context: context,
                    sessions: workoutStore.sessionHistory,
                    accountCreatedAt: authService.currentUser?.createdAt
                )
            }
            .onDisappear {
                dismissChatKeyboard()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    assistant.refreshGuidedCheckInsIfNeeded(context: context)
                    assistant.checkInactivityFollowUpIfNeeded(
                        context: context,
                        sessions: workoutStore.sessionHistory
                    )
                    assistant.checkCardioMeditationNudgeIfNeeded(
                        context: context,
                        sessions: workoutStore.sessionHistory,
                        accountCreatedAt: authService.currentUser?.createdAt
                    )
                }
            }
            .onChange(of: checkInService.pendingCheckIn?.phase) { _, _ in
                assistant.refreshGuidedCheckInsIfNeeded(context: context)
            }
            .onChange(of: dailyMorningService.state?.phase) { _, _ in
                assistant.refreshGuidedCheckInsIfNeeded(context: context)
            }
            .onChange(of: dailyEveningService.state?.phase) { _, _ in
                assistant.refreshGuidedCheckInsIfNeeded(context: context)
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    assistant.refreshGuidedCheckInsIfNeeded(context: context)
                    assistant.checkInactivityFollowUpIfNeeded(
                        context: context,
                        sessions: workoutStore.sessionHistory
                    )
                    assistant.checkCardioMeditationNudgeIfNeeded(
                        context: context,
                        sessions: workoutStore.sessionHistory,
                        accountCreatedAt: authService.currentUser?.createdAt
                    )
                }
            }
            .onChange(of: draft) { _, newValue in
                if !newValue.isEmpty {
                    assistant.recordUserInteraction()
                }
            }
        }
    }

    private func bootstrapOrResumeCheckIn() {
        if let checkIn = checkInService.dueCheckIn, checkIn.phase == .scheduled {
            assistant.beginPostWorkoutCheckInIfNeeded(checkIn: checkIn, context: context)
        } else if checkInService.isAwaitingFeelingReply,
                  let checkIn = checkInService.pendingCheckIn {
            assistant.restoreInterruptedPostWorkoutCheckIn(checkIn: checkIn, context: context)
        } else if dailyEveningService.isDue,
                  dailyEveningService.state?.phase == .pending {
            assistant.beginDailyEveningCheckInIfNeeded(context: context)
        } else if dailyEveningService.isAwaitingReply {
            assistant.restoreInterruptedDailyEveningCheckIn(context: context)
        } else if dailyMorningService.isDue,
                  dailyMorningService.state?.phase == .pending {
            assistant.beginDailyMorningCheckInIfNeeded(context: context)
        } else if dailyMorningService.isAwaitingFeelingReply {
            assistant.restoreInterruptedDailyMorningCheckIn(context: context)
        } else {
            assistant.bootstrap(context: context)
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            if assistant.isTyping {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            } else if let last = assistant.messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private func dismissChatKeyboard() {
        isInputFocused = false
        KeyboardDismiss.hide()
    }

    private var canSendDraft: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !assistant.isTyping
    }

    private var suggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestedReplies, id: \.self) { question in
                    Button {
                        draft = ""
                        dismissChatKeyboard()
                        assistant.send(question, context: context, workoutStore: workoutStore)
                    } label: {
                        Text(question)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(assistant.isInGuidedCheckIn ? .white : AppTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(assistant.isInGuidedCheckIn ? AppTheme.accent : AppTheme.cardBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(assistant.isTyping)
                    .opacity(assistant.isTyping ? 0.5 : 1)
                }
            }
            .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
            .padding(.vertical, 8)
        }
        .background(AppTheme.background.opacity(0.95))
    }

    private var suggestedReplies: [String] {
        if assistant.isInPostWorkoutCheckIn {
            return PostWorkoutCheckInEngine.feelingQuickReplies
        }
        if assistant.isInDailyEveningCheckIn {
            if dailyEveningService.state?.phase == .askedRestReadiness {
                return DailyEveningCheckInEngine.restReadinessQuickReplies
            }
            return DailyEveningCheckInEngine.dayReflectionQuickReplies
        }
        if assistant.isInDailyMorningCheckIn {
            return DailyMorningCheckInEngine.feelingQuickReplies
        }
        if assistant.isInWorkoutBuilder {
            return assistant.workoutBuilderQuickReplies
        }
        return HealthAssistantEngine.suggestedQuestions
    }

    private var inputPlaceholder: String {
        if assistant.isInDailyEveningCheckIn {
            if dailyEveningService.state?.phase == .askedRestReadiness {
                return "Como está seu corpo e mente agora?"
            }
            return "Conte como foi seu dia..."
        }
        if assistant.isInWorkoutBuilder {
            return "Responda à pergunta do IAssistente..."
        }
        if assistant.isInGuidedCheckIn {
            return "Conte como você está se sentindo..."
        }
        return "Digite sua dúvida..."
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(inputPlaceholder, text: $draft)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.send)
                .focused($isInputFocused)
                .onSubmit {
                    sendDraftIfPossible()
                }
                .disabled(assistant.isTyping)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .foregroundStyle(AppTheme.textPrimary)

            if isInputFocused {
                Button {
                    dismissChatKeyboard()
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.title3)
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(AppTheme.cardBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fechar teclado")
            }

            Button {
                sendDraftIfPossible()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(canSendDraft ? AppTheme.accent : AppTheme.textSecondary)
                    .clipShape(Circle())
            }
            .disabled(!canSendDraft)
        }
        .padding(.horizontal, DeviceLayout.adaptivePadding(for: horizontalSizeClass))
        .padding(.vertical, 10)
        .background(AppTheme.cardBackground.opacity(0.6))
        .opacity(assistant.isTyping ? 0.85 : 1)
    }

    private func sendDraftIfPossible() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !assistant.isTyping else {
            dismissChatKeyboard()
            return
        }
        draft = ""
        dismissChatKeyboard()
        assistant.send(text, context: context, workoutStore: workoutStore)
    }
}

private struct TypingIndicatorBubble: View {
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "ellipsis.message.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.accent)
                    .modifier(RepeatingPulseSymbolEffect())

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        TypingDot(delay: Double(index) * 0.2)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .accessibilityLabel("Assistente digitando")

            Spacer(minLength: 48)
        }
    }
}

private struct TypingDot: View {
    let delay: Double
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(AppTheme.textSecondary)
            .frame(width: 7, height: 7)
            .offset(y: isAnimating ? -4 : 2)
            .animation(
                .easeInOut(duration: 0.45)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

private struct ChatBubble: View {
    let message: HealthChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 48) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.isUser ? .white : AppTheme.textPrimary)
                    .multilineTextAlignment(message.isUser ? .trailing : .leading)

                Text(message.timestamp, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(message.isUser ? .white.opacity(0.75) : AppTheme.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(message.isUser ? AppTheme.accent : AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if !message.isUser { Spacer(minLength: 48) }
        }
    }
}

#Preview {
    HealthChatView()
        .environmentObject(AuthService())
        .environmentObject(MealPlanService())
        .environmentObject(DailyWellnessService.shared)
        .environmentObject(WorkoutStore())
}
