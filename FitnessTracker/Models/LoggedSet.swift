import Foundation
import SwiftData

@Model
final class LoggedSet {
    @Attribute(.unique) var id: UUID
    var reps: Int
    var weight: Double
    var isWarmup: Bool
    var createdAt: Date

    var loggedExercise: LoggedExercise?

    init(
        id: UUID = UUID(),
        reps: Int,
        weight: Double,
        isWarmup: Bool = false,
        createdAt: Date = .now,
        loggedExercise: LoggedExercise? = nil
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.isWarmup = isWarmup
        self.createdAt = createdAt
        self.loggedExercise = loggedExercise
    }

    var volume: Double {
        weight * Double(reps)
    }
}
