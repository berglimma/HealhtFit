import SwiftUI

struct ExerciseDemoGifView: View {
    let exercise: Exercise
    var preferredGender: Gender? = nil
    var compact: Bool = false

    @State private var loadState: ExerciseGifLoadState = .loading
    @State private var activeURL: URL?

    private var primaryURL: URL? {
        exercise.demoGifURL(preferredGender: preferredGender)
    }

    private var fallbackURL: URL? {
        ExerciseGifCatalog.bundledGifURL(for: exercise)
    }

    private var frameHeight: CGFloat {
        compact ? 220 : 280
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 8) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(AppTheme.accent)

                Text("Demonstração")
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)

                Spacer()

                if loadState == .loaded {
                    Label("Ao vivo", systemImage: "circle.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                }
            }

            Text(exercise.name)
                .font(compact ? .caption.weight(.medium) : .subheadline.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.09, blue: 0.11), Color(red: 0.12, green: 0.13, blue: 0.16)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                if let activeURL {
                    AnimatedGIFView(
                        url: activeURL,
                        loadState: $loadState,
                        contentMode: .scaleAspectFit,
                        loopsBeforeCompletion: 0
                    )
                    .id("\(exercise.id.uuidString)-\(activeURL.absoluteString)")
                    .opacity(loadState == .loaded ? 1 : 0)
                }

                if loadState == .loading {
                    VStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Carregando demonstração...")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                } else if loadState == .failed {
                    unavailableContent
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: frameHeight)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        }
        .padding(compact ? 12 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            reloadGIF()
        }
        .onChange(of: exercise.id) { _, _ in
            reloadGIF()
        }
        .onChange(of: preferredGender) { _, _ in
            reloadGIF()
        }
        .onChange(of: loadState) { _, newState in
            if newState == .failed,
               let primary = primaryURL,
               let fallback = fallbackURL,
               activeURL == primary {
                activeURL = fallback
                loadState = .loading
            }
        }
    }

    private func reloadGIF() {
        loadState = .loading
        activeURL = primaryURL ?? fallbackURL
    }

    private var unavailableContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo.slash")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.6))
            Text("Demonstração indisponível")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}
