import SwiftUI

struct WelcomeMotivationView: View {
    let context: WelcomeMotivationContext
    let onComplete: () -> Void

    @State private var slideIndex = 0
    @State private var contentOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.88
    @State private var progress: Double = 0
    @State private var didComplete = false

    private let displayDuration: TimeInterval = 5
    private var slideInterval: TimeInterval { displayDuration / Double(max(context.slides.count, 1)) }

    private var glowColor: Color {
        switch context.glowColorName {
        case .accent: AppTheme.accent
        case .yellow: .yellow
        case .orange: AppTheme.accentSecondary
        case .red: .red
        }
    }

    private var currentSlide: WelcomeMotivationSlide {
        context.slides[slideIndex]
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            RadialGradient(
                colors: [glowColor.opacity(0.18), AppTheme.background],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 48)

                animationStage
                    .padding(.bottom, 32)

                messageSection
                    .padding(.bottom, 24)

                Spacer(minLength: 24)

                footerSection
                    .padding(.bottom, 36)
            }
            .padding(.horizontal, 28)
            .opacity(contentOpacity)
        }
        .onAppear { startAnimations() }
    }

    private var animationStage: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(glowColor.opacity(0.16))
                    .frame(width: 128, height: 128)

                Circle()
                    .stroke(glowColor.opacity(0.4), lineWidth: 2)
                    .frame(width: 128, height: 128)

                Image(systemName: currentSlide.icon)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(glowColor)
                    .modifier(RepeatingBounceSymbolEffect(speed: 0.55))
            }
            .frame(width: 128, height: 128)
            .scaleEffect(iconScale)
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: slideIndex)

            Text(currentSlide.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(height: 22)
                .animation(.easeInOut(duration: 0.25), value: slideIndex)

            slideIndicators
        }
    }

    private var slideIndicators: some View {
        HStack(spacing: 8) {
            ForEach(context.slides.indices, id: \.self) { index in
                Capsule()
                    .fill(index == slideIndex ? glowColor : AppTheme.textSecondary.opacity(0.35))
                    .frame(width: index == slideIndex ? 18 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: slideIndex)
            }
        }
        .padding(.top, 4)
    }

    private var messageSection: some View {
        VStack(spacing: 14) {
            Text(context.headline)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(context.message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(context.submessage)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(glowColor.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footerSection: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
                .tint(glowColor)
                .padding(.horizontal, 12)

            Text("Carregando...")
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.55)) {
            contentOpacity = 1
            iconScale = 1
        }

        withAnimation(.easeInOut(duration: displayDuration)) {
            progress = 1
        }

        Task {
            while !didComplete {
                try? await Task.sleep(for: .seconds(slideInterval))
                guard !didComplete else { break }
                await MainActor.run {
                    slideIndex = (slideIndex + 1) % context.slides.count
                }
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(displayDuration))
            await MainActor.run { finish() }
        }
    }

    private func finish() {
        guard !didComplete else { return }
        didComplete = true
        withAnimation(.easeInOut(duration: 0.25)) {
            contentOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onComplete()
        }
    }
}

#Preview("Ativo") {
    WelcomeMotivationView(
        context: WelcomeMotivationEngine.makeContext(
            athleteName: "João Silva",
            hoursSinceLastOpen: 6,
            hoursSinceLastWorkout: 12,
            weeklyWorkoutCount: 3
        ),
        onComplete: {}
    )
}

#Preview("Sentiu falta") {
    WelcomeMotivationView(
        context: WelcomeMotivationEngine.makeContext(
            athleteName: "Maria",
            hoursSinceLastOpen: 72,
            hoursSinceLastWorkout: 96,
            weeklyWorkoutCount: 0
        ),
        onComplete: {}
    )
}
