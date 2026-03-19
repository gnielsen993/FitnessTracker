import Foundation
import SwiftData

final class SeedDataService {
    private static let seedCompletedKey = "seed.v1.completed"
    private let decoder = JSONDecoder()

    func seedIfNeeded(context: ModelContext) throws {
        if UserDefaults.standard.bool(forKey: Self.seedCompletedKey) {
            return
        }

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


        // Ensure built-in routines have starter exercises if empty.
        let routines = try context.fetch(FetchDescriptor<WorkoutType>())
        let byName = Dictionary(uniqueKeysWithValues: routines.map { ($0.name.lowercased(), $0) })

        func addStarterExercises(to routineName: String, categories: Set<String>, limit: Int = 8) {
            guard let routine = byName[routineName.lowercased()] else { return }
            guard routine.templateExercises.isEmpty else { return }

            let picks = exerciseIndex.values
                .filter { categories.contains($0.category.lowercased()) }
                .sorted { $0.name < $1.name }
                .prefix(limit)

            for ex in picks {
                routine.templateExercises.append(ex)
            }
        }

        addStarterExercises(to: "Push", categories: ["chest", "triceps", "shoulders"])
        addStarterExercises(to: "Pull", categories: ["back", "biceps", "shoulders"])
        addStarterExercises(to: "Lower", categories: ["legs", "core"])
        addStarterExercises(to: "Full Body", categories: ["chest", "triceps", "shoulders", "back", "biceps", "legs", "core"])

        try context.save()
        UserDefaults.standard.set(true, forKey: Self.seedCompletedKey)
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
