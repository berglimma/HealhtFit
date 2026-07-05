import SwiftUI

struct ExerciseDemoGifView: View {
    let exercise: Exercise
    var compact: Bool = false

    private var gifURL: URL? {
        exercise.demoGifURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            Label("GIF Demonstrativo", systemImage: "photo.on.rectangle.angled")
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            Text(exercise.name)
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            if let gifURL {
                AnimatedGIFView(url: gifURL)
                    .frame(maxWidth: .infinity)
                    .frame(height: compact ? 180 : 220)
                    .background(AppTheme.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                unavailableView
            }
        }
        .padding(compact ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var unavailableView: some View {
        ZStack {
            AppTheme.accent.opacity(0.12)
            VStack(spacing: 8) {
                Image(systemName: "photo.slash")
                    .font(.title2)
                    .foregroundStyle(AppTheme.textSecondary)
                Text("GIF indisponível")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 180 : 220)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
