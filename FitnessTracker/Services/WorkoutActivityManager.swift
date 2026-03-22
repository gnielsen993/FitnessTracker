import Foundation
import ActivityKit

@MainActor
final class WorkoutActivityManager {
    static let shared = WorkoutActivityManager()
    private init() {}

    private var currentActivity: Activity<WorkoutActivityAttributes>?

    func startActivity(routineName: String, totalExercises: Int, currentExerciseName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = WorkoutActivityAttributes(
            routineName: routineName,
            startTime: .now
        )
        let state = WorkoutActivityAttributes.ContentState(
            completedExercises: 0,
            totalExercises: totalExercises,
            currentExerciseName: currentExerciseName
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    func updateActivity(
        completedExercises: Int,
        totalExercises: Int,
        currentExerciseName: String,
        restTimerEndDate: Date? = nil,
        restTimerFinished: Bool = false
    ) {
        guard let activity = currentActivity else { return }

        let state = WorkoutActivityAttributes.ContentState(
            completedExercises: completedExercises,
            totalExercises: totalExercises,
            currentExerciseName: currentExerciseName,
            restTimerEndDate: restTimerEndDate,
            restTimerFinished: restTimerFinished
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    func endActivity() {
        guard let activity = currentActivity else { return }
        let finalState = activity.content.state

        Task {
            await activity.end(
                .init(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        currentActivity = nil
    }

    /// Ends any Live Activities left over from a previous app session (e.g. after force-quit).
    /// Call this on app launch before potentially starting a new activity.
    func cleanupOrphanedActivities(hasActiveWorkout: Bool) {
        let runningActivities = Activity<WorkoutActivityAttributes>.activities

        if hasActiveWorkout {
            // Resume tracking the existing activity if one is running
            currentActivity = runningActivities.first
            // End any extras beyond the first
            for activity in runningActivities.dropFirst() {
                Task {
                    await activity.end(
                        .init(state: activity.content.state, staleDate: nil),
                        dismissalPolicy: .immediate
                    )
                }
            }
        } else {
            // No active workout — end all lingering activities
            for activity in runningActivities {
                Task {
                    await activity.end(
                        .init(state: activity.content.state, staleDate: nil),
                        dismissalPolicy: .immediate
                    )
                }
            }
        }
    }
}
