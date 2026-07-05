import SwiftUI

struct MainTabView: View {
    @ObservedObject private var checkInService = PostWorkoutCheckInService.shared
    @ObservedObject private var dailyMorningService = DailyMorningCheckInService.shared
    @ObservedObject private var dailyEveningService = DailyEveningCheckInService.shared
    @State private var selectedTab = 0

    private let assistantTabTag = 3

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
                .tag(2)

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
                .tag(4)
        }
        .tint(AppTheme.accent)
        .tabViewStyle(.automatic)
        .onAppear {
            updateAssistantTabVisibility(for: selectedTab)
            checkInService.refreshAssistantBadge()
        }
        .onChange(of: selectedTab) { _, tab in
            updateAssistantTabVisibility(for: tab)
        }
        .onChange(of: dailyMorningService.state?.phase) { _, _ in
            checkInService.refreshAssistantBadge()
        }
        .onChange(of: dailyEveningService.state?.phase) { _, _ in
            checkInService.refreshAssistantBadge()
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
