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
        for (index, exercise) in split.templateExercises.enumerated() {
            let logged = LoggedExercise(orderIndex: index, targetWorkingSets: 3, isMarkedDone: false, session: session, exercise: exercise)
            context.insert(logged)
            session.loggedExercises.append(logged)
        }

        coverageReport = CoverageEngine.buildReport(for: session, split: split)
        try context.save()
    }

    func resumeActiveSession(context: ModelContext) {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.endedAt == nil }
        )
        descriptor.sortBy = [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]

        guard let orphans = try? context.fetch(descriptor), !orphans.isEmpty else { return }

        // Resume the most recent; end any others as orphans.
        let latest = orphans[0]
        activeSession = latest
        selectedSplit = latest.workoutType

        for session in orphans.dropFirst() {
            session.endedAt = session.startedAt
        }
        try? context.save()

        refreshCoverage()
    }

    func abandonWorkout(context: ModelContext) throws {
        guard let session = activeSession else { return }
        // Delete the session and all its logged exercises/sets (cascade).
        context.delete(session)
        try context.save()
        activeSession = nil
        coverageReport = nil
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
        let logged = LoggedExercise(orderIndex: nextIndex, targetWorkingSets: 3, isMarkedDone: false, session: session, exercise: exercise)
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
        cardioDurationMinutes: Double? = nil,
        cardioSpeedDescription: String? = nil,
        cardioZoneDescription: String? = nil,
        pinPosition: String? = nil,
        weightUnit: String = "lbs",
        to loggedExercise: LoggedExercise,
        context: ModelContext
    ) throws {
        guard reps > 0 else { throw TrainError.invalidReps }
        guard weight >= 0 else { throw TrainError.invalidWeight }

        let set = LoggedSet(reps: reps, weight: weight, isWarmup: isWarmup, cardioDurationMinutes: cardioDurationMinutes, cardioSpeedDescription: cardioSpeedDescription, cardioZoneDescription: cardioZoneDescription, pinPosition: pinPosition, weightUnit: weightUnit, loggedExercise: loggedExercise)
        context.insert(set)
        loggedExercise.sets.append(set)
        try context.save()
        refreshCoverage()
    }

    func updateSet(_ set: LoggedSet, reps: Int, weight: Double, isWarmup: Bool, cardioDurationMinutes: Double? = nil, cardioSpeedDescription: String? = nil, cardioZoneDescription: String? = nil, pinPosition: String? = nil, weightUnit: String = "lbs", context: ModelContext) throws {
        guard reps > 0 else { throw TrainError.invalidReps }
        guard weight >= 0 else { throw TrainError.invalidWeight }

        set.reps = reps
        set.weight = weight
        set.isWarmup = isWarmup
        set.cardioDurationMinutes = cardioDurationMinutes
        set.cardioSpeedDescription = cardioSpeedDescription
        set.cardioZoneDescription = cardioZoneDescription
        set.pinPosition = pinPosition
        set.weightUnit = weightUnit
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

    func deleteRoutine(_ routine: WorkoutType, context: ModelContext) throws {
        if let session = activeSession, session.workoutType?.id == routine.id {
            throw TrainError.cannotDeleteActiveRoutine
        }

        if selectedSplit?.id == routine.id {
            selectedSplit = nil
        }

        // The inverse relationship on WorkoutType.sessions auto-nils
        // workoutType on all referencing sessions when this routine is deleted.
        BootstrapService.markRoutineDeleted(routine.name)
        context.delete(routine)
        try context.save()
    }
}

enum TrainError: LocalizedError {
    case exerciseAlreadyAdded
    case invalidReps
    case invalidWeight
    case cannotDeleteActiveRoutine

    var errorDescription: String? {
        switch self {
        case .exerciseAlreadyAdded:
            return "Exercise already exists in this workout."
        case .invalidReps:
            return "Reps must be greater than 0."
        case .invalidWeight:
            return "Weight cannot be negative."
        case .cannotDeleteActiveRoutine:
            return "Cannot delete a routine while it's being used in an active workout."
        }
    }
}
