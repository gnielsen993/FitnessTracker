import Foundation

struct InsightTip: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct WeeklyConsistencySummary {
    let completed: Int
    let target: Int
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(completed) / Double(target))
    }
}

enum InsightEngine {
    static func weeklyConsistency(
        sessions: [WorkoutSession],
        target: Int = 4,
        calendar: Calendar = .current,
        referenceDate: Date = .now
    ) -> WeeklyConsistencySummary {
        let completed = WeeklyGoalEngine.completedSessionsThisWeek(
            sessions: sessions,
            calendar: calendar,
            referenceDate: referenceDate
        )
        return WeeklyConsistencySummary(completed: completed, target: target)
    }

    static func tips(from sessions: [WorkoutSession]) -> [InsightTip] {
        guard !sessions.isEmpty else {
            return [
                InsightTip(
                    title: "Start Your Baseline",
                    message: "Log your first workout to unlock consistency and coverage insights."
                )
            ]
        }

        let sorted = sessions.sorted { $0.startedAt < $1.startedAt }
        let recent = sorted.suffix(4)
        let averageVolume = recent
            .map(StatsEngine.totalSessionVolume)
            .reduce(0, +) / Double(recent.count)

        let consistency = weeklyConsistency(sessions: sessions)
        var items: [InsightTip] = []

        if consistency.completed < consistency.target {
            items.append(
                InsightTip(
                    title: "Consistency Opportunity",
                    message: "You are \(consistency.completed)/\(consistency.target) sessions this week. Add one short session to stay on track."
                )
            )
        } else {
            items.append(
                InsightTip(
                    title: "Consistency Strong",
                    message: "You already hit your weekly session target. Focus on quality reps and recovery today."
                )
            )
        }

        if averageVolume > 0 {
            items.append(
                InsightTip(
                    title: "Volume Trend",
                    message: "Your recent average session volume is \(Int(averageVolume.rounded())). Keep load increases gradual for stable progress."
                )
            )
        }

        let ended = sessions.filter { $0.endedAt != nil }.count
        if ended < sessions.count {
            items.append(
                InsightTip(
                    title: "Session Hygiene",
                    message: "Some sessions are still active. End sessions after training for cleaner history and better weekly analytics."
                )
            )
        }

        return items
    }
}
