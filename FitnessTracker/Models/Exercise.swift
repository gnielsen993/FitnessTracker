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

extension Array where Element: Exercise {
    func groupedByCategory(filter: String = "") -> [(category: String, items: [Exercise])] {
        let query = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered: [Exercise] = query.isEmpty ? self : self.filter {
            $0.name.lowercased().contains(query)
                || $0.category.lowercased().contains(query)
                || $0.equipment.lowercased().contains(query)
        }
        let grouped = Dictionary(grouping: filtered) { $0.category }
        return grouped.keys.sorted().map { key in
            (category: key, items: grouped[key]?.sorted(by: { $0.name < $1.name }) ?? [])
        }
    }
}
