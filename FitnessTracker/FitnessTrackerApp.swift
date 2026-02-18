import SwiftUI
import SwiftData

@main
struct FitnessTrackerApp: App {
    @StateObject private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            AppBootstrapView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
        }
        .modelContainer(for: [
            WorkoutType.self,
            MuscleGroup.self,
            MuscleRegion.self,
            Exercise.self,
            ExerciseMuscleMap.self,
            WorkoutSession.self,
            LoggedExercise.self,
            LoggedSet.self
        ])
    }
}
