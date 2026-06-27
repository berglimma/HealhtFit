import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

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

            ProfileView()
                .tabItem {
                    Label("Perfil", systemImage: "person.fill")
                }
                .tag(3)
        }
        .tint(AppTheme.accent)
        .tabViewStyle(.automatic)
    }
}
