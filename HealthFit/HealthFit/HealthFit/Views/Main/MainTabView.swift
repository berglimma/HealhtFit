import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var wellnessService: DailyWellnessService
    @ObservedObject private var checkInService = PostWorkoutCheckInService.shared
    @ObservedObject private var dailyMorningService = DailyMorningCheckInService.shared
    @ObservedObject private var dailyEveningService = DailyEveningCheckInService.shared
    @ObservedObject private var profileReminder = ProfileDataReminderService.shared
    @State private var selectedTab = 0
    @State private var isShowingProfileDataPrompt = false

    private let assistantTabTag = 3
    private let nutritionTabTag = 2
    private let profileTabTag = 4

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Início", systemImage: "house.fill")
                }
                .tag(0)

            WorkoutListView()
                .tabItem {
                    Label("Treinos", systemImage: "dumbbell.fill")
                }
                .tag(1)

            MealPlanView()
                .tabItem {
                    Label("Nutrição", systemImage: "fork.knife")
                }
                .tag(nutritionTabTag)

            HealthChatView()
                .tabItem {
                    Label("IAssistente", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(assistantTabTag)
                .badge(checkInService.assistantTabBadgeCount)

            ProfileView()
                .tabItem {
                    Label("Perfil", systemImage: "person.fill")
                }
                .tag(profileTabTag)
        }
        .tint(AppTheme.accent)
        .tabViewStyle(.automatic)
        .onAppear {
            updateAssistantTabVisibility(for: selectedTab)
            checkInService.refreshAssistantBadge()
            profileReminder.evaluate(for: authService.currentUser)
            Task { @MainActor in
                // Aguarda o check-in de sono (se houver) ter prioridade antes do pop-up de dados.
                try? await Task.sleep(for: .milliseconds(700))
                presentProfilePromptIfNeeded()
            }
        }
        .onChange(of: selectedTab) { _, tab in
            updateAssistantTabVisibility(for: tab)
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
}
