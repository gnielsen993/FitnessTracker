import Foundation
import SwiftData

final class BootstrapService {
    func bootstrapIfNeeded(context: ModelContext) throws {
        let groups = try ensureMuscleGroups(context: context)
        try ensureDefaultRoutines(context: context, groups: groups)
        try migrateTemplateExercisesIfNeeded(context: context)
        try context.save()
    }

    /// Migrate legacy `templateExercises` arrays to `TemplateExercise` join objects.
    private func migrateTemplateExercisesIfNeeded(context: ModelContext) throws {
        let routines = try context.fetch(FetchDescriptor<WorkoutType>())
        for routine in routines {
            guard !routine.templateExercises.isEmpty, routine.templateItems.isEmpty else { continue }
            for (index, exercise) in routine.templateExercises.enumerated() {
                let item = TemplateExercise(orderIndex: index, defaultSets: 3, routine: routine, exercise: exercise)
                context.insert(item)
                routine.templateItems.append(item)
            }
            routine.templateExercises.removeAll()
        }
    }

    private func ensureMuscleGroups(context: ModelContext) throws -> [String: MuscleGroup] {
        let existingGroups = try context.fetch(FetchDescriptor<MuscleGroup>())
        var groupIndex = Dictionary(uniqueKeysWithValues: existingGroups.map { ($0.name.lowercased(), $0) })

        func ensureGroup(_ name: String, _ regions: [String]) -> MuscleGroup {
            if let g = groupIndex[name.lowercased()] {
                let existingRegionNames = Set(g.regions.map { $0.name.lowercased() })
                for region in regions where !existingRegionNames.contains(region.lowercased()) {
                    g.regions.append(MuscleRegion(name: region, group: g))
                }
                return g
            }

            let group = MuscleGroup(name: name, regions: regions.map { MuscleRegion(name: $0) })
            context.insert(group)
            groupIndex[name.lowercased()] = group
            return group
        }

        _ = ensureGroup("Chest", ["Upper", "Mid", "Lower"])
        _ = ensureGroup("Triceps", ["Long", "Lateral", "Medial"])
        _ = ensureGroup("Shoulders", ["Anterior", "Lateral", "Posterior"])
        _ = ensureGroup("Back", ["Lats", "Upper Back", "Lower Back"])
        _ = ensureGroup("Biceps", ["Long", "Short", "Brachialis"])
        _ = ensureGroup("Legs", ["Quads", "Hamstrings", "Glutes", "Calves"])
        _ = ensureGroup("Core", ["Upper Abs", "Lower Abs", "Obliques"])

        return groupIndex
    }

    private static let deletedRoutinesKey = "bootstrap.deletedRoutines"

    /// Record that the user explicitly deleted a default routine so we don't re-seed it.
    static func markRoutineDeleted(_ name: String) {
        var deleted = UserDefaults.standard.stringArray(forKey: deletedRoutinesKey) ?? []
        let key = name.lowercased()
        if !deleted.contains(key) {
            deleted.append(key)
            UserDefaults.standard.set(deleted, forKey: deletedRoutinesKey)
        }
    }

    private func ensureDefaultRoutines(context: ModelContext, groups: [String: MuscleGroup]) throws {
        let existingRoutines = try context.fetch(FetchDescriptor<WorkoutType>())
        var routineIndex = Dictionary(uniqueKeysWithValues: existingRoutines.map { ($0.name.lowercased(), $0) })
        let deletedByUser = Set(UserDefaults.standard.stringArray(forKey: Self.deletedRoutinesKey) ?? [])

        let allGroups = ["chest", "triceps", "shoulders", "back", "biceps", "legs", "core"].compactMap { groups[$0] }

        var routineCounter = 0
        func ensureRoutine(_ name: String, _ groupKeys: [String]) {
            guard !deletedByUser.contains(name.lowercased()) else { return }

            let targetGroups = groupKeys.compactMap { groups[$0] }
            if let existing = routineIndex[name.lowercased()] {
                if existing.sortOrder == 0 { existing.sortOrder = routineCounter }
                let existingIDs = Set(existing.includedMuscleGroups.map { $0.id })
                for group in targetGroups where !existingIDs.contains(group.id) {
                    existing.includedMuscleGroups.append(group)
                }
                routineCounter += 1
                return
            }

            let created = WorkoutType(name: name, sortOrder: routineCounter, includedMuscleGroups: targetGroups)
            context.insert(created)
            routineIndex[name.lowercased()] = created
            routineCounter += 1
        }

        ensureRoutine("Push", ["chest", "triceps", "shoulders"])
        ensureRoutine("Pull", ["back", "biceps", "shoulders"])
        ensureRoutine("Lower", ["legs", "core"])
        ensureRoutine("Full Body", allGroups.map { $0.name.lowercased() })
    }
}
