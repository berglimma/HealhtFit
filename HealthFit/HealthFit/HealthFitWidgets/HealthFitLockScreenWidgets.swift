import SwiftUI
import WidgetKit

// MARK: - Provider

struct HealthFitLockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> HealthFitLockScreenEntry {
        HealthFitLockScreenEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (HealthFitLockScreenEntry) -> Void) {
        completion(HealthFitLockScreenEntry(date: .now, snapshot: HealthFitWidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HealthFitLockScreenEntry>) -> Void) {
        let entry = HealthFitLockScreenEntry(date: .now, snapshot: HealthFitWidgetSnapshot.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct HealthFitLockScreenEntry: TimelineEntry {
    let date: Date
    let snapshot: HealthFitWidgetSnapshot
}

// MARK: - Lift (rectangular) — left block in the mock

struct HealthFitLiftLockWidget: Widget {
    let kind = "HealthFitLiftLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthFitLockScreenProvider()) { entry in
            HealthFitLiftLockView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Carga recente")
        .description("Maior carga recente na Tela de Bloqueio.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

private struct HealthFitLiftLockView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: HealthFitWidgetSnapshot

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(snapshot.liftPrimaryLabel) · \(snapshot.liftExerciseName)")
        default:
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.liftPrimaryLabel)
                    .font(.title2.weight(.bold))
                    .widgetAccentable()
                Text(snapshot.liftSecondaryLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Progress ring (circular) — center block

struct HealthFitProgressLockWidget: Widget {
    let kind = "HealthFitProgressLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthFitLockScreenProvider()) { entry in
            HealthFitProgressLockView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Treinos da semana")
        .description("Progresso semanal de musculação.")
        .supportedFamilies([.accessoryCircular])
    }
}

private struct HealthFitProgressLockView: View {
    let snapshot: HealthFitWidgetSnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Gauge(value: snapshot.progressFraction) {
                Text("treinos")
            } currentValueLabel: {
                Text(snapshot.progressLabel)
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .minimumScaleFactor(0.7)
            }
            .gaugeStyle(.accessoryCircularCapacity)
        }
    }
}

// MARK: - Calories (circular) — right block

struct HealthFitCaloriesLockWidget: Widget {
    let kind = "HealthFitCaloriesLockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HealthFitLockScreenProvider()) { entry in
            HealthFitCaloriesLockView(snapshot: entry.snapshot)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Calorias de hoje")
        .description("Energia ativa de hoje.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

private struct HealthFitCaloriesLockView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: HealthFitWidgetSnapshot

    var body: some View {
        switch family {
        case .accessoryInline:
            Label("\(snapshot.todayCalories) kcal", systemImage: "flame.fill")
        default:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .widgetAccentable()
                    Text("\(snapshot.todayCalories)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("kcal")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview("Lift", as: .accessoryRectangular) {
    HealthFitLiftLockWidget()
} timeline: {
    HealthFitLockScreenEntry(date: .now, snapshot: .placeholder)
}

#Preview("Progress", as: .accessoryCircular) {
    HealthFitProgressLockWidget()
} timeline: {
    HealthFitLockScreenEntry(date: .now, snapshot: .placeholder)
}

#Preview("Calories", as: .accessoryCircular) {
    HealthFitCaloriesLockWidget()
} timeline: {
    HealthFitLockScreenEntry(date: .now, snapshot: .placeholder)
}
