import XCTest
@testable import FitnessTracker

final class EngineTests: XCTestCase {
    func testEstimatedOneRepMax() {
        let oneRM = StatsEngine.estimatedOneRepMax(weight: 100, reps: 5)
        XCTAssertEqual(oneRM, 116.6666, accuracy: 0.001)
    }

    func testRemainingSessionsNeverNegative() {
        XCTAssertEqual(WeeklyGoalEngine.remainingSessions(target: 3, completed: 5), 0)
    }

    func testCoverageIgnoresWarmupOnlySets() {
        let group = MuscleGroup(name: "Chest", regions: [MuscleRegion(name: "Upper")])
        let split = WorkoutType(name: "Push", includedMuscleGroups: [group])
        let session = WorkoutSession(workoutType: split)

        let exercise = Exercise(name: "Bench", category: "Chest", equipment: "Barbell")
        let map = ExerciseMuscleMap(role: .primary, exercise: exercise, muscleRegion: group.regions[0])
        exercise.muscleMaps = [map]

        let loggedExercise = LoggedExercise(orderIndex: 0, session: session, exercise: exercise)
        loggedExercise.sets = [LoggedSet(reps: 10, weight: 50, isWarmup: true, loggedExercise: loggedExercise)]
        session.loggedExercises = [loggedExercise]

        let report = CoverageEngine.buildReport(for: session, split: split)
        XCTAssertEqual(report.groups.first?.touchedRegions, 0)
    }

    func testInsightEngineReturnsStarterTipWhenNoData() {
        let tips = InsightEngine.tips(from: [])
        XCTAssertEqual(tips.count, 1)
        XCTAssertTrue(tips[0].title.contains("Start"))
    }
}
