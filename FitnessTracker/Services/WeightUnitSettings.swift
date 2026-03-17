import Foundation

enum WeightUnit: String, CaseIterable, Identifiable {
    case lbs
    case kg

    var id: String { rawValue }
    var displayName: String { self == .lbs ? "lbs" : "kg" }
}

enum WeightUnitSettings {
    static let key = "settings.weight.unit"
    static let defaultValue: WeightUnit = .lbs

    static func load(from defaults: UserDefaults = .standard) -> WeightUnit {
        guard let raw = defaults.string(forKey: key), let unit = WeightUnit(rawValue: raw) else {
            return defaultValue
        }
        return unit
    }

    static func save(_ unit: WeightUnit, to defaults: UserDefaults = .standard) {
        defaults.set(unit.rawValue, forKey: key)
    }

    static func convert(_ value: Double, from unit: WeightUnit, to target: WeightUnit) -> Double {
        guard unit != target else { return value }
        switch (unit, target) {
        case (.lbs, .kg):
            return value * 0.45359237
        case (.kg, .lbs):
            return value * 2.2046226218
        default:
            return value
        }
    }
}
