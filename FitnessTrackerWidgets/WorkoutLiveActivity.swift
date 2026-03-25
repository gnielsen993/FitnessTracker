import SwiftUI
import WidgetKit
import ActivityKit

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // Lock screen / banner presentation
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions — fill the space properly
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.routineName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.completedExercises)/\(context.state.totalExercises)")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.restTimerFinished {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Rest Complete")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            Capsule()
                                .fill(.green.opacity(0.15))
                        )
                    } else if let endDate = context.state.restTimerEndDate, endDate > .now {
                        HStack {
                            Label("Rest", systemImage: "timer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(timerInterval: Date.now...endDate, countsDown: true)
                                .font(.headline.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.orange)
                                .contentTransition(.numericText())
                        }
                    } else {
                        HStack {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .foregroundStyle(.green)
                            Text(context.state.currentExerciseName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                }
            } compactLeading: {
                // Timer/status on left to avoid music app overlap on trailing side
                if context.state.restTimerFinished {
                    ZStack {
                        Circle().stroke(.green, lineWidth: 1.5)
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .font(.caption2.weight(.bold))
                    }
                    .frame(width: 18, height: 18)
                } else if let endDate = context.state.restTimerEndDate, endDate > .now {
                    Text(timerInterval: Date.now...endDate, countsDown: true)
                        .monospacedDigit()
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(width: 36)
                } else {
                    Text("\(context.state.completedExercises)/\(context.state.totalExercises)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } compactTrailing: {
                // Intentionally empty so system-compacted pair prefers
                // timer on leading side and leaves trailing side for other apps (e.g. music).
                EmptyView()
            } minimal: {
                // Minimal view should prioritize timer visibility over branding icon.
                if context.state.restTimerFinished {
                    ZStack {
                        Circle().stroke(.green, lineWidth: 1.5)
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                            .font(.caption2.weight(.bold))
                    }
                } else if let endDate = context.state.restTimerEndDate, endDate > .now {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                } else {
                    Text("\(context.state.completedExercises)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundStyle(.green)
                Text(context.attributes.routineName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("\(context.state.completedExercises)/\(context.state.totalExercises)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(
                value: Double(context.state.completedExercises),
                total: max(1, Double(context.state.totalExercises))
            )
            .tint(.green)

            HStack {
                if context.state.restTimerFinished {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text("Rest Complete")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundStyle(.green)
                        .font(.caption)
                    Text(context.state.currentExerciseName)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                Spacer()
                if let endDate = context.state.restTimerEndDate, endDate > .now {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        Text(timerInterval: Date.now...endDate, countsDown: true)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding()
    }
}
