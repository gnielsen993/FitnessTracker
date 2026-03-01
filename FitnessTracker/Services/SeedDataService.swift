import Foundation
import SwiftData

final class SeedDataService {
    private let decoder = JSONDecoder()

    func seedIfNeeded(context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<Exercise>())

        #if SWIFT_PACKAGE
        let url = Bundle.module.url(forResource: "seed_exercises_v1", withExtension: "json")
        #else
        let url = Bundle.main.url(forResource: "seed_exercises_v1", withExtension: "json")
        #endif
        guard let url else { return }

        let data = try Data(contentsOf: url)
        let payload = try decoder.decode(SeedExercisePayload.self, from: data)

        let groups = try context.fetch(FetchDescriptor<MuscleGroup>())
        let allRegions = groups.flatMap(\.regions)
        let regionIndex = Dictionary(allRegions.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { _, latest in latest })

        var exerciseIndex = Dictionary(existing.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { _, latest in latest })

        for seed in payload.exercises {
            let normalizedName = seed.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            let exercise: Exercise
            if let existingExercise = exerciseIndex[normalizedName] {
                exercise = existingExercise
                exercise.category = seed.category
                exercise.equipment = seed.equipment
            } else {
                let created = Exercise(name: seed.name, category: seed.category, equipment: seed.equipment)
                context.insert(created)
                exercise = created
                exerciseIndex[normalizedName] = created
            }

            // Replace broad/legacy mappings with curated table-driven mappings.
            for map in exercise.muscleMaps {
                context.delete(map)
            }
            exercise.muscleMaps.removeAll()

            let primary = seed.primaryRegions ?? []
            let secondary = seed.secondaryRegions ?? []

            var inserted = false
            for regionName in primary {
                if let region = regionIndex[regionName.lowercased()] {
                    let map = ExerciseMuscleMap(role: .primary, exercise: exercise, muscleRegion: region)
                    context.insert(map)
                    exercise.muscleMaps.append(map)
                    inserted = true
                }
            }

            for regionName in secondary {
                if let region = regionIndex[regionName.lowercased()] {
                    let map = ExerciseMuscleMap(role: .secondary, exercise: exercise, muscleRegion: region)
                    context.insert(map)
                    exercise.muscleMaps.append(map)
                    inserted = true
                }
            }

            // Safety fallback for seeds that somehow have no mappings.
            if !inserted {
                let fallbackRegions = groups
                    .first(where: { $0.name.caseInsensitiveCompare(seed.category) == .orderedSame })?
                    .regions ?? []

                for region in fallbackRegions {
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
    let primaryRegions: [String]?
    let secondaryRegions: [String]?
}
