import SwiftUI
import WidgetKit

// MARK: - Timeline

struct HealthFitHomeEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let streakDays: Int
    let workoutsThisWeek: Int
}

struct HealthFitHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> HealthFitHomeEntry {
        sampleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthFitHomeEntry) -> Void) {
        completion(sampleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthFitHomeEntry>) -> Void) {
        let entry = sampleEntry(date: Date())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func sampleEntry(date: Date) -> HealthFitHomeEntry {
        let hour = Calendar.current.component(.hour, from: date)
        let (title, subtitle): (String, String) = {
            switch hour {
            case 5..<12:
                return ("Bom treino", "Comece o dia com energia")
            case 12..<18:
                return ("Mantém o ritmo", "Seu plano de hoje te espera")
            default:
                return ("Fecha o dia bem", "Uma sessão curta ainda conta")
            }
        }()
        return HealthFitHomeEntry(
            date: date,
            title: title,
            subtitle: subtitle,
            streakDays: 3,
            workoutsThisWeek: 4
        )
    }
}

// MARK: - Widget

struct HealthFitHomeWidget: Widget {
    let kind = "HealthFitHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthFitHomeProvider()) { entry in
            HealthFitHomeWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.12, blue: 0.10),
                            Color(red: 0.04, green: 0.08, blue: 0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("HealthFit")
        .description("Resumo rápido do seu treino na Tela de Início.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .systemExtraLarge
        ])
    }
}

// MARK: - Views

private struct HealthFitHomeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HealthFitHomeEntry

    private let accent = Color(red: 0.30, green: 0.85, blue: 0.45)

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        case .systemMedium:
            mediumLayout
        case .systemLarge:
            largeLayout(columns: 2)
        case .systemExtraLarge:
            largeLayout(columns: 3)
        default:
            mediumLayout
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .foregroundStyle(accent)
            Text("HealthFit")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            brandHeader
            Spacer(minLength: 0)
            Text(entry.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text("\(entry.workoutsThisWeek) treinos · semana")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
        .padding(4)
    }

    private var mediumLayout: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                brandHeader
                Text(entry.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(entry.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 10) {
                statChip(value: "\(entry.streakDays)", label: "dias")
                statChip(value: "\(entry.workoutsThisWeek)", label: "semana")
            }
        }
        .padding(4)
    }

    private func largeLayout(columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            brandHeader
            Text(entry.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text(entry.subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))

            HStack(spacing: 12) {
                detailCard(
                    icon: "flame.fill",
                    title: "Sequência",
                    value: "\(entry.streakDays) dias",
                    tint: Color.orange
                )
                detailCard(
                    icon: "figure.strengthtraining.traditional",
                    title: "Esta semana",
                    value: "\(entry.workoutsThisWeek) treinos",
                    tint: accent
                )
                if columns > 2 {
                    detailCard(
                        icon: "sparkles",
                        title: "Foco",
                        value: "Consistência",
                        tint: Color.cyan
                    )
                }
            }

            Spacer(minLength: 0)

            Text("Toque para abrir o HealthFit")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(6)
    }

    private func statChip(value: String, label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value)
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(accent)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private func detailCard(icon: String, title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview("Small", as: .systemSmall) {
    HealthFitHomeWidget()
} timeline: {
    HealthFitHomeEntry(
        date: .now,
        title: "Bom treino",
        subtitle: "Comece o dia com energia",
        streakDays: 3,
        workoutsThisWeek: 4
    )
}

#Preview("Medium", as: .systemMedium) {
    HealthFitHomeWidget()
} timeline: {
    HealthFitHomeEntry(
        date: .now,
        title: "Bom treino",
        subtitle: "Comece o dia com energia",
        streakDays: 3,
        workoutsThisWeek: 4
    )
}

#Preview("Large", as: .systemLarge) {
    HealthFitHomeWidget()
} timeline: {
    HealthFitHomeEntry(
        date: .now,
        title: "Bom treino",
        subtitle: "Comece o dia com energia",
        streakDays: 3,
        workoutsThisWeek: 4
    )
}

#Preview("Extra Large", as: .systemExtraLarge) {
    HealthFitHomeWidget()
} timeline: {
    HealthFitHomeEntry(
        date: .now,
        title: "Bom treino",
        subtitle: "Comece o dia com energia",
        streakDays: 3,
        workoutsThisWeek: 4
    )
}
