import SwiftUI
import SwiftData
import Charts
import DesignKit

struct HomeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: [SortDescriptor(\WorkoutType.sortOrder), SortDescriptor(\WorkoutType.name)]) private var routines: [WorkoutType]

    @StateObject private var viewModel = DashboardViewModel()
    @State private var showingInsights = false

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }

    private var weekly: WeeklyConsistencySummary { viewModel.weeklyConsistency(from: sessions) }
    private var todayVolume: Int { Int(viewModel.todayVolume(from: sessions)) }
    private var volumeSeries: [(Date, Double)] { sessions.prefix(8).map { ($0.startedAt, StatsEngine.totalSessionVolume($0)) }.reversed() }
    private var consistency: [Bool] { viewModel.consistencyLast7Days(from: sessions) }
    private var sessionsLast7Days: Int { consistency.filter { $0 }.count }


    private var suggestedRoutine: WorkoutType? {
        guard !routines.isEmpty else { return nil }
        let ordered = routines
        let lastRoutineID = sessions.first?.workoutType?.id
        guard let lastRoutineID, let idx = ordered.firstIndex(where: { $0.id == lastRoutineID }) else {
            return ordered.first
        }
        return ordered[(idx + 1) % ordered.count]
    }

    private func startSuggestedWorkout() {
        guard let routine = suggestedRoutine else { return }
        UserDefaults.standard.set(routine.id.uuidString, forKey: AppNavigationSignals.suggestedRoutineIDKey)
        NotificationCenter.default.post(name: AppNavigationSignals.startSuggestedWorkout, object: nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    header
                    startWorkoutCard
                    topStats
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
            Text("Pick up where you left off and keep momentum.")
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary)
        }
    }

    private var startWorkoutCard: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text("Start Workout")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)

                if let suggestedRoutine {
                    Text("Suggested next: \(suggestedRoutine.name)")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)

                    HStack(spacing: theme.spacing.s) {
                        DKButton("Start Suggested", theme: theme) {
                            startSuggestedWorkout()
                        }

                        DKButton("Choose Different", style: .secondary, theme: theme) {
                            NotificationCenter.default.post(name: AppNavigationSignals.startSuggestedWorkout, object: nil)
                        }
                    }
                } else {
                    Text("Create a routine in Settings to start quickly.")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                    DKButton("Go to Train", style: .secondary, theme: theme) {
                        NotificationCenter.default.post(name: AppNavigationSignals.startSuggestedWorkout, object: nil)
                    }
                }
            }
        }
    }

    private var topStats: some View {
        HStack(spacing: theme.spacing.s) {
            metricTile(title: "Weekly", value: "\(weekly.completed)/\(weekly.target)", subtitle: "sessions")
            metricTile(title: "Volume", value: "\(todayVolume)", subtitle: "today")
            metricTile(title: "Active Days", value: "\(sessionsLast7Days)/7", subtitle: "this week")
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
}
