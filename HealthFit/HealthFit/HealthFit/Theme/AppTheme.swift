import SwiftUI
import Foundation

enum AppTheme {
    static let accent = Color("AccentGreen")
    static let accentSecondary = Color("AccentOrange")
    static let background = Color("Background")
    static let cardBackground = Color("CardBackground")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.65)

    static let gradientPrimary = LinearGradient(
        colors: [Color("AccentGreen"), Color("AccentOrange")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let gradientCard = LinearGradient(
        colors: [Color("CardBackground"), Color("CardBackground").opacity(0.8)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cornerRadius: CGFloat = 16
    static let padding: CGFloat = 20
}

enum AppInfo {
    static let developerName = "BERG LIMMA"
    static let developerCredit = "Código desenvolvido por BERG LIMMA"
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isEnabled
                    ? AnyShapeStyle(AppTheme.gradientPrimary)
                    : AnyShapeStyle(Color.gray.opacity(0.4))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(
                color: isEnabled ? AppTheme.accent.opacity(0.45) : .clear,
                radius: 12, x: 0, y: 6
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.6)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct DeveloperCreditView: View {
    var body: some View {
        Text(AppInfo.developerCredit)
            .font(.caption2)
            .foregroundStyle(AppTheme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

struct MetricBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
