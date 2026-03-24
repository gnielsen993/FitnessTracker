import Foundation

enum RestTimerRuntime {
    private static let endDateKey = "train.restTimer.endDate"

    static func setEndDate(_ date: Date?) {
        let defaults = UserDefaults.standard
        if let date {
            defaults.set(date.timeIntervalSince1970, forKey: endDateKey)
        } else {
            defaults.removeObject(forKey: endDateKey)
        }
    }

    static func endDate() -> Date? {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: endDateKey) != nil else { return nil }
        let ts = defaults.double(forKey: endDateKey)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    static func remainingSeconds(now: Date = .now) -> Int {
        guard let endDate = endDate() else { return 0 }
        return max(0, Int(endDate.timeIntervalSince(now)))
    }
}
