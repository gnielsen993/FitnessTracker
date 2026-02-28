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

                    if tips.isEmpty {
                        ContentUnavailableView(
                            "No insights yet",
                            systemImage: "lightbulb",
                            description: Text("Complete a few workouts and insights will show up here.")
                        )
                    } else {
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
                }
                .padding(.vertical, theme.spacing.l)
                .padding(.horizontal, theme.spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Insights")
        }
    }
}
