import Foundation
import SwiftData

@Model
final class WorkoutType {
    @Attribute(.unique) var id: UUID
    var name: String

    // A split owns the groups it targets. Default presets are seeded at first launch.
    @Relationship(deleteRule: .nullify) var includedMuscleGroups: [MuscleGroup]

    init(
        id: UUID = UUID(),
        name: String,
        includedMuscleGroups: [MuscleGroup] = []
    ) {
        self.id = id
        self.name = name
        self.includedMuscleGroups = includedMuscleGroups
    }
}
