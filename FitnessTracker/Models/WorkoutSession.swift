import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var notes: String

    var workoutType: WorkoutType?

    @Relationship(deleteRule: .cascade, inverse: \LoggedExercise.session) var loggedExercises: [LoggedExercise]

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        endedAt: Date? = nil,
        notes: String = "",
        workoutType: WorkoutType? = nil,
        loggedExercises: [LoggedExercise] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
        self.workoutType = workoutType
        self.loggedExercises = loggedExercises
    }
}
