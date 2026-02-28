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

    private var weekly: WeeklyConsistencySummary { viewModel.weeklyConsistency(from: sessions) }
    private var todayVolume: Int { Int(viewModel.todayVolume(from: sessions)) }
    private var strengthSeries: [(date: Date, value: Double)] { viewModel.strengthTrend(from: sessions) }
    private var volumeSeries: [(Date, Double)] { sessions.prefix(8).map { ($0.startedAt, StatsEngine.totalSessionVolume($0)) }.reversed() }
    private var consistency: [Bool] { viewModel.consistencyLast7Days(from: sessions) }
    private var strengthDelta: Double { viewModel.strengthDeltaThisWeek(from: sessions) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    header

                    topStats

                    strengthCard

                    volumeCard

                    consistencyCard

                    splitBalanceCard

                    DKButton("View Insights", style: .secondary, theme: theme) {
                        showingInsights = true
                    }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
            Text("Performance Lab")
                .font(theme.typography.titleLarge)
                .foregroundStyle(theme.colors.textPrimary)
            Text("Train with data, not vibes.")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    private var topStats: some View {
        HStack(spacing: theme.spacing.s) {
            metricTile(title: "Weekly", value: "\(weekly.completed)/\(weekly.target)", subtitle: "sessions")
            metricTile(title: "Volume", value: "\(todayVolume)", subtitle: "today")
            metricTile(title: "Strength", value: formattedDelta(strengthDelta), subtitle: "7d")
        }
    }

    private func metricTile(title: String, value: String, subtitle: String) -> some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text(title)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                Text(value)
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                Text(subtitle)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private var strengthCard: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                HStack {
                    Text("Strength Trend")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer()
                    Text(formattedDelta(strengthDelta))
                        .font(theme.typography.body)
                        .foregroundStyle(strengthDelta >= 0 ? theme.colors.success : theme.colors.danger)
                }

                if strengthSeries.isEmpty {
                    ContentUnavailableView("No strength data", systemImage: "chart.line.uptrend.xyaxis", description: Text("Log weighted sets to chart progress."))
                        .frame(height: 160)
                } else {
                    Chart(strengthSeries, id: \.date) { item in
                        LineMark(x: .value("Date", item.date), y: .value("e1RM", item.value))
                            .foregroundStyle(theme.charts.chart1)
                        AreaMark(x: .value("Date", item.date), y: .value("e1RM", item.value))
                            .foregroundStyle(theme.charts.chart1.opacity(0.15))
                    }
                    .dkChartStyle(theme: theme)
                    .frame(height: 160)
                }
            }
        }
    }

    private var volumeCard: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text("Volume Trend")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)

                if volumeSeries.isEmpty {
                    ContentUnavailableView("No volume data", systemImage: "waveform.path.ecg", description: Text("Finish sessions to visualize workload."))
                        .frame(height: 140)
                } else {
                    Chart(volumeSeries, id: \.0) { item in
                        BarMark(x: .value("Date", item.0), y: .value("Volume", item.1))
                            .foregroundStyle(theme.charts.chart3)
                    }
                    .dkChartStyle(theme: theme)
                    .frame(height: 140)
                }
            }
        }
    }

    private var consistencyCard: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text("7-Day Consistency")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)

                HStack(spacing: theme.spacing.xs) {
                    ForEach(Array(consistency.enumerated()), id: \.offset) { _, hit in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(hit ? theme.colors.accentPrimary : theme.colors.surfaceElevated)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(theme.colors.border, lineWidth: 1)
                            }
                            .frame(height: 14)
                    }
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

    private func formattedDelta(_ delta: Double) -> String {
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(Int(delta.rounded()))%"
    }
}
