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

    private var weekly: WeeklyConsistencySummary {
        viewModel.weeklyConsistency(from: sessions)
    }

    private var todayVolume: Int {
        Int(viewModel.todayVolume(from: sessions))
    }

    private var recentSeries: [(Date, Double)] {
        sessions.prefix(8).map { ($0.startedAt, StatsEngine.totalSessionVolume($0)) }.reversed()
    }

    private var streakDays: Int {
        var streak = 0
        let cal = Calendar.current
        for offset in 0..<30 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: .now) else { break }
            let hasSession = sessions.contains { cal.isDate($0.startedAt, inSameDayAs: day) }
            if hasSession { streak += 1 } else if offset > 0 { break }
        }
        return streak
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    header

                    summaryHero

                    metricGrid

                    trendCard

                    splitBalanceCard

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
            .navigationTitle("Summary")
            .sheet(isPresented: $showingInsights) {
                InsightsView(tips: viewModel.tips(from: sessions))
                    .environmentObject(themeManager)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            Text("Today")
                .font(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.textPrimary)
        }
    }

    private var summaryHero: some View {
        DKCard(theme: theme) {
            HStack(spacing: theme.spacing.l) {
                DKProgressRing(
                    progress: weekly.progress,
                    lineWidth: 14,
                    label: "Weekly",
                    theme: theme
                )
                .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: theme.spacing.s) {
                    Text("Move")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)

                    Text("\(weekly.completed)/\(weekly.target)")
                        .font(theme.typography.titleLarge)
                        .foregroundStyle(theme.colors.textPrimary)

                    Text("sessions this week")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)

                    DKBadge("Volume \(todayVolume)", theme: theme)
                }
                Spacer()
            }
        }
    }

    private var metricGrid: some View {
        VStack(spacing: theme.spacing.s) {
            HStack(spacing: theme.spacing.s) {
                metricTile(title: "Today Volume", value: "\(todayVolume)")
                metricTile(title: "Streak", value: "\(streakDays) days")
            }

            HStack(spacing: theme.spacing.s) {
                metricTile(title: "Sessions", value: "\(sessions.count)")
                metricTile(title: "Weekly Goal", value: "\(Int(weekly.progress * 100))%")
            }
        }
    }

    private func metricTile(title: String, value: String) -> some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)

                Text(value)
                    .font(theme.typography.title)
                    .foregroundStyle(theme.colors.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private var trendCard: some View {
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
    }

    private var splitBalanceCard: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text("Recent Split Balance")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)

                let splits = viewModel.splitDistribution(from: sessions)
                if splits.isEmpty {
                    Text("No split data yet")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                } else {
                    ForEach(splits, id: \.name) { item in
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
        }
    }
}
