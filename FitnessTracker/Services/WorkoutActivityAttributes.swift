import Foundation
import ActivityKit

struct WorkoutActivityAttributes: ActivityAttributes {
    /// Static attributes set when the activity starts.
    var routineName: String
    var startTime: Date

    /// Dynamic state that updates throughout the workout.
    struct ContentState: Codable, Hashable {
        var completedExercises: Int
        var totalExercises: Int
        var currentExerciseName: String
        /// Non-nil when a rest timer is active; the UI uses `Text(timerInterval:)`.
        var restTimerEndDate: Date?
        /// True when the rest timer has just finished (triggers glow effect in Dynamic Island).
        var restTimerFinished: Bool = false
    }
}
