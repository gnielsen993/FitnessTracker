import Foundation
import Combine
import SwiftData

@MainActor
final class TrainViewModel: ObservableObject {
    @Published var activeSession: WorkoutSession?
    @Published var selectedSplit: WorkoutType?
    @Published var coverageReport: CoverageReport?

    func startWorkout(using split: WorkoutType, context: ModelContext) throws {
        let session = WorkoutSession(startedAt: .now, workoutType: split)
        context.insert(session)
        activeSession = session
        selectedSplit = split

        // Auto-add template exercises so the user doesn't start from scratch every session.
        let sortedTemplate = split.templateExercises.sorted { $0.name < $1.name }
        for (index, exercise) in sortedTemplate.enumerated() {
            let logged = LoggedExercise(orderIndex: index, session: session, exercise: exercise)
            context.insert(logged)
            session.loggedExercises.append(logged)
        }

        coverageReport = CoverageEngine.buildReport(for: session, split: split)
        try context.save()
    }

    func refreshCoverage() {
        guard let session = activeSession, let split = selectedSplit else { return }
        coverageReport = CoverageEngine.buildReport(for: session, split: split)
    }

    func addExercise(_ exercise: Exercise, context: ModelContext) throws {
        guard let session = activeSession else { return }

        if session.loggedExercises.contains(where: { $0.exercise?.id == exercise.id }) {
            throw TrainError.exerciseAlreadyAdded
        }

        let nextIndex = session.loggedExercises.count
        let logged = LoggedExercise(orderIndex: nextIndex, session: session, exercise: exercise)
        context.insert(logged)
        session.loggedExercises.append(logged)
        try context.save()
        refreshCoverage()
    }

    func removeExercise(_ loggedExercise: LoggedExercise, context: ModelContext) throws {
        guard let session = activeSession else { return }
        session.loggedExercises.removeAll { $0.id == loggedExercise.id }
        context.delete(loggedExercise)
        try context.save()
        refreshCoverage()
    }

    func addSet(
        reps: Int,
        weight: Double,
        isWarmup: Bool,
        to loggedExercise: LoggedExercise,
        context: ModelContext
    ) throws {
        guard reps > 0 else { throw TrainError.invalidReps }
        guard weight >= 0 else { throw TrainError.invalidWeight }

        let set = LoggedSet(reps: reps, weight: weight, isWarmup: isWarmup, loggedExercise: loggedExercise)
        context.insert(set)
        loggedExercise.sets.append(set)
        try context.save()
        refreshCoverage()
    }

    func updateSet(_ set: LoggedSet, reps: Int, weight: Double, isWarmup: Bool, context: ModelContext) throws {
        guard reps > 0 else { throw TrainError.invalidReps }
        guard weight >= 0 else { throw TrainError.invalidWeight }

        set.reps = reps
        set.weight = weight
        set.isWarmup = isWarmup
        try context.save()
        refreshCoverage()
    }

    func deleteSet(_ set: LoggedSet, from loggedExercise: LoggedExercise, context: ModelContext) throws {
        loggedExercise.sets.removeAll { $0.id == set.id }
        context.delete(set)
        try context.save()
        refreshCoverage()
    }

    func endWorkout(context: ModelContext) throws {
        guard let session = activeSession else { return }
        session.endedAt = .now
        try context.save()
        activeSession = nil
        coverageReport = nil
    }
}

enum TrainError: LocalizedError {
    case exerciseAlreadyAdded
    case invalidReps
    case invalidWeight

    var errorDescription: String? {
        switch self {
        case .exerciseAlreadyAdded:
            return "Exercise already exists in this workout."
        case .invalidReps:
            return "Reps must be greater than 0."
        case .invalidWeight:
            return "Weight cannot be negative."
        }
    }
}
