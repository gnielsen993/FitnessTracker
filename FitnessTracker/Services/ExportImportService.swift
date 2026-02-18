import Foundation
import SwiftData

struct WorkoutExportBundle: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let sessions: [WorkoutSessionDTO]
}

struct WorkoutSessionDTO: Codable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let notes: String
    let workoutTypeName: String
    let exercises: [LoggedExerciseDTO]
}

struct LoggedExerciseDTO: Codable {
    let name: String
    let orderIndex: Int
    let sets: [LoggedSetDTO]
}

struct LoggedSetDTO: Codable {
    let reps: Int
    let weight: Double
    let isWarmup: Bool
    let createdAt: Date
}

final class ExportImportService {
    private let schemaVersion = 1
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = encoder
        self.decoder = decoder
    }

    func exportData(from sessions: [WorkoutSession]) throws -> Data {
        let sessionDTOs = sessions.map { session in
            WorkoutSessionDTO(
                id: session.id,
                startedAt: session.startedAt,
                endedAt: session.endedAt,
                notes: session.notes,
                workoutTypeName: session.workoutType?.name ?? "Unknown",
                exercises: session.loggedExercises.sorted { $0.orderIndex < $1.orderIndex }.map { logged in
                    LoggedExerciseDTO(
                        name: logged.exercise?.name ?? "Unknown",
                        orderIndex: logged.orderIndex,
                        sets: logged.sets.map { set in
                            LoggedSetDTO(
                                reps: set.reps,
                                weight: set.weight,
                                isWarmup: set.isWarmup,
                                createdAt: set.createdAt
                            )
                        }
                    )
                }
            )
        }

        let bundle = WorkoutExportBundle(
            schemaVersion: schemaVersion,
            exportedAt: .now,
            sessions: sessionDTOs
        )

        return try encoder.encode(bundle)
    }

    func importData(_ data: Data, into context: ModelContext, availableWorkoutTypes: [WorkoutType], availableExercises: [Exercise]) throws {
        let bundle = try decoder.decode(WorkoutExportBundle.self, from: data)
        guard bundle.schemaVersion == schemaVersion else {
            throw ImportError.unsupportedSchema(bundle.schemaVersion)
        }

        let typeIndex = Dictionary(uniqueKeysWithValues: availableWorkoutTypes.map { ($0.name, $0) })
        let exerciseIndex = Dictionary(uniqueKeysWithValues: availableExercises.map { ($0.name, $0) })

        for importedSession in bundle.sessions {
            let session = WorkoutSession(
                id: importedSession.id,
                startedAt: importedSession.startedAt,
                endedAt: importedSession.endedAt,
                notes: importedSession.notes,
                workoutType: typeIndex[importedSession.workoutTypeName]
            )
            context.insert(session)

            for importedExercise in importedSession.exercises {
                let logged = LoggedExercise(
                    orderIndex: importedExercise.orderIndex,
                    session: session,
                    exercise: exerciseIndex[importedExercise.name]
                )
                context.insert(logged)

                for importedSet in importedExercise.sets {
                    let set = LoggedSet(
                        reps: importedSet.reps,
                        weight: importedSet.weight,
                        isWarmup: importedSet.isWarmup,
                        createdAt: importedSet.createdAt,
                        loggedExercise: logged
                    )
                    context.insert(set)
                }

                session.loggedExercises.append(logged)
            }
        }

        try context.save()
    }
}

enum ImportError: Error {
    case unsupportedSchema(Int)
}
