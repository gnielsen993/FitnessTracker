import Foundation

struct WorkingWeightRecommendation: Identifiable {
    let id = UUID()
    let reps: Int
    let weight: Double
}

struct ProgressiveSuggestion {
    let message: String
    let estimatedOneRM: Double?
    let recommendations: [WorkingWeightRecommendation]
}

enum ProgressiveOverloadEngine {
    private static let repGoal = 10

    static func suggestion(
        exercise: Exercise?,
        latestWorkingSet: LoggedSet?,
        recentWorkingSets: [LoggedSet]
    ) -> ProgressiveSuggestion? {
        guard let latestWorkingSet else { return nil }

        let increment = suggestedIncrement(for: exercise)
        let currentWeight = latestWorkingSet.weight
        let currentReps = latestWorkingSet.reps

        let message: String
        if currentReps < repGoal {
            let targetReps = min(repGoal, currentReps + 1)
            message = "Last set was \(currentReps)x\(Int(currentWeight)). Keep the same weight and aim for \(targetReps) reps next set."
        } else {
            let nextWeight = roundedToNearestFive(currentWeight + increment)
            message = "You hit \(currentReps) reps at \(Int(currentWeight)). Increase to ~\(Int(nextWeight)) and work back up from 6-8 reps."
        }

        let oneRM = estimateOneRM(from: recentWorkingSets + [latestWorkingSet])
        let recommendations: [WorkingWeightRecommendation]
        if let oneRM {
            recommendations = [5, 8, 10].map { reps in
                let weight = oneRM / (1 + Double(reps) / 30.0) // Epley inverse
                return WorkingWeightRecommendation(reps: reps, weight: roundedToNearestFive(weight))
            }
        } else {
            recommendations = []
        }

        return ProgressiveSuggestion(
            message: message,
            estimatedOneRM: oneRM,
            recommendations: recommendations
        )
    }

    private static func estimateOneRM(from sets: [LoggedSet]) -> Double? {
        let working = sets.filter { !$0.isWarmup && $0.reps > 0 && $0.weight > 0 }
        guard !working.isEmpty else { return nil }
        return working.map { StatsEngine.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max()
    }

    private static func suggestedIncrement(for exercise: Exercise?) -> Double {
        guard let category = exercise?.category.lowercased() else { return 5 }
        if category.contains("legs") || category.contains("back") {
            return 10
        }
        return 5
    }

    private static func roundedToNearestFive(_ value: Double) -> Double {
        (value / 5.0).rounded() * 5.0
    }
}
