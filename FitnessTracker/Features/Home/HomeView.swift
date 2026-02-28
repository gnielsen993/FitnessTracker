import SwiftUI
import SwiftData
import Charts
import DesignKit

struct HomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @StateObject private var viewModel = DashboardViewModel()
    @State private var showingInsights = false

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }

    private var recentSeries: [(Date, Double)] {
        sessions.prefix(8).map { ($0.startedAt, StatsEngine.totalSessionVolume($0)) }.reversed()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    DKSectionHeader(
                        "Today",
                        subtitle: "Local-first performance dashboard",
                        theme: theme
                    )

                    DKCard(theme: theme) {
                        HStack(spacing: theme.spacing.l) {
                            DKProgressRing(
                                progress: viewModel.weeklyConsistency(from: sessions).progress,
                                label: "Weekly",
                                theme: theme
                            )
                            .frame(width: 120, height: 120)

                            VStack(alignment: .leading, spacing: theme.spacing.s) {
                                Text("\(Int(viewModel.todayVolume(from: sessions)))")
                                    .font(theme.typography.titleLarge)
                                    .foregroundStyle(theme.colors.textPrimary)
                                Text("Today Volume")
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colors.textSecondary)

                                let weekly = viewModel.weeklyConsistency(from: sessions)
                                DKBadge("\(weekly.completed)/\(weekly.target) sessions", theme: theme)
                            }
                        }
                    }

                    DKCard(theme: theme) {
                        VStack(alignment: .leading, spacing: theme.spacing.s) {
                            Text("Volume Trend")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colors.textPrimary)

                            if recentSeries.isEmpty {
                                ContentUnavailableView(
                                    "No sessions yet",
                                    systemImage: "chart.line.uptrend.xyaxis",
                                    description: Text("Log your first workout to unlock trend charts.")
                                )
                                .frame(height: 170)
                            } else {
                                Chart(recentSeries, id: \.0) { item in
                                    AreaMark(
                                        x: .value("Date", item.0),
                                        y: .value("Volume", item.1)
                                    )
                                    .foregroundStyle(theme.charts.chart2.opacity(0.18))

                                    LineMark(
                                        x: .value("Date", item.0),
                                        y: .value("Volume", item.1)
                                    )
                                    .foregroundStyle(theme.charts.chart1)
                                }
                                .dkChartStyle(theme: theme)
                                .frame(height: 170)
                            }
                        }
                    }

                    DKCard(theme: theme) {
                        VStack(alignment: .leading, spacing: theme.spacing.s) {
                            Text("Recent Split Balance")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colors.textPrimary)

                            ForEach(viewModel.splitDistribution(from: sessions), id: \.name) { item in
                                HStack {
                                    Text(item.name)
                                        .foregroundStyle(theme.colors.textPrimary)
                                    Spacer()
                                    Text("\(item.count)")
                                        .foregroundStyle(theme.colors.textSecondary)
                                }
                                .font(theme.typography.body)
                            }
                        }
                    }

                    DKButton("View Insights", style: .secondary, theme: theme) {
                        showingInsights = true
                    }
                    .accessibilityLabel("Open training insights")
                }
                .padding(.vertical, theme.spacing.l)
                .padding(.horizontal, theme.spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Home")
            .sheet(isPresented: $showingInsights) {
                InsightsView(tips: viewModel.tips(from: sessions))
                    .environmentObject(themeManager)
            }
        }
    }
}
