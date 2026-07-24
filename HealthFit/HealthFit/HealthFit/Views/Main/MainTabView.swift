import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @ObservedObject private var checkInService = PostWorkoutCheckInService.shared
    @ObservedObject private var dailyMorningService = DailyMorningCheckInService.shared
    @ObservedObject private var dailyEveningService = DailyEveningCheckInService.shared
    @ObservedObject private var profileReminder = ProfileDataReminderService.shared
    @State private var selectedTab = 0

    private let assistantTabTag = 3
    private let nutritionTabTag = 2
    private let profileTabTag = 4

    private var showProfileDataPrompt: Binding<Bool> {
        Binding(
            get: { profileReminder.activePrompt != nil },
            set: { isPresented in
                if !isPresented {
                    profileReminder.dismissPrompt(for: authService.currentUser?.id)
                }
            }
        )
    }

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
        }
        .onChange(of: selectedTab) { _, tab in
            updateAssistantTabVisibility(for: tab)
        }
        .onChange(of: authService.currentUser?.id) { _, _ in
            profileReminder.evaluate(for: authService.currentUser)
        }
        .onChange(of: dailyMorningService.state?.phase) { _, _ in
            checkInService.refreshAssistantBadge()
        }
        .onChange(of: dailyEveningService.state?.phase) { _, _ in
            checkInService.refreshAssistantBadge()
        }
        .alert(
            profileReminder.activePrompt?.title ?? "Seus dados",
            isPresented: showProfileDataPrompt
        ) {
            Button("Ir para Perfil") {
                profileReminder.dismissPrompt(for: authService.currentUser?.id)
                selectedTab = profileTabTag
            }
            Button("Ir para Nutrição") {
                profileReminder.dismissPrompt(for: authService.currentUser?.id)
                selectedTab = nutritionTabTag
            }
            Button("Agora não", role: .cancel) {
                profileReminder.dismissPrompt(for: authService.currentUser?.id)
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

    private func updateAssistantTabVisibility(for tab: Int) {
        checkInService.setAssistantTabActive(tab == assistantTabTag)
    }
}
