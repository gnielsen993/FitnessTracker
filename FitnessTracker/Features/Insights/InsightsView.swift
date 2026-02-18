import SwiftUI
import DesignKit

struct InsightsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    let tips: [InsightTip]

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    DKSectionHeader("Training Insights", subtitle: "Rule-based tips from local data", theme: theme)

                    ForEach(tips) { tip in
                        DKCard(theme: theme) {
                            VStack(alignment: .leading, spacing: theme.spacing.s) {
                                Text(tip.title)
                                    .font(theme.typography.headline)
                                    .foregroundStyle(theme.colors.textPrimary)
                                Text(tip.message)
                                    .font(theme.typography.body)
                                    .foregroundStyle(theme.colors.textSecondary)
                            }
                        }
                    }
                }
                .padding(theme.spacing.l)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Insights")
        }
    }
}
