import ActivityKit
import SwiftUI
import WidgetKit

@main
struct HealthFitWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivityWidget()
    }
}

struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutLiveActivityAttributes.self) { context in
            LockScreenWorkoutLiveActivityView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("HealthFit", systemImage: "heart.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    phaseBadge(context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        timerView(for: context.state)
                            .font(.title2.monospacedDigit().weight(.bold))
                        Spacer()
                        Text(context.state.setsLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.phase == .rest ? "pause.circle.fill" : "figure.strengthtraining.traditional")
                    .foregroundStyle(context.state.phase == .rest ? .orange : .green)
            } compactTrailing: {
                timerView(for: context.state)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(context.state.phase == .rest ? .orange : .primary)
                    .frame(maxWidth: 64)
                    .minimumScaleFactor(0.6)
            } minimal: {
                Image(systemName: context.state.phase == .rest ? "pause.circle.fill" : "heart.fill")
                    .foregroundStyle(context.state.phase == .rest ? .orange : .green)
            }
        }
    }

    @ViewBuilder
    private func timerView(for state: WorkoutLiveActivityAttributes.ContentState) -> some View {
        if state.phase == .rest, let end = state.restEndDate {
            Text(timerInterval: Date.now...max(end, Date.now.addingTimeInterval(1)), countsDown: true, showsHours: true)
        } else {
            Text(timerInterval: state.exerciseTimerStart...Date.distantFuture, countsDown: false, showsHours: true)
        }
    }

    private func phaseBadge(_ state: WorkoutLiveActivityAttributes.ContentState) -> some View {
        Text(state.phase == .rest ? "PAUSA" : "TREINO")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(state.phase == .rest ? Color.orange.opacity(0.25) : Color.green.opacity(0.25))
            .clipShape(Capsule())
    }
}

private struct LockScreenWorkoutLiveActivityView: View {
    let state: WorkoutLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.green)
                    Text("HealthFit")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("·")
                        .foregroundStyle(.white.opacity(0.35))
                    Text(state.phase == .rest ? "Pausa" : "Exercício")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(state.phase == .rest ? .orange : .green)
                }

                Text(state.exerciseName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(state.workoutTitle)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                if state.phase == .rest, let end = state.restEndDate {
                    Text(timerInterval: Date.now...max(end, Date.now.addingTimeInterval(1)), countsDown: true, showsHours: true)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.trailing)
                    Text("restante")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange.opacity(0.8))
                } else {
                    Text(timerInterval: state.exerciseTimerStart...Date.distantFuture, countsDown: false, showsHours: true)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.trailing)
                    Text(state.setsLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
