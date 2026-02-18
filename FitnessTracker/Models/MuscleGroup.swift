import Foundation
import SwiftData

@Model
final class MuscleGroup {
    @Attribute(.unique) var id: UUID
    var name: String

    @Relationship(deleteRule: .cascade, inverse: \MuscleRegion.group) var regions: [MuscleRegion]

    init(
        id: UUID = UUID(),
        name: String,
        regions: [MuscleRegion] = []
    ) {
        self.id = id
        self.name = name
        self.regions = regions
    }
}
