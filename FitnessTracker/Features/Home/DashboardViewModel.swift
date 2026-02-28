import Foundation
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    let weeklyTarget = 4

    func todayVolume(from sessions: [WorkoutSession], calendar: Calendar = .current) -> Double {
        let today = sessions.filter { calendar.isDateInToday($0.startedAt) }
        return today.map(StatsEngine.totalSessionVolume).reduce(0, +)
    }

    func weeklyConsistency(from sessions: [WorkoutSession]) -> WeeklyConsistencySummary {
        InsightEngine.weeklyConsistency(sessions: sessions, target: weeklyTarget)
    }

    func splitDistribution(from sessions: [WorkoutSession], limit: Int = 6) -> [(name: String, count: Int)] {
        let recent = sessions.sorted { $0.startedAt > $1.startedAt }.prefix(limit)
        let counts = Dictionary(grouping: recent) { $0.workoutType?.name ?? "Unknown" }
            .mapValues(\.count)
        return counts
            .map { ($0.key, $0.value) }
            .sorted { $0.count > $1.count }
    }

    func strengthTrend(from sessions: [WorkoutSession], limit: Int = 8) -> [(date: Date, value: Double)] {
        sessions
            .sorted { $0.startedAt < $1.startedAt }
            .suffix(limit)
            .map { session in
                let sets = session.loggedExercises.flatMap(\.sets).filter { !$0.isWarmup }
                let peak = sets.map { StatsEngine.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
                return (session.startedAt, peak)
            }
    }

    func strengthDeltaThisWeek(from sessions: [WorkoutSession], calendar: Calendar = .current) -> Double {
        let sorted = strengthTrend(from: sessions, limit: 20)
        guard sorted.count >= 2 else { return 0 }

        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let recent = sorted.filter { $0.date >= weekAgo }

        guard let latest = recent.last?.value else { return 0 }
        let baseline = sorted.first(where: { $0.date < weekAgo })?.value ?? sorted.dropLast().last?.value ?? latest
        guard baseline > 0 else { return 0 }
        return ((latest - baseline) / baseline) * 100
    }

    func consistencyLast7Days(from sessions: [WorkoutSession], calendar: Calendar = .current) -> [Bool] {
        (0..<7).reversed().map { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: .now) else { return false }
            return sessions.contains { calendar.isDate($0.startedAt, inSameDayAs: day) }
        }
    }

    func tips(from sessions: [WorkoutSession]) -> [InsightTip] {
        InsightEngine.tips(from: sessions)
    }
}
