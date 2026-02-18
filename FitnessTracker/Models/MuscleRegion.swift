import Foundation
import SwiftData

@Model
final class MuscleRegion {
    @Attribute(.unique) var id: UUID
    var name: String

    var group: MuscleGroup?

    init(
        id: UUID = UUID(),
        name: String,
        group: MuscleGroup? = nil
    ) {
        self.id = id
        self.name = name
        self.group = group
    }
}
