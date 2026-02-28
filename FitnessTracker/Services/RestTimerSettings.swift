import Foundation

enum RestTimerSettings {
    static let key = "train.rest.seconds"
    static let defaultValue: Double = 90

    static func load(from defaults: UserDefaults = .standard) -> Double {
        if let value = defaults.object(forKey: key) as? NSNumber {
            return clamp(value.doubleValue)
        }
        if let value = defaults.object(forKey: key) as? String,
           let parsed = Double(value) {
            return clamp(parsed)
        }
        return defaultValue
    }

    static func save(_ seconds: Double, to defaults: UserDefaults = .standard) {
        defaults.set(clamp(seconds), forKey: key)
    }

    private static func clamp(_ value: Double) -> Double {
        min(300, max(30, value))
    }
}
