import Foundation
import SwiftData

final class SeedDataService {
    private let decoder = JSONDecoder()

    func seedIfNeeded(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Exercise>())
        guard existing.isEmpty else { return }

        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "seed_exercises_v1", withExtension: "json")
        #else
        let url = Bundle.main.url(forResource: "seed_exercises_v1", withExtension: "json")
        #endif
        guard let url else { return }

        let data = try Data(contentsOf: url)
        let payload = try decoder.decode(SeedExercisePayload.self, from: data)

        let groups = try context.fetch(FetchDescriptor<MuscleGroup>())
        let groupIndex = Dictionary(uniqueKeysWithValues: groups.map { ($0.name.lowercased(), $0) })

        for seed in payload.exercises {
            let exercise = Exercise(
                name: seed.name,
                category: seed.category,
                equipment: seed.equipment
            )
            context.insert(exercise)

            let key = seed.category.lowercased()
            if let group = groupIndex[key] {
                for region in group.regions {
                    let map = ExerciseMuscleMap(role: .primary, exercise: exercise, muscleRegion: region)
                    context.insert(map)
                    exercise.muscleMaps.append(map)
                }
            }
        }

        try context.save()
    }
}

struct SeedExercisePayload: Codable {
    let schemaVersion: Int
    let exercises: [SeedExercise]
}

struct SeedExercise: Codable {
    let name: String
    let category: String
    let equipment: String
}
