import Foundation
import SwiftData

enum ExerciseRole: String, Codable, CaseIterable {
    case primary
    case secondary
}

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var equipment: String

    @Relationship(deleteRule: .cascade, inverse: \ExerciseMuscleMap.exercise) var muscleMaps: [ExerciseMuscleMap]

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        equipment: String,
        muscleMaps: [ExerciseMuscleMap] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.equipment = equipment
        self.muscleMaps = muscleMaps
    }
}
