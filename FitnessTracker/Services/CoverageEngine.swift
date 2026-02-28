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
    // Region reaches 100% when at least this many working sets are logged.
    private static let targetWorkingSetsPerRegion = 4

    static func buildReport(for session: WorkoutSession, split: WorkoutType) -> CoverageReport {
        var regionSetCounts: [UUID: Int] = [:]
        var regionExercises: [UUID: Set<String>] = [:]

        for loggedExercise in session.loggedExercises {
            let workingSets = loggedExercise.sets.filter { !$0.isWarmup }
            guard !workingSets.isEmpty else { continue }

            let regionIDs = matchedRegionIDs(for: loggedExercise, in: split)
            guard !regionIDs.isEmpty else { continue }

            let exerciseName = loggedExercise.exercise?.name ?? "Exercise"
            for regionID in regionIDs {
                regionSetCounts[regionID, default: 0] += workingSets.count
                regionExercises[regionID, default: []].insert(exerciseName)
            }
        }

        let groups = split.includedMuscleGroups.map { group in
            let regions: [RegionCoverage] = group.regions.map { region in
                let setCount = regionSetCounts[region.id, default: 0]
                let progress = min(1, Double(setCount) / Double(targetWorkingSetsPerRegion))
                let exercises = Array(regionExercises[region.id, default: []]).sorted()

                return RegionCoverage(
                    id: region.id,
                    name: region.name,
                    touched: setCount > 0,
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

    private static func matchedRegionIDs(for loggedExercise: LoggedExercise, in split: WorkoutType) -> [UUID] {
        let exerciseName = loggedExercise.exercise?.name.lowercased() ?? ""
        guard !exerciseName.isEmpty else { return [] }

        let splitRegions = split.includedMuscleGroups.flatMap(\.regions)
        let keywordMatched = splitRegions.filter { region in
            regionKeywords(regionName: region.name).contains { exerciseName.contains($0) }
        }

        if !keywordMatched.isEmpty {
            return keywordMatched.map(\.id)
        }

        // Conservative fallback: only use explicit map if exactly one region is mapped.
        let mapped = loggedExercise.exercise?.muscleMaps.compactMap { $0.muscleRegion } ?? []
        let mappedInSplit = mapped.filter { region in
            splitRegions.contains(where: { $0.id == region.id })
        }

        if mappedInSplit.count == 1, let only = mappedInSplit.first {
            return [only.id]
        }

        return []
    }

    private static func regionKeywords(regionName: String) -> [String] {
        let key = regionName.lowercased()
        switch key {
        case "upper":
            return ["incline"]
        case "mid":
            return ["bench", "press", "fly", "push-up"]
        case "lower":
            return ["decline", "dip", "deadlift", "back extension"]

        case "long":
            return ["overhead", "skull", "incline"]
        case "lateral":
            return ["pushdown", "pressdown", "lateral", "kickback"]
        case "medial":
            return ["close-grip", "close grip", "dip", "pushdown"]

        case "anterior":
            return ["press", "front raise"]
        case "posterior":
            return ["rear delt", "face pull", "reverse fly"]

        case "lats":
            return ["pulldown", "pull-up", "chin-up", "straight-arm"]
        case "upper back":
            return ["row", "face pull", "rear delt"]
        case "lower back":
            return ["deadlift", "rdl", "back extension", "good morning"]

        case "short":
            return ["preacher", "concentration", "cable curl"]
        case "brachialis":
            return ["hammer", "reverse curl"]

        case "quads":
            return ["squat", "leg press", "leg extension", "lunge", "split squat", "hack squat"]
        case "hamstrings":
            return ["rdl", "romanian", "leg curl", "deadlift"]
        case "glutes":
            return ["hip thrust", "glute", "lunge", "squat", "deadlift"]
        case "calves":
            return ["calf"]

        case "upper abs":
            return ["crunch", "sit-up"]
        case "lower abs":
            return ["leg raise", "hanging knee", "reverse crunch"]
        case "obliques":
            return ["twist", "side plank", "woodchop"]

        default:
            return [key]
        }
    }
}
