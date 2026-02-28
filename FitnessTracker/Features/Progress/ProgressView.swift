import SwiftUI
import SwiftData
import Charts
import DesignKit

struct ProgressView: View {
    enum Range: String, CaseIterable, Identifiable {
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"

        var id: String { rawValue }

        var dayCount: Int {
            switch self {
            case .oneMonth: 30
            case .threeMonths: 90
            case .sixMonths: 180
            case .oneYear: 365
            }
        }
    }

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]

    @State private var selectedRange: Range = .threeMonths
    @State private var searchText = ""

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }

    private var filteredSessions: [WorkoutSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -selectedRange.dayCount, to: .now) ?? .distantPast
        return sessions.filter { $0.startedAt >= cutoff }
    }

    private var volumeSeries: [(date: Date, value: Double)] {
        filteredSessions.map { ($0.startedAt, StatsEngine.totalSessionVolume($0)) }
    }

    private var exerciseNames: [String] {
        let all = Set(filteredSessions.flatMap { $0.loggedExercises.compactMap { $0.exercise?.name } })
        let sorted = all.sorted()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.lowercased().contains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    Picker("Range", selection: $selectedRange) {
                        ForEach(Range.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    DKCard(theme: theme) {
                        VStack(alignment: .leading, spacing: theme.spacing.s) {
                            Text("Overall Volume")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colors.textPrimary)

                            if volumeSeries.isEmpty {
                                ContentUnavailableView(
                                    "No progress data",
                                    systemImage: "chart.xyaxis.line",
                                    description: Text("Complete workouts to see your trend over time.")
                                )
                                .frame(height: 180)
                            } else {
                                Chart(volumeSeries, id: \.date) { item in
                                    LineMark(
                                        x: .value("Date", item.date),
                                        y: .value("Volume", item.value)
                                    )
                                    .foregroundStyle(theme.charts.chart1)
                                }
                                .dkChartStyle(theme: theme)
                                .frame(height: 180)
                            }
                        }
                    }

                    DKCard(theme: theme) {
                        VStack(alignment: .leading, spacing: theme.spacing.s) {
                            Text("Exercise Trends")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colors.textPrimary)

                            TextField("Search workout (e.g. Barbell Row)", text: $searchText)
                                .textFieldStyle(.roundedBorder)

                            if exerciseNames.isEmpty {
                                Text("No matching workouts in this date range.")
                                    .font(theme.typography.body)
                                    .foregroundStyle(theme.colors.textSecondary)
                            } else {
                                ForEach(exerciseNames.prefix(8), id: \.self) { name in
                                    exerciseTrendCard(for: name)
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
            .navigationTitle("Progress")
        }
    }

    private func exerciseTrendCard(for exerciseName: String) -> some View {
        let progression = progressionSeries(for: exerciseName)

        return DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                HStack {
                    Text(exerciseName)
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer()
                    if let latest = progression.last?.value {
                        Text("Top e1RM \(Int(latest))")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }

                if progression.isEmpty {
                    Text("No logged sets yet.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                } else {
                    Chart(progression, id: \.date) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("e1RM", point.value)
                        )
                        .foregroundStyle(theme.charts.chart2)

                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("e1RM", point.value)
                        )
                        .foregroundStyle(theme.charts.chart2)
                    }
                    .dkChartStyle(theme: theme)
                    .frame(height: 140)
                }
            }
        }
    }

    private func progressionSeries(for exerciseName: String) -> [(date: Date, value: Double)] {
        filteredSessions.compactMap { session in
            let sets = session.loggedExercises
                .filter { $0.exercise?.name == exerciseName }
                .flatMap(\.sets)
                .filter { !$0.isWarmup }

            guard !sets.isEmpty else { return nil }
            let peak = sets.map { StatsEngine.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            return (date: session.startedAt, value: peak)
        }
    }
}
