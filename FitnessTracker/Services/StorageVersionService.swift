import Foundation

@MainActor
final class StorageVersionService {
    private let defaults: UserDefaults
    private let key = "storage.schema.version"

    /// Bump when local persistence schema changes and migration logic is added.
    let currentVersion: Int = 1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var storedVersion: Int {
        defaults.integer(forKey: key)
    }

    func recordCurrentVersionIfNeeded() {
        if storedVersion != currentVersion {
            defaults.set(currentVersion, forKey: key)
        }
    }
}
