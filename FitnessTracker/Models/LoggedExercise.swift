import Foundation
import SwiftData

@Model
final class LoggedExercise {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int

    var session: WorkoutSession?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.loggedExercise) var sets: [LoggedSet]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        session: WorkoutSession? = nil,
        exercise: Exercise? = nil,
        sets: [LoggedSet] = []
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.session = session
        self.exercise = exercise
        self.sets = sets
    }
}
