import Foundation
import SwiftData

final class BootstrapService {
    func bootstrapIfNeeded(context: ModelContext) throws {
        let existingGroups = try context.fetch(FetchDescriptor<MuscleGroup>())
        guard existingGroups.isEmpty else { return }

        let chest = MuscleGroup(name: "Chest", regions: [
            MuscleRegion(name: "Upper"),
            MuscleRegion(name: "Mid"),
            MuscleRegion(name: "Lower")
        ])

        let triceps = MuscleGroup(name: "Triceps", regions: [
            MuscleRegion(name: "Long"),
            MuscleRegion(name: "Lateral"),
            MuscleRegion(name: "Medial")
        ])

        let shoulders = MuscleGroup(name: "Shoulders", regions: [
            MuscleRegion(name: "Anterior"),
            MuscleRegion(name: "Lateral"),
            MuscleRegion(name: "Posterior")
        ])

        let back = MuscleGroup(name: "Back", regions: [
            MuscleRegion(name: "Lats"),
            MuscleRegion(name: "Upper Back"),
            MuscleRegion(name: "Lower Back")
        ])

        let biceps = MuscleGroup(name: "Biceps", regions: [
            MuscleRegion(name: "Long"),
            MuscleRegion(name: "Short"),
            MuscleRegion(name: "Brachialis")
        ])

        let legs = MuscleGroup(name: "Legs", regions: [
            MuscleRegion(name: "Quads"),
            MuscleRegion(name: "Hamstrings"),
            MuscleRegion(name: "Glutes"),
            MuscleRegion(name: "Calves")
        ])

        let core = MuscleGroup(name: "Core", regions: [
            MuscleRegion(name: "Upper Abs"),
            MuscleRegion(name: "Lower Abs"),
            MuscleRegion(name: "Obliques")
        ])

        let groups = [chest, triceps, shoulders, back, biceps, legs, core]
        groups.forEach { context.insert($0) }

        let push = WorkoutType(name: "Push", includedMuscleGroups: [chest, triceps, shoulders])
        let pull = WorkoutType(name: "Pull", includedMuscleGroups: [back, biceps, shoulders])
        let lower = WorkoutType(name: "Lower", includedMuscleGroups: [legs, core])
        let fullBody = WorkoutType(name: "Full Body", includedMuscleGroups: groups)

        [push, pull, lower, fullBody].forEach { context.insert($0) }

        try context.save()
    }
}
