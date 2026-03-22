import Foundation
import SwiftData

@Model
final class TemplateExercise {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var defaultSets: Int

    var routine: WorkoutType?
    var exercise: Exercise?

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        defaultSets: Int = 3,
        routine: WorkoutType? = nil,
        exercise: Exercise? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.defaultSets = defaultSets
        self.routine = routine
        self.exercise = exercise
    }
}
