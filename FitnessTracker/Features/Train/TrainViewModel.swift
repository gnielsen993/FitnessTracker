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
        coverageReport = CoverageEngine.buildReport(for: session, split: split)
        try context.save()
    }

    func refreshCoverage() {
        guard let session = activeSession, let split = selectedSplit else { return }
        coverageReport = CoverageEngine.buildReport(for: session, split: split)
    }

    func addExercise(_ exercise: Exercise, context: ModelContext) throws {
        guard let session = activeSession else { return }
        let nextIndex = session.loggedExercises.count
        let logged = LoggedExercise(orderIndex: nextIndex, session: session, exercise: exercise)
        context.insert(logged)
        session.loggedExercises.append(logged)
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
        let set = LoggedSet(reps: reps, weight: weight, isWarmup: isWarmup, loggedExercise: loggedExercise)
        context.insert(set)
        loggedExercise.sets.append(set)
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
