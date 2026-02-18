import Foundation

enum StatsEngine {
    nonisolated static func totalSessionVolume(_ session: WorkoutSession) -> Double {
        session.loggedExercises
            .flatMap(\.sets)
            .filter { !$0.isWarmup }
            .reduce(0) { $0 + $1.volume }
    }

    nonisolated static func exerciseVolume(_ loggedExercise: LoggedExercise) -> Double {
        loggedExercise.sets
            .filter { !$0.isWarmup }
            .reduce(0) { $0 + $1.volume }
    }

    // Epley formula for rough trend visualization.
    nonisolated static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return 0 }
        return weight * (1 + Double(reps) / 30.0)
    }
}
