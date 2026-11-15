import SwiftUI
import WidgetKit

// MARK: - Timeline

struct HealthFitHomeEntry: TimelineEntry {
    let date: Date
    let snapshot: HealthFitWidgetSnapshot
}

struct HealthFitHomeProvider: TimelineProvider {
    func placeholder(in context: Context) -> HealthFitHomeEntry {
        HealthFitHomeEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthFitHomeEntry) -> Void) {
        completion(HealthFitHomeEntry(date: Date(), snapshot: HealthFitWidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthFitHomeEntry>) -> Void) {
        let entry = HealthFitHomeEntry(date: Date(), snapshot: HealthFitWidgetSnapshot.load())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
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
        .description("Carga, treinos da semana e calorias na Tela de Início.")
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

    private var snapshot: HealthFitWidgetSnapshot { entry.snapshot }
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
            Text(snapshot.liftPrimaryLabel)
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
            Text(snapshot.liftSecondaryLabel)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(2)
            Text("\(snapshot.progressLabel) treinos · \(snapshot.todayCalories) kcal")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
        }
        .padding(4)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            brandHeader
            HStack(alignment: .top, spacing: 12) {
                metricBlock(
                    value: snapshot.liftPrimaryLabel,
                    label: snapshot.liftSecondaryLabel,
                    accent: .white
                )
                metricBlock(
                    value: snapshot.progressLabel,
                    label: "treinos",
                    accent: accent
                )
                metricBlock(
                    value: "\(snapshot.todayCalories)",
                    label: "kcal",
                    accent: Color.orange
                )
            }
            Text(snapshot.workoutOfDayTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            Text(snapshot.workoutOfDaySubtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)
        }
        .padding(4)
    }

    private func largeLayout(columns: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            brandHeader
            Text(snapshot.workoutOfDayTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(snapshot.workoutOfDaySubtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(3)

            HStack(spacing: 12) {
                detailCard(
                    icon: "dumbbell.fill",
                    title: "Carga",
                    value: snapshot.liftPrimaryLabel,
                    tint: .white
                )
                detailCard(
                    icon: "checkmark.circle.fill",
                    title: "Semana",
                    value: "\(snapshot.progressLabel) treinos",
                    tint: accent
                )
                if columns > 2 {
                    detailCard(
                        icon: "flame.fill",
                        title: "Hoje",
                        value: "\(snapshot.todayCalories) kcal",
                        tint: .orange
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

    private func metricBlock(value: String, label: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .lineLimit(2)
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
    HealthFitHomeEntry(date: .now, snapshot: .placeholder)
}

#Preview("Medium", as: .systemMedium) {
    HealthFitHomeWidget()
} timeline: {
    HealthFitHomeEntry(date: .now, snapshot: .placeholder)
}
