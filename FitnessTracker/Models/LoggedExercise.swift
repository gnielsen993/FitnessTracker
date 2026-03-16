import Foundation
import SwiftData

@Model
final class LoggedExercise {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var targetWorkingSets: Int
    var isMarkedDone: Bool

    var session: WorkoutSession?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.loggedExercise) var sets: [LoggedSet]

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        targetWorkingSets: Int = 3,
        isMarkedDone: Bool = false,
        session: WorkoutSession? = nil,
        exercise: Exercise? = nil,
        sets: [LoggedSet] = []
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.targetWorkingSets = targetWorkingSets
        self.isMarkedDone = isMarkedDone
        self.session = session
        self.exercise = exercise
        self.sets = sets
    }
}
