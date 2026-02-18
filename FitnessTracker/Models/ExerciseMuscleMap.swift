import Foundation
import SwiftData

@Model
final class ExerciseMuscleMap {
    @Attribute(.unique) var id: UUID
    var role: ExerciseRole.RawValue

    var exercise: Exercise?
    var muscleRegion: MuscleRegion?

    init(
        id: UUID = UUID(),
        role: ExerciseRole,
        exercise: Exercise? = nil,
        muscleRegion: MuscleRegion? = nil
    ) {
        self.id = id
        self.role = role.rawValue
        self.exercise = exercise
        self.muscleRegion = muscleRegion
    }
}
