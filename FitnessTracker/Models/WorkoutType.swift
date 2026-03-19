import Foundation
import SwiftData

@Model
final class WorkoutType {
    @Attribute(.unique) var id: UUID
    var name: String

    // A split owns the groups it targets. Default presets are seeded at first launch.
    @Relationship(deleteRule: .nullify) var includedMuscleGroups: [MuscleGroup]

    // Remembered exercises for this split — auto-added when starting a workout.
    @Relationship(deleteRule: .nullify) var templateExercises: [Exercise]

    // Inverse of WorkoutSession.workoutType — lets SwiftData auto-nil on delete.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.workoutType) var sessions: [WorkoutSession]

    init(
        id: UUID = UUID(),
        name: String,
        includedMuscleGroups: [MuscleGroup] = [],
        templateExercises: [Exercise] = [],
        sessions: [WorkoutSession] = []
    ) {
        self.id = id
        self.name = name
        self.includedMuscleGroups = includedMuscleGroups
        self.templateExercises = templateExercises
        self.sessions = sessions
    }
}
