import ActivityKit
import SwiftUI
import WidgetKit

@main
struct HealthFitWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivityWidget()
        EveningTrainingNudgeLiveActivityWidget()
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
                    HealthFitBrandMark(font: .caption.weight(.semibold), foreground: .green)
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
                    .symbolEffect(.pulse, options: .repeating, isActive: context.state.phase != .rest)
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

/// Brand heart + “HealthFit” kept on one non-wrapping line (lock screen + Dynamic Island).
private struct HealthFitBrandMark: View {
    var font: Font = .caption.weight(.bold)
    var foreground: Color = .white.opacity(0.85)
    var heartColor: Color = .green

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .foregroundStyle(heartColor)
                .symbolEffect(.pulse, options: .repeating)

            Text("HealthFit")
                .font(font)
                .foregroundStyle(foreground)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("HealthFit")
    }
}

private struct LockScreenWorkoutLiveActivityView: View {
    let state: WorkoutLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    HealthFitBrandMark()

                    Text("·")
                        .foregroundStyle(.white.opacity(0.35))

                    Text(state.phase == .rest ? "Pausa" : "Exercício")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(state.phase == .rest ? .orange : .green)
                        .lineLimit(1)
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

// MARK: - Evening training nudge (18:00)

struct EveningTrainingNudgeLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EveningTrainingNudgeAttributes.self) { context in
            LockScreenEveningTrainingNudgeView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HealthFitBrandMark(font: .caption.weight(.semibold), foreground: .green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...max(context.state.countdownEndDate, Date.now.addingTimeInterval(1)),
                         countsDown: true,
                         showsHours: true)
                        .font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(.orange)
                        .frame(maxWidth: 72)
                        .minimumScaleFactor(0.6)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.statusMessage)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.motivationalMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            } compactLeading: {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(timerInterval: Date.now...max(context.state.countdownEndDate, Date.now.addingTimeInterval(1)),
                     countsDown: true,
                     showsHours: true)
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: 56)
                    .minimumScaleFactor(0.5)
            } minimal: {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.green)
                    .symbolEffect(.pulse, options: .repeating)
            }
        }
    }
}

private struct LockScreenEveningTrainingNudgeView: View {
    let state: EveningTrainingNudgeAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HealthFitBrandMark()

                Text(state.statusMessage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(state.motivationalMessage)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(3)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(
                    timerInterval: Date.now...max(state.countdownEndDate, Date.now.addingTimeInterval(1)),
                    countsDown: true,
                    showsHours: true
                )
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.orange)
                .multilineTextAlignment(.trailing)

                Text("restante")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange.opacity(0.8))
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
