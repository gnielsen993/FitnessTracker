import Foundation

struct RegionCoverage: Identifiable {
    let id: UUID
    let name: String
    let touched: Bool
    let workingSetCount: Int
    let progress: Double
    let contributingExercises: [String]
}

struct GroupCoverage: Identifiable {
    let id: UUID
    let name: String
    let touchedRegions: Int
    let totalRegions: Int
    let progress: Double
    let regions: [RegionCoverage]
}

struct CoverageReport {
    let splitName: String
    let groups: [GroupCoverage]
}

enum CoverageEngine {
    // Region reaches 100% when weighted working-set score reaches this value.
    private static let targetSetScorePerRegion = 4.0

    static func buildReport(for session: WorkoutSession, split: WorkoutType) -> CoverageReport {
        var regionScores: [UUID: Double] = [:]
        var regionRawSetCounts: [UUID: Int] = [:]
        var regionExercises: [UUID: Set<String>] = [:]

        let splitRegionIDs = Set(split.includedMuscleGroups.flatMap(\.regions).map(\.id))

        for loggedExercise in session.loggedExercises {
            let workingSetCount = loggedExercise.sets.filter { !$0.isWarmup }.count
            guard workingSetCount > 0 else { continue }

            let exerciseName = loggedExercise.exercise?.name ?? "Exercise"
            let maps = loggedExercise.exercise?.muscleMaps ?? []

            for map in maps {
                guard let region = map.muscleRegion else { continue }
                guard splitRegionIDs.contains(region.id) else { continue }

                let multiplier: Double = (map.role == ExerciseRole.primary.rawValue) ? 1.0 : 0.5
                regionScores[region.id, default: 0] += Double(workingSetCount) * multiplier
                regionRawSetCounts[region.id, default: 0] += workingSetCount
                regionExercises[region.id, default: []].insert(exerciseName)
            }
        }

        let groups = split.includedMuscleGroups.map { group in
            let regions: [RegionCoverage] = group.regions.map { region in
                let score = regionScores[region.id, default: 0]
                let setCount = regionRawSetCounts[region.id, default: 0]
                let progress = min(1, score / targetSetScorePerRegion)
                let exercises = Array(regionExercises[region.id, default: []]).sorted()

                return RegionCoverage(
                    id: region.id,
                    name: region.name,
                    touched: score > 0,
                    workingSetCount: setCount,
                    progress: progress,
                    contributingExercises: exercises
                )
            }

            let touchedRegions = regions.filter { $0.progress >= 0.75 }.count
            let groupProgress = regions.isEmpty ? 0 : regions.map(\.progress).reduce(0, +) / Double(regions.count)

            return GroupCoverage(
                id: group.id,
                name: group.name,
                touchedRegions: touchedRegions,
                totalRegions: regions.count,
                progress: groupProgress,
                regions: regions
            )
        }

        return CoverageReport(splitName: split.name, groups: groups)
    }
}
