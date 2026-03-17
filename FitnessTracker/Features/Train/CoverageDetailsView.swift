import SwiftUI
import DesignKit

// MARK: - Coverage details

struct CoverageDetailsView: View {
    let report: CoverageReport?
    let theme: Theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.m) {
                    if let report {
                        ForEach(report.groups) { group in
                            DKCard(theme: theme) {
                                VStack(alignment: .leading, spacing: theme.spacing.s) {
                                    Text(group.name)
                                        .font(theme.typography.headline)
                                        .foregroundStyle(theme.colors.textPrimary)
                                    ForEach(group.regions) { region in
                                        VStack(alignment: .leading, spacing: theme.spacing.xs) {
                                            HStack {
                                                Image(systemName: region.progress >= 0.75 ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(region.progress >= 0.75 ? theme.colors.success : theme.colors.textTertiary)
                                                Text(region.name)
                                                    .foregroundStyle(theme.colors.textSecondary)
                                                Spacer()
                                                Text("\(region.workingSetCount) sets")
                                                    .font(theme.typography.caption)
                                                    .foregroundStyle(theme.colors.textTertiary)
                                            }

                                            SwiftUI.ProgressView(value: region.progress)
                                                .tint(theme.colors.accentPrimary)

                                            if !region.contributingExercises.isEmpty {
                                                Text(region.contributingExercises.joined(separator: ", "))
                                                    .font(theme.typography.caption)
                                                    .foregroundStyle(theme.colors.textTertiary)
                                            }
                                        }
                                        .padding(.vertical, theme.spacing.xs)
                                    }
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
            .navigationTitle("Coverage")
        }
    }
}
