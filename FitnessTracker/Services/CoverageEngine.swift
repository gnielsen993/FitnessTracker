import Foundation

struct RegionCoverage: Identifiable {
    let id: UUID
    let name: String
    let touched: Bool
}

struct GroupCoverage: Identifiable {
    let id: UUID
    let name: String
    let touchedRegions: Int
    let totalRegions: Int
    let regions: [RegionCoverage]
}

struct CoverageReport {
    let splitName: String
    let groups: [GroupCoverage]
}

enum CoverageEngine {
    // Binary coverage: any non-warmup set touching a mapped region marks that region as covered.
    static func buildReport(for session: WorkoutSession, split: WorkoutType) -> CoverageReport {
        let touchedRegionIDs = Set(session.loggedExercises.flatMap { loggedExercise -> [UUID] in
            let hasWorkingSet = loggedExercise.sets.contains { !$0.isWarmup }
            guard hasWorkingSet else { return [] }

            return loggedExercise.exercise?.muscleMaps.compactMap { $0.muscleRegion?.id } ?? []
        })

        let groups = split.includedMuscleGroups.map { group in
            let regions = group.regions.map { region in
                RegionCoverage(
                    id: region.id,
                    name: region.name,
                    touched: touchedRegionIDs.contains(region.id)
                )
            }

            return GroupCoverage(
                id: group.id,
                name: group.name,
                touchedRegions: regions.filter(\.touched).count,
                totalRegions: regions.count,
                regions: regions
            )
        }

        return CoverageReport(splitName: split.name, groups: groups)
    }
}
