import SwiftUI
import UIKit

/// Dashboard entry for HealthFit Pulse (gated by Labs ou `appConfig/ios.pulseEnabled`).
struct PulseDashboardCard: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var shareCardStore: WorkoutShareCardStore
    @EnvironmentObject private var mealPlanService: MealPlanService
    @EnvironmentObject private var wellnessService: DailyWellnessService
    @State private var showTerms = false
    @State private var showFeed = false

    private var userId: String { authService.currentUser?.id ?? "" }

    var body: some View {
        Button {
            if PulseExperimental.hasAcceptedTerms(userId: userId) {
                showFeed = true
            } else {
                showTerms = true
            }
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showTerms) {
            PulseTermsView(
                onAccept: {
                    PulseExperimental.acceptTerms(userId: userId)
                    showTerms = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showFeed = true
                    }
                },
                onCancel: { showTerms = false }
            )
            .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showFeed) {
            PulseFeedView()
                .environmentObject(authService)
                .environmentObject(workoutStore)
                .environmentObject(shareCardStore)
                .environmentObject(mealPlanService)
                .environmentObject(wellnessService)
        }
    }

    private var cardContent: some View {
        ZStack(alignment: .bottomLeading) {
            sportCollage
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Label("Comunidade", systemImage: "heart.circle.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.accent)

                Text(PulseExperimental.featureName)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text(PulseExperimental.tagline)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Label("Stories", systemImage: "circle.dashed")
                    Label("Comunidades", systemImage: "person.3.fill")
                    Label("Ranking leve", systemImage: "chart.bar.fill")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .shadow(color: AppTheme.accent.opacity(0.35), radius: 12, y: 6)
    }

    private var sportCollage: some View {
        let assets = PulseExperimental.sportCoverAssets
        return GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                collageTile(assets[safe: 0], x: 0, y: 0, width: w * 0.55, height: h)
                collageTile(assets[safe: 1], x: w * 0.55, y: 0, width: w * 0.45, height: h * 0.5)
                collageTile(assets[safe: 2], x: w * 0.55, y: h * 0.5, width: w * 0.225, height: h * 0.5)
                collageTile(assets[safe: 3], x: w * 0.775, y: h * 0.5, width: w * 0.225, height: h * 0.5)
            }
        }
    }

    private func collageTile(_ name: String?, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        Group {
            if let name, UIImage(named: name) != nil {
                Image(name)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [AppTheme.accent.opacity(0.7), AppTheme.accentSecondary.opacity(0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "figure.run")
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .position(x: x + width / 2, y: y + height / 2)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
