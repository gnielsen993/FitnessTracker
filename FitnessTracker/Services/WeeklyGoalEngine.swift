import Foundation

enum WeeklyGoalEngine {
    static func completedSessionsThisWeek(
        sessions: [WorkoutSession],
        calendar: Calendar = .current,
        referenceDate: Date = .now
    ) -> Int {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return 0
        }

        return sessions.filter { weekInterval.contains($0.startedAt) }.count
    }

    static func remainingSessions(target: Int, completed: Int) -> Int {
        max(0, target - completed)
    }
}
