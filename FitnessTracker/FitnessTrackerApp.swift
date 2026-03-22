import SwiftUI
import SwiftData

@main
struct FitnessTrackerApp: App {
    @StateObject private var themeManager = ThemeManager()

    let modelContainer: ModelContainer

    init() {
        let schema = Schema([
            WorkoutType.self,
            MuscleGroup.self,
            MuscleRegion.self,
            Exercise.self,
            ExerciseMuscleMap.self,
            WorkoutSession.self,
            LoggedExercise.self,
            LoggedSet.self,
            TemplateExercise.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            modelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema migration failed — delete the old store and recreate.
            // This is acceptable at POC stage where data was already not persisting.
            let url = config.url
            let related = [url, url.appendingPathExtension("wal"), url.appendingPathExtension("shm")]
            for file in related {
                try? FileManager.default.removeItem(at: file)
            }
            // Also reset the seed flag so data gets re-seeded.
            UserDefaults.standard.removeObject(forKey: "seed.v1.completed")
            do {
                modelContainer = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppBootstrapView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.preferredColorScheme)
        }
        .modelContainer(modelContainer)
    }
}
