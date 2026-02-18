import SwiftUI
import SwiftData

struct AppBootstrapView: View {
    @Environment(\.modelContext) private var modelContext

    private let bootstrapService = BootstrapService()
    private let seedDataService = SeedDataService()

    var body: some View {
        RootTabView()
            .task {
                do {
                    try bootstrapService.bootstrapIfNeeded(context: modelContext)
                    try seedDataService.seedIfNeeded(context: modelContext)
                } catch {
                    assertionFailure("Bootstrap failed: \(error)")
                }
            }
    }
}
