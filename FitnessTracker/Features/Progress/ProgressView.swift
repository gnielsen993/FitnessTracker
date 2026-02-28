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

    @State private var selectedRange: Range = .oneMonth

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

    private var sessionCountSeries: [(date: Date, value: Int)] {
        filteredSessions.map { ($0.startedAt, 1) }
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
                            Text("Session Volume")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colors.textPrimary)

                            if volumeSeries.isEmpty {
                                ContentUnavailableView(
                                    "No progress data",
                                    systemImage: "chart.xyaxis.line",
                                    description: Text("Complete workouts to see your trend over time.")
                                )
                                .frame(height: 220)
                            } else {
                                Chart(volumeSeries, id: \.date) { item in
                                    LineMark(
                                        x: .value("Date", item.date),
                                        y: .value("Volume", item.value)
                                    )
                                    .foregroundStyle(theme.charts.chart1)
                                }
                                .dkChartStyle(theme: theme)
                                .frame(height: 220)
                            }
                        }
                    }

                    DKCard(theme: theme) {
                        VStack(alignment: .leading, spacing: theme.spacing.s) {
                            Text("Session Frequency")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colors.textPrimary)

                            if sessionCountSeries.isEmpty {
                                ContentUnavailableView(
                                    "No frequency data",
                                    systemImage: "calendar",
                                    description: Text("Session bars appear once you log workouts.")
                                )
                                .frame(height: 170)
                            } else {
                                Chart(sessionCountSeries, id: \.date) { item in
                                    BarMark(
                                        x: .value("Date", item.date),
                                        y: .value("Sessions", item.value)
                                    )
                                    .foregroundStyle(theme.charts.chart3)
                                }
                                .dkChartStyle(theme: theme)
                                .frame(height: 170)
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
}
