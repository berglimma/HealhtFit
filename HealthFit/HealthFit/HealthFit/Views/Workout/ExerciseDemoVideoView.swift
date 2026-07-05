import SwiftUI

struct ExerciseDemoGifView: View {
    let exercise: Exercise
    var compact: Bool = false

    @State private var loadState: ExerciseGifLoadState = .loading

    private var gifURL: URL? {
        exercise.demoGifURL
    }

    private var frameHeight: CGFloat {
        compact ? 180 : 220
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            Label("GIF Demonstrativo", systemImage: "photo.on.rectangle.angled")
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)

            Text(exercise.name)
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(AppTheme.textSecondary)

            ZStack {
                AppTheme.accent.opacity(0.08)

                if let gifURL {
                    AnimatedGIFView(url: gifURL, loadState: $loadState)
                        .id(gifURL)
                        .opacity(loadState == .loaded ? 1 : 0)

                    if loadState == .loading {
                        ProgressView("Carregando GIF...")
                            .tint(AppTheme.accent)
                    } else if loadState == .failed {
                        unavailableContent
                    }
                } else {
                    unavailableContent
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: frameHeight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(compact ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var unavailableContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.slash")
                .font(.title2)
                .foregroundStyle(AppTheme.textSecondary)
            Text("GIF indisponível")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}
