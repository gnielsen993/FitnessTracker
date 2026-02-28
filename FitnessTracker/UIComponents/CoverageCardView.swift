import SwiftUI
import DesignKit

struct CoverageCardView: View {
    let report: CoverageReport
    let theme: Theme

    var body: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text("\(report.splitName) Coverage")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)

                HStack(spacing: theme.spacing.m) {
                    ForEach(report.groups.prefix(3)) { group in
                        VStack(spacing: theme.spacing.xs) {
                            DKProgressRing(
                                progress: progressValue(for: group),
                                lineWidth: 8,
                                label: group.name,
                                theme: theme
                            )
                            .frame(width: 86, height: 86)
                        }
                    }
                }

                ForEach(report.groups) { group in
                    HStack {
                        Text(group.name)
                            .foregroundStyle(theme.colors.textPrimary)
                        Spacer()
                        Text("\(Int(group.progress * 100))%")
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                    .font(theme.typography.body)
                }
            }
        }
    }

    private func progressValue(for group: GroupCoverage) -> Double {
        group.progress
    }
}
