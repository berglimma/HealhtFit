import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var workoutStore: WorkoutStore
    @ObservedObject private var checkInService = PostWorkoutCheckInService.shared
    @ObservedObject private var dailyMorningService = DailyMorningCheckInService.shared
    @ObservedObject private var dailyEveningService = DailyEveningCheckInService.shared
    @ObservedObject private var profileReminder = ProfileDataReminderService.shared
    @State private var selectedTab = 0
    @State private var isShowingProfileDataPrompt = false
    @State private var presentedActiveSheet: WorkoutSheet?

    private let assistantTabTag = 3
    private let nutritionTabTag = 2
    private let profileTabTag = 4
    private let workoutsTabTag = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(L10n.Tab.home, systemImage: "house.fill")
                }
                .tag(0)

            WorkoutListView()
                .tabItem {
                    Label(L10n.Tab.workouts, systemImage: "dumbbell.fill")
                }
                .tag(workoutsTabTag)

            MealPlanView()
                .tabItem {
                    Label(L10n.Tab.nutrition, systemImage: "fork.knife")
                }
                .tag(nutritionTabTag)

            HealthChatView()
                .tabItem {
                    Label(L10n.Tab.assistant, systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(assistantTabTag)
                .badge(checkInService.assistantTabBadgeCount)

            ProfileView()
                .tabItem {
                    Label(L10n.Tab.profile, systemImage: "person.fill")
                }
                .tag(profileTabTag)
        }
        .tint(AppTheme.accent)
        .tabViewStyle(.automatic)
        // TabView ignores the tab bar when laying out chrome on itself, so a bare bottom
        // inset covers the menu. Reserve a hit-through strip under the banner matching
        // UITabBar content height so the card sits above the icons/labels.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let session = workoutStore.activeSession, workoutStore.isActiveWorkoutMinimized {
                VStack(spacing: 0) {
                    ActiveWorkoutBanner(
                        session: session,
                        currentExerciseName: workoutStore.currentExercise?.name
                    ) {
                        workoutStore.resumeActiveWorkout()
                        syncActiveWorkoutPresentation()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                    Color.clear
                        .frame(height: DeviceLayout.mainTabBarContentHeight)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .fullScreenCover(item: $presentedActiveSheet, onDismiss: {
            // Se o treino ainda está ativo, foi um minimizar (não o fim da sessão).
            if workoutStore.activeSession != nil {
                workoutStore.minimizeActiveWorkout()
            }
            syncActiveWorkoutPresentation()
        }) { sheet in
            ActiveWorkoutView(sheet: sheet) {
                selectedTab = workoutsTabTag
            }
        }
        .onAppear {
            updateAssistantTabVisibility(for: selectedTab)
            checkInService.refreshAssistantBadge()
            profileReminder.evaluate(for: authService.currentUser)
            syncActiveWorkoutPresentation()
            Task { @MainActor in
                // Aguarda o check-in de sono (se houver) ter prioridade antes do pop-up de dados.
                try? await Task.sleep(for: .milliseconds(700))
                presentProfilePromptIfNeeded()
            }
        }
        .onChange(of: selectedTab) { _, tab in
            // Libera o teclado do IAssistente para as abas/tab bar responderem no iPhone.
            KeyboardDismiss.hide()
            updateAssistantTabVisibility(for: tab)
        }
        .onChange(of: workoutStore.activeSession?.id) { _, _ in
            syncActiveWorkoutPresentation()
        }
        .onChange(of: workoutStore.isActiveWorkoutMinimized) { _, _ in
            syncActiveWorkoutPresentation()
        }
        .onChange(of: authService.currentUser?.id) { _, _ in
            profileReminder.evaluate(for: authService.currentUser)
            presentProfilePromptIfNeeded()
        }
        .onChange(of: wellnessService.showSleepCheckIn) { _, isShowingSleep in
            if isShowingSleep {
                // Evita conflito com o sheet de sono; o pop-up volta ao fechar.
                isShowingProfileDataPrompt = false
            } else {
                presentProfilePromptIfNeeded()
            }
        }
        .onChange(of: profileReminder.activePrompt) { _, _ in
            presentProfilePromptIfNeeded()
        }
        .onChange(of: dailyMorningService.state?.phase) { _, _ in
            checkInService.refreshAssistantBadge()
        }
        .onChange(of: dailyEveningService.state?.phase) { _, _ in
            checkInService.refreshAssistantBadge()
        }
        .alert(
            profileReminder.activePrompt?.title ?? "Seus dados",
            isPresented: $isShowingProfileDataPrompt
        ) {
            Button("Ir para Perfil") {
                handlePromptChoice(navigateTo: profileTabTag)
            }
            Button("Ir para Nutrição") {
                handlePromptChoice(navigateTo: nutritionTabTag)
            }
            Button("Agora não", role: .cancel) {
                handlePromptChoice(navigateTo: nil)
            }
        } message: {
            Text(profileReminder.activePrompt?.message ?? "")
        }
        .task {
            while !Task.isCancelled {
                checkInService.refreshAssistantBadge()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func presentProfilePromptIfNeeded() {
        guard profileReminder.activePrompt != nil else {
            isShowingProfileDataPrompt = false
            return
        }
        // Não compete com o check-in de sono.
        guard !wellnessService.showSleepCheckIn else {
            isShowingProfileDataPrompt = false
            return
        }
        isShowingProfileDataPrompt = true
    }

    private func handlePromptChoice(navigateTo tab: Int?) {
        isShowingProfileDataPrompt = false
        profileReminder.dismissPrompt(for: authService.currentUser?.id)

        guard let tab else { return }

        // Garante a troca de aba após o alert fechar (evita o tab ficar preso).
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            selectedTab = tab
        }
    }

    private func updateAssistantTabVisibility(for tab: Int) {
        checkInService.setAssistantTabActive(tab == assistantTabTag)
    }

    private func syncActiveWorkoutPresentation() {
        if let sheet = workoutStore.activeStrengthSheet(),
           workoutStore.activeSession != nil,
           !workoutStore.isActiveWorkoutMinimized {
            presentedActiveSheet = sheet
        } else if workoutStore.activeSession != nil, workoutStore.isActiveWorkoutMinimized {
            // Minimizar: fecha o cover do treino ativo.
            presentedActiveSheet = nil
        }
        // Se activeSession ficou nil (treino finalizado), NÃO limpar o cover aqui.
        // ActiveWorkoutView precisa permanecer vivo para exibir WorkoutSummaryView
        // (e-mail + card de compartilhar) e só então chamar dismiss().
    }
}
