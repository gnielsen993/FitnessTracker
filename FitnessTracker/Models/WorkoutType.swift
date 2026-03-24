import Foundation
import SwiftData

@Model
final class WorkoutType {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int

    // A split owns the groups it targets. Default presets are seeded at first launch.
    @Relationship(deleteRule: .nullify) var includedMuscleGroups: [MuscleGroup]

    // Legacy: kept temporarily for migration from old templateExercises to templateItems.
    @Relationship(deleteRule: .nullify) var templateExercises: [Exercise]

    // New join model with per-exercise config (order, default sets).
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.routine) var templateItems: [TemplateExercise]

    // Inverse of WorkoutSession.workoutType — lets SwiftData auto-nil on delete.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.workoutType) var sessions: [WorkoutSession]

    var sortedTemplateItems: [TemplateExercise] {
        templateItems.sorted { $0.orderIndex < $1.orderIndex }
    }

    init(
        id: UUID = UUID(),
        name: String,
        sortOrder: Int = 0,
        includedMuscleGroups: [MuscleGroup] = [],
        templateExercises: [Exercise] = [],
        templateItems: [TemplateExercise] = [],
        sessions: [WorkoutSession] = []
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.includedMuscleGroups = includedMuscleGroups
        self.templateExercises = templateExercises
        self.templateItems = templateItems
        self.sessions = sessions
    }
}
