import SwiftUI

/// Hero card compartilhado — mesmo layout dos programas de musculação
/// (altura 180, imagem full-bleed, gradiente e texto em baixo à esquerda).
struct WorkoutProgramHeroCard: View {
    let title: String
    let subtitle: String
    let accent: Color
    /// Asset em Assets.xcassets (ex.: `WorkoutProgramMale`, `CardioCoverCorrida`).
    var imageName: String? = nil
    var systemImage: String = "figure.run"
    var coverColors: [Color] = [AppTheme.accent, AppTheme.accent.opacity(0.7)]
    var eyebrow: String? = nil
    var eyebrowSystemImage: String? = nil
    /// Linha extra abaixo do subtítulo (ex.: contagens do programa).
    var footerLabels: [(icon: String, text: String)] = []

    private var resolvedAccent: Color {
        coverColors.first ?? accent
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            coverLayer
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.05), .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                if let eyebrow {
                    if let eyebrowSystemImage {
                        Label(eyebrow, systemImage: eyebrowSystemImage)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(resolvedAccent)
                    } else {
                        Text(eyebrow)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(resolvedAccent)
                    }
                }

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !footerLabels.isEmpty {
                    HStack(spacing: 10) {
                        ForEach(Array(footerLabels.enumerated()), id: \.offset) { _, item in
                            Label(item.text, systemImage: item.icon)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(resolvedAccent.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(resolvedAccent.opacity(0.45), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        // Flatten compositing cost of stacked gradients + photo covers in long lists.
        .compositingGroup()
    }

    @ViewBuilder
    private var coverLayer: some View {
        if let imageName {
            Image(imageName)
                .resizable()
                .scaledToFill()
                // Hint decoder toward list card size (~2x for @3x max).
                .frame(maxWidth: .infinity, maxHeight: 180)
        } else {
            ModalityCoverArt(
                systemImage: systemImage,
                colors: coverColors,
                symbolSize: 56
            )
        }
    }
}

/// Capa de modalidade: asset fotográfico quando existir; senão gradiente + símbolo.
struct ModalityCoverArt: View {
    let systemImage: String
    let colors: [Color]
    var imageName: String? = nil
    var symbolSize: CGFloat = 42

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let iconSize = min(symbolSize, max(22, size * 0.42))

            ZStack {
                if let imageName {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    RadialGradient(
                        colors: [.white.opacity(0.22), .clear],
                        center: .topTrailing,
                        startRadius: 4,
                        endRadius: max(size * 0.9, 40)
                    )

                    Image(systemName: systemImage)
                        .font(.system(size: iconSize, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                        .offset(y: size > 80 ? -6 : 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
