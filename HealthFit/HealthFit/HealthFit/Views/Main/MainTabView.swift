import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var workoutStore: WorkoutStore
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var checkInService = PostWorkoutCheckInService.shared
    @ObservedObject private var dailyMorningService = DailyMorningCheckInService.shared
    @ObservedObject private var dailyEveningService = DailyEveningCheckInService.shared
    @ObservedObject private var profileReminder = ProfileDataReminderService.shared
    @State private var selectedTab = 0
    /// Only mount heavy tab roots after first visit — TabView otherwise builds all 5 eagerly.
    @State private var loadedTabs: Set<Int> = [0]
    @State private var isShowingProfileDataPrompt = false
    /// Keeps ActiveWorkoutView mounted for the whole strength session (and summary).
    /// Minimize only hides it — never dismiss/re-present a fullScreenCover.
    @State private var hostedActiveSheet: WorkoutSheet?
    /// Same Option A hosting for cardio/bike (keeps GPS map + tracker alive when minimized).
    @State private var hostedCardioConfig: CardioWorkoutConfig?
    /// Bumped to open the early-end sheet after resuming from the banner / conflict alert.
    @State private var openEarlyEndTick = 0
    /// Bumped to finish the hosted cardio session (summary + share card).
    @State private var requestCardioFinishTick = 0

    private let homeTabTag = 0
    private let assistantTabTag = 3
    private let nutritionTabTag = 2
    private let profileTabTag = 4
    private let workoutsTabTag = 1

    /// Ensures the tab's root view is created in the same update as selection (no empty flash).
    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                loadedTabs.insert(newValue)
                selectedTab = newValue
            }
        )
    }

    private var showsMinimizedWorkoutBanner: Bool {
        workoutStore.activeSession != nil
            && workoutStore.isActiveWorkoutMinimized
            && !workoutStore.isVisionCameraPresented
    }

    private var canEndFromMinimizedBanner: Bool {
        hostedActiveSheet != nil || hostedCardioConfig != nil
    }

    var body: some View {
        // ZStack keeps the minimized card above tab content without keyboard avoidance,
        // and hosts the active strength/cardio workout as a persistent overlay (not fullScreenCover)
        // so minimize/resume never races SwiftUI presentation identity.
        ZStack(alignment: .bottom) {
            TabView(selection: tabSelection) {
                lazyTab(homeTabTag) {
                    DashboardView()
                }
                .tabItem {
                    Label(L10n.Tab.home, systemImage: "house.fill")
                }
                .tag(homeTabTag)

                lazyTab(workoutsTabTag) {
                    WorkoutListView()
                }
                .tabItem {
                    Label(L10n.Tab.workouts, systemImage: "dumbbell.fill")
                }
                .tag(workoutsTabTag)

                lazyTab(nutritionTabTag) {
                    MealPlanView()
                }
                .tabItem {
                    Label(L10n.Tab.nutrition, systemImage: "fork.knife")
                }
                .tag(nutritionTabTag)

                lazyTab(assistantTabTag) {
                    HealthChatView()
                }
                .tabItem {
                    Label(L10n.Tab.assistant, systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(assistantTabTag)
                .badge(checkInService.assistantTabBadgeCount)

                lazyTab(profileTabTag) {
                    ProfileView()
                }
                .tabItem {
                    Label(L10n.Tab.profile, systemImage: "person.fill")
                }
                .tag(profileTabTag)
            }
            .tint(AppTheme.accent)
            .tabViewStyle(.automatic)

            if showsMinimizedWorkoutBanner, let session = workoutStore.activeSession {
                VStack(spacing: 0) {
                    ActiveWorkoutBanner(
                        session: session,
                        currentExerciseName: workoutStore.currentExercise?.name,
                        onResume: {
                            resumeMinimizedWorkout()
                        },
                        onEnd: canEndFromMinimizedBanner
                            ? { endMinimizedWorkoutFromBanner() }
                            : nil
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                    // Hit-through strip so UITabBar icons/labels still receive taps.
                    Color.clear
                        .frame(height: DeviceLayout.mainTabBarContentHeight)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, alignment: .bottom)
                .ignoresSafeArea(.keyboard)
                .zIndex(2)
            }

            if let sheet = hostedActiveSheet {
                ActiveWorkoutView(
                    sheet: sheet,
                    onReturnToWorkoutList: {
                        selectedTab = workoutsTabTag
                    },
                    onHostClose: {
                        hostedActiveSheet = nil
                    },
                    openEarlyEndTick: openEarlyEndTick
                )
                .opacity(workoutStore.isActiveWorkoutMinimized ? 0 : 1)
                .allowsHitTesting(!workoutStore.isActiveWorkoutMinimized)
                .accessibilityHidden(workoutStore.isActiveWorkoutMinimized)
                .zIndex(workoutStore.isActiveWorkoutMinimized ? 0 : 3)
            }

            if let config = hostedCardioConfig {
                ActiveCardioView(
                    config: config,
                    onReturnToWorkoutList: {
                        selectedTab = workoutsTabTag
                    },
                    onHostClose: {
                        hostedCardioConfig = nil
                    },
                    openFinishTick: requestCardioFinishTick
                )
                .opacity(workoutStore.isActiveWorkoutMinimized ? 0 : 1)
                .allowsHitTesting(!workoutStore.isActiveWorkoutMinimized)
                .accessibilityHidden(workoutStore.isActiveWorkoutMinimized)
                .zIndex(workoutStore.isActiveWorkoutMinimized ? 0 : 3)
            }
        }
        .onAppear {
            KeyboardDismiss.hide()
            updateAssistantTabVisibility(for: selectedTab)
            checkInService.refreshAssistantBadge()
            profileReminder.evaluate(for: authService.currentUser)
            syncActiveWorkoutHosting()
            Task { @MainActor in
                // Aguarda o check-in de sono (se houver) ter prioridade antes do pop-up de dados.
                try? await Task.sleep(for: .milliseconds(700))
                presentProfilePromptIfNeeded()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active || phase == .background || phase == .inactive {
                KeyboardDismiss.hide()
            }
        }
        .onChange(of: selectedTab) { _, tab in
            // Libera o teclado do IAssistente para as abas/tab bar responderem no iPhone.
            KeyboardDismiss.hide()
            loadedTabs.insert(tab)
            updateAssistantTabVisibility(for: tab)
        }
        .onChange(of: workoutStore.activeSession?.id) { _, _ in
            syncActiveWorkoutHosting()
        }
        .onChange(of: workoutStore.isActiveWorkoutMinimized) { _, _ in
            syncActiveWorkoutHosting()
        }
        .onChange(of: workoutStore.activeCardioConfig?.title) { _, _ in
            syncActiveWorkoutHosting()
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
        .alert(
            WorkoutStore.activeWorkoutConflictAlertTitle,
            isPresented: $workoutStore.showActiveWorkoutConflictAlert
        ) {
            Button("Encerrar") {
                endActiveWorkoutFromConflictAlert()
            }
            Button("Continuar") {
                resumeMinimizedWorkout()
            }
            Button("Sair", role: .cancel) {}
        } message: {
            Text(workoutStore.activeWorkoutConflictAlertMessage)
        }
        .task(id: selectedTab) {
            guard selectedTab == assistantTabTag else { return }
            while !Task.isCancelled {
                checkInService.refreshAssistantBadge()
                try? await Task.sleep(for: .seconds(45))
            }
        }
    }

    /// Placeholder until the tab is first selected — keeps Profile/Chat/Nutrição off first paint.
    @ViewBuilder
    private func lazyTab<Content: View>(_ tag: Int, @ViewBuilder content: () -> Content) -> some View {
        Group {
            if loadedTabs.contains(tag) {
                content()
            } else {
                AppTheme.background
                    .ignoresSafeArea()
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
            loadedTabs.insert(tab)
            selectedTab = tab
        }
    }

    private func updateAssistantTabVisibility(for tab: Int) {
        checkInService.setAssistantTabActive(tab == assistantTabTag)
    }

    private func resumeMinimizedWorkout() {
        workoutStore.resumeActiveWorkout()
        syncActiveWorkoutHosting()
    }

    private func endMinimizedWorkoutFromBanner() {
        workoutStore.resumeActiveWorkout()
        syncActiveWorkoutHosting()
        requestFinishOnHostedWorkout()
    }

    private func endActiveWorkoutFromConflictAlert() {
        workoutStore.resumeActiveWorkout()
        syncActiveWorkoutHosting()
        // Allow the host to mount before triggering finish (stuck / relaunched cardio).
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            syncActiveWorkoutHosting()
            requestFinishOnHostedWorkout()
        }
    }

    private func requestFinishOnHostedWorkout() {
        if hostedCardioConfig != nil {
            requestCardioFinishTick += 1
        } else if hostedActiveSheet != nil {
            openEarlyEndTick += 1
        } else if let config = workoutStore.resolvedActiveCardioConfig() {
            // Last-resort remount for stuck cardio, then finish.
            hostedCardioConfig = config
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(80))
                requestCardioFinishTick += 1
            }
        }
    }

    private func syncActiveWorkoutHosting() {
        guard workoutStore.activeSession != nil else {
            // Session cleared after finish: keep hosting until the active view closes
            // itself (summary → onHostClose). Do not tear down here.
            return
        }

        if let sheet = workoutStore.activeStrengthSheet() {
            if hostedCardioConfig != nil {
                hostedCardioConfig = nil
            }
            if hostedActiveSheet?.id != sheet.id {
                hostedActiveSheet = sheet
            }
            return
        }

        if let config = workoutStore.resolvedActiveCardioConfig() {
            if hostedActiveSheet != nil {
                hostedActiveSheet = nil
            }
            if hostedCardioConfig != config {
                hostedCardioConfig = config
            }
            return
        }
    }
}
