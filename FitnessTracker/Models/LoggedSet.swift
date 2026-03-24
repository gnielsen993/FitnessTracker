import Foundation
import SwiftData

@Model
final class LoggedSet {
    @Attribute(.unique) var id: UUID
    var reps: Int
    var weight: Double
    var isWarmup: Bool
    var createdAt: Date
    var cardioDurationMinutes: Double?
    var cardioSpeedDescription: String?
    var cardioZoneDescription: String?
    var cardioDistance: Double?
    var cardioInclinePercent: Double?
    var pinPosition: String?
    var weightUnit: String = "lbs"

    var loggedExercise: LoggedExercise?

    init(
        id: UUID = UUID(),
        reps: Int,
        weight: Double,
        isWarmup: Bool = false,
        createdAt: Date = .now,
        cardioDurationMinutes: Double? = nil,
        cardioSpeedDescription: String? = nil,
        cardioZoneDescription: String? = nil,
        cardioDistance: Double? = nil,
        cardioInclinePercent: Double? = nil,
        pinPosition: String? = nil,
        weightUnit: String = "lbs",
        loggedExercise: LoggedExercise? = nil
    ) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.isWarmup = isWarmup
        self.createdAt = createdAt
        self.cardioDurationMinutes = cardioDurationMinutes
        self.cardioSpeedDescription = cardioSpeedDescription
        self.cardioZoneDescription = cardioZoneDescription
        self.cardioDistance = cardioDistance
        self.cardioInclinePercent = cardioInclinePercent
        self.pinPosition = pinPosition
        self.weightUnit = weightUnit
        self.loggedExercise = loggedExercise
    }

    var volume: Double {
        weight * Double(reps)
    }
}
