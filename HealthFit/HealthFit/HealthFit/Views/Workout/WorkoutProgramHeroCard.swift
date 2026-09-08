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
    /// Plano mínimo quando a modalidade está bloqueada — desenha o cadeado no card.
    var lockedByPlan: PlanTier? = nil

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
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            if let lockedByPlan {
                PlanRequirementBadge(tier: lockedByPlan, compact: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .saturation(lockedByPlan == nil ? 1 : 0.35)
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

/// Estilo visual das fichas nos hubs masculino/feminino.
enum MusculacaoSheetCardStyle {
    case shape
    case shapeLevel1
    case shapeLevel2
    case recommended
    case standard

    private static let shapeLevel1Blue = Color(red: 0.45, green: 0.72, blue: 0.98)
    private static let shapeLevel2Orange = AppTheme.accentSecondary

    var badgeTitle: String? {
        switch self {
        case .shape: return "Foco no Shape"
        case .shapeLevel1: return "Shape · Nível 1"
        case .shapeLevel2: return "Shape · Nível 2"
        case .recommended: return "Recomendado"
        case .standard: return nil
        }
    }

    var badgeIcon: String {
        switch self {
        case .shape, .shapeLevel1, .shapeLevel2: return "flame.fill"
        case .recommended: return "star.fill"
        case .standard: return "dumbbell.fill"
        }
    }

    func accent(for sheetTitle: String, gender: Gender, highlighted: Bool) -> Color {
        switch self {
        case .shape:
            return sheetTitle.contains("Nível 2")
                ? Self.shapeLevel2Orange
                : Self.shapeLevel1Blue
        case .shapeLevel1:
            return Self.shapeLevel1Blue
        case .shapeLevel2:
            return Self.shapeLevel2Orange
        case .recommended:
            return gender == .female
                ? Color(red: 0.86, green: 0.45, blue: 0.58)
                : AppTheme.accent
        case .standard:
            return highlighted ? AppTheme.accent : AppTheme.accent.opacity(0.85)
        }
    }
}

/// Card fotográfico compacto — séries por nível, foco do treino, Shape e recomendados.
struct MusculacaoPhotoCategoryCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let gender: Gender
    var count: Int = 0
    var eyebrow: String? = nil
    var height: CGFloat = 128

    private var imageName: String {
        gender == .female ? "WorkoutProgramFemale" : "WorkoutProgramMale"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: height)
                .clipped()

            LinearGradient(
                colors: [
                    accent.opacity(0.15),
                    .black.opacity(0.55),
                    .black.opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accent.opacity(0.28))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let eyebrow {
                        Text(eyebrow)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(accent)
                    }

                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)

                    if count > 0 {
                        Label("\(count) ficha\(count == 1 ? "" : "s")", systemImage: "list.bullet.rectangle.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.bottom, 2)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background(accent.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .strokeBorder(accent.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .compositingGroup()
    }
}

/// Card fotográfico de ficha (Shape / Recomendados) nos hubs M/F.
struct MusculacaoPhotoSheetCard: View {
    let sheet: WorkoutSheet
    let gender: Gender
    var style: MusculacaoSheetCardStyle = .standard
    var highlighted: Bool = false
    var displayTitle: String? = nil

    private var imageName: String {
        gender == .female ? "WorkoutProgramFemale" : "WorkoutProgramMale"
    }

    private var accent: Color {
        style.accent(for: sheet.title, gender: gender, highlighted: highlighted)
    }

    private var badgeTitle: String? {
        switch style {
        case .shape:
            return sheet.title.contains("Nível 2") ? "Shape · Nível 2" : "Shape · Nível 1"
        default:
            return style.badgeTitle
        }
    }

    private var shortTitle: String {
        if let displayTitle, !displayTitle.isEmpty { return displayTitle }
        var title = sheet.title
        for prefix in [
            "Shape Feminino ", "Shape Masculino ",
            "Feminino ", "Masculino ",
            "Guiado — ", "Guiado - "
        ] {
            if title.hasPrefix(prefix) {
                title = String(title.dropFirst(prefix.count))
                break
            }
        }
        return title
    }

    /// Desloca o crop da foto para cada ficha não parecer idêntica.
    private var coverOffset: CGFloat {
        let values = sheet.title.unicodeScalars.map { Int($0.value) }
        let sum = values.reduce(0, +)
        return CGFloat(sum % 48) - 24
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: 118)
                .offset(y: coverOffset)
                .clipped()

            LinearGradient(
                colors: [
                    accent.opacity(0.22),
                    .black.opacity(0.35),
                    .black.opacity(0.86)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if let badge = badgeTitle {
                        Label(badge, systemImage: style.badgeIcon)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.9))
                            .clipShape(Capsule())
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Text(shortTitle)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.88)

                HStack(spacing: 10) {
                    Label("\(sheet.totalExercises) exercícios", systemImage: "list.bullet")
                    Label("~\(max(sheet.estimatedDuration / 60, 1)) min", systemImage: "clock")
                    Label("\(sheet.exercises.reduce(0) { $0 + $1.sets }) séries", systemImage: "repeat")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 118)
        .background(accent.opacity(0.22))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .strokeBorder(accent.opacity(highlighted ? 0.7 : 0.4), lineWidth: highlighted ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
        .compositingGroup()
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
