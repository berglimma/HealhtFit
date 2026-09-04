import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @EnvironmentObject var workoutStore: WorkoutStore
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var checkInService = PostWorkoutCheckInService.shared
    @ObservedObject private var dailyMorningService = DailyMorningCheckInService.shared
    @ObservedObject private var dailyEveningService = DailyEveningCheckInService.shared
    @ObservedObject private var profileReminder = ProfileDataReminderService.shared
    @ObservedObject private var duoNavigation = DuoNavigationRouter.shared
    @ObservedObject private var coachNavigation = CoachNavigationRouter.shared
    @ObservedObject private var coachService = CoachService.shared
    @State private var selectedTab = 0
    /// Only mount heavy tab roots after first visit — TabView otherwise builds all 5 eagerly.
    @State private var loadedTabs: Set<Int> = [0]
    @State private var isShowingProfileDataPrompt = false
    /// Keeps ActiveWorkoutView mounted for the whole strength session (and summary).
    /// Minimize only hides it — never dismiss/re-present a fullScreenCover.
    @State private var hostedActiveSheet: WorkoutSheet?
    /// Same Option A hosting for cardio/bike (keeps GPS map + tracker alive when minimized).
    @State private var hostedCardioConfig: CardioWorkoutConfig?
    /// Meditação ativa (inclui sessão iniciada no Apple Watch).
    @State private var hostedMeditationConfig: MeditationWorkoutConfig?
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
            && !workoutStore.isFullscreenCameraPresented
    }

    private var canEndFromMinimizedBanner: Bool {
        hostedActiveSheet != nil || hostedCardioConfig != nil || hostedMeditationConfig != nil
    }

    private var isHostedWorkoutMinimized: Bool {
        workoutStore.isActiveWorkoutMinimized
    }

    // MARK: - Body (split to help the type-checker)

    var body: some View {
        rootWithAlerts
    }

    private var rootWithAlerts: some View {
        rootWithSessionHandlers
            .alert(
                profileReminder.activePrompt?.title ?? "Seus dados",
                isPresented: $isShowingProfileDataPrompt
            ) {
                profileDataAlertButtons
            } message: {
                Text(profileReminder.activePrompt?.message ?? "")
            }
            .alert(
                WorkoutStore.activeWorkoutConflictAlertTitle,
                isPresented: $workoutStore.showActiveWorkoutConflictAlert
            ) {
                activeWorkoutConflictAlertButtons
            } message: {
                Text(workoutStore.activeWorkoutConflictAlertMessage)
            }
            .task(id: selectedTab) {
                await pollAssistantBadgeWhileVisible()
            }
    }

    private var rootWithSessionHandlers: some View {
        rootWithLifecycle
            .onChange(of: workoutStore.activeSession?.id) { _, _ in
                syncActiveWorkoutHosting()
            }
            .onChange(of: workoutStore.isActiveWorkoutMinimized) { _, _ in
                syncActiveWorkoutHosting()
            }
            .onChange(of: workoutStore.activeCardioConfig?.title) { _, _ in
                syncActiveWorkoutHosting()
            }
            .onChange(of: workoutStore.activeMeditationConfig?.title) { _, _ in
                syncActiveWorkoutHosting()
            }
            .onChange(of: watchConnectivity.watchForcedSessionCloseTick) { _, _ in
                clearHostedWorkoutOverlays()
            }
            .onChange(of: authService.currentUser?.id) { _, _ in
                profileReminder.evaluate(for: authService.currentUser)
                presentProfilePromptIfNeeded()
            }
    }

    private var rootWithLifecycle: some View {
        mainStack
            .onAppear(perform: handleAppear)
            .onChange(of: scenePhase) { _, phase in
                handleScenePhase(phase)
            }
            .onChange(of: selectedTab) { _, tab in
                handleSelectedTabChange(tab)
            }
            .onChange(of: duoNavigation.focusWorkoutsTabTick) { _, _ in
                loadedTabs.insert(workoutsTabTag)
                selectedTab = workoutsTabTag
            }
            .onChange(of: coachNavigation.focusProfileTabTick) { _, _ in
                loadedTabs.insert(profileTabTag)
                selectedTab = profileTabTag
            }
            .sheet(item: $duoNavigation.presentedChat) { destination in
                NavigationStack {
                    DuoTeamChatView(teamId: destination.teamId, teamName: destination.teamName)
                        .environmentObject(authService)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Fechar") {
                                    duoNavigation.dismissChat()
                                }
                            }
                        }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $coachNavigation.presentedChat) { destination in
                NavigationStack {
                    Group {
                        if let link = coachService.myLinks.first(where: { $0.id == destination.linkId }) {
                            CoachChatView(link: link)
                        } else {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Abrindo chat Coach…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .onAppear {
                                CoachService.shared.start()
                                CoachService.shared.ensureChatListening(linkId: destination.linkId)
                            }
                        }
                    }
                    .environmentObject(authService)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fechar") {
                                coachNavigation.dismissChat()
                            }
                        }
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: wellnessService.showSleepCheckIn) { _, isShowingSleep in
                handleSleepCheckInChange(isShowingSleep)
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
    }

    /// ZStack: tabs + banner minimizado + overlays de treino ativo.
    private var mainStack: some View {
        ZStack(alignment: .bottom) {
            mainTabView
            minimizedWorkoutBanner
            hostedActiveStrengthOverlay
            hostedActiveCardioOverlay
            hostedActiveMeditationOverlay
        }
    }

    // MARK: - Tab bar

    private var mainTabView: some View {
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
    }

    // MARK: - Overlays

    @ViewBuilder
    private var minimizedWorkoutBanner: some View {
        if showsMinimizedWorkoutBanner, let session = workoutStore.activeSession {
            minimizedBannerContent(session: session)
        }
    }

    private func minimizedBannerContent(session: WorkoutSession) -> some View {
        VStack(spacing: 0) {
            ActiveWorkoutBanner(
                session: session,
                currentExerciseName: workoutStore.currentExercise?.name,
                onResume: { resumeMinimizedWorkout() },
                onEnd: canEndFromMinimizedBanner ? { endMinimizedWorkoutFromBanner() } : nil
            )
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 8)

            Color.clear
                .frame(height: DeviceLayout.mainTabBarContentHeight)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .bottom)
        .ignoresSafeArea(.keyboard)
        .zIndex(2)
    }

    @ViewBuilder
    private var hostedActiveStrengthOverlay: some View {
        if let sheet = hostedActiveSheet {
            ActiveWorkoutView(
                sheet: sheet,
                onReturnToWorkoutList: { selectedTab = workoutsTabTag },
                onHostClose: { hostedActiveSheet = nil },
                openEarlyEndTick: openEarlyEndTick
            )
            .modifier(HostedActiveWorkoutChrome(isMinimized: isHostedWorkoutMinimized))
        }
    }

    @ViewBuilder
    private var hostedActiveCardioOverlay: some View {
        if let config = hostedCardioConfig {
            ActiveCardioView(
                config: config,
                onReturnToWorkoutList: { selectedTab = workoutsTabTag },
                onHostClose: { hostedCardioConfig = nil },
                openFinishTick: requestCardioFinishTick
            )
            .modifier(HostedActiveWorkoutChrome(isMinimized: isHostedWorkoutMinimized))
        }
    }

    @ViewBuilder
    private var hostedActiveMeditationOverlay: some View {
        if let meditation = hostedMeditationConfig {
            ActiveMeditationView(
                config: meditation,
                onReturnToWorkoutList: { selectedTab = workoutsTabTag },
                onHostClose: { hostedMeditationConfig = nil }
            )
            .modifier(HostedActiveWorkoutChrome(isMinimized: isHostedWorkoutMinimized))
        }
    }

    // MARK: - Alerts

    @ViewBuilder
    private var profileDataAlertButtons: some View {
        Button("Ir para Perfil") {
            handlePromptChoice(navigateTo: profileTabTag)
        }
        Button("Ir para Nutrição") {
            handlePromptChoice(navigateTo: nutritionTabTag)
        }
        Button("Agora não", role: .cancel) {
            handlePromptChoice(navigateTo: nil)
        }
    }

    @ViewBuilder
    private var activeWorkoutConflictAlertButtons: some View {
        Button("Encerrar") {
            endActiveWorkoutFromConflictAlert()
        }
        Button("Continuar") {
            resumeMinimizedWorkout()
        }
        Button("Sair", role: .cancel) {}
    }

    // MARK: - Lifecycle handlers

    private func handleAppear() {
        KeyboardDismiss.hide()
        updateAssistantTabVisibility(for: selectedTab)
        checkInService.refreshAssistantBadge()
        profileReminder.evaluate(for: authService.currentUser)
        syncActiveWorkoutHosting()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            presentProfilePromptIfNeeded()
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        // Só fecha teclado ao ir para background. Em `.inactive`/`.active` (ficha, Control Center,
        // animação de teclado) o endEditing global impede digitar em TextField (ex.: medidas).
        if phase == .background {
            KeyboardDismiss.hide()
        }
        if phase == .active {
            ClimbingGearService.shared.notifyInspectionIfNeeded()
        }
    }

    private func handleSelectedTabChange(_ tab: Int) {
        KeyboardDismiss.hide()
        loadedTabs.insert(tab)
        updateAssistantTabVisibility(for: tab)
    }

    private func handleSleepCheckInChange(_ isShowingSleep: Bool) {
        if isShowingSleep {
            isShowingProfileDataPrompt = false
        } else {
            presentProfilePromptIfNeeded()
        }
    }

    private func clearHostedWorkoutOverlays() {
        hostedActiveSheet = nil
        hostedCardioConfig = nil
        hostedMeditationConfig = nil
    }

    private func pollAssistantBadgeWhileVisible() async {
        guard selectedTab == assistantTabTag else { return }
        while !Task.isCancelled {
            if scenePhase == .active {
                checkInService.refreshAssistantBadge()
            }
            try? await Task.sleep(for: .seconds(60))
        }
    }

    // MARK: - Lazy tabs

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

    // MARK: - Profile prompt

    private func presentProfilePromptIfNeeded() {
        guard profileReminder.activePrompt != nil else {
            isShowingProfileDataPrompt = false
            return
        }
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

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            loadedTabs.insert(tab)
            selectedTab = tab
        }
    }

    private func updateAssistantTabVisibility(for tab: Int) {
        checkInService.setAssistantTabActive(tab == assistantTabTag)
    }

    // MARK: - Active workout host

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
            if hostedCardioConfig != nil { hostedCardioConfig = nil }
            if hostedMeditationConfig != nil { hostedMeditationConfig = nil }
            if hostedActiveSheet?.id != sheet.id {
                hostedActiveSheet = sheet
            }
            return
        }

        if let config = workoutStore.resolvedActiveCardioConfig() {
            if hostedActiveSheet != nil { hostedActiveSheet = nil }
            if hostedMeditationConfig != nil { hostedMeditationConfig = nil }
            if hostedCardioConfig != config {
                hostedCardioConfig = config
            }
            return
        }

        if let meditation = workoutStore.activeMeditationConfig,
           let session = workoutStore.activeSession,
           WeeklyProgressAnalyzer.isMeditationSession(session) {
            if hostedActiveSheet != nil { hostedActiveSheet = nil }
            if hostedCardioConfig != nil { hostedCardioConfig = nil }
            if hostedMeditationConfig != meditation {
                hostedMeditationConfig = meditation
            }
        }
    }
}

// MARK: - Hosted workout chrome

/// Shared opacity / hit-testing for strength, cardio and meditation overlays.
private struct HostedActiveWorkoutChrome: ViewModifier {
    let isMinimized: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isMinimized ? 0 : 1)
            .allowsHitTesting(!isMinimized)
            .accessibilityHidden(isMinimized)
            .zIndex(isMinimized ? 0 : 3)
    }
}
