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

    func tips(from sessions: [WorkoutSession]) -> [InsightTip] {
        InsightEngine.tips(from: sessions)
    }
}
