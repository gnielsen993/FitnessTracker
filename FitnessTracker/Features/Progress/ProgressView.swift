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

    enum MainLift: String, CaseIterable, Identifiable {
        case bench = "Bench"
        case squat = "Squat"
        case deadlift = "Deadlift"

        var id: String { rawValue }

        var aliases: [String] {
            switch self {
            case .bench:
                return ["bench", "barbell bench press", "bench press"]
            case .squat:
                return ["squat", "back squat", "front squat"]
            case .deadlift:
                return ["deadlift", "romanian deadlift", "conventional deadlift"]
            }
        }
    }

    enum CountdownPreset: String, CaseIterable, Identifiable {
        case oneMonth = "1 month"
        case twoMonths = "2 months"
        case threeMonths = "3 months"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .oneMonth: 30
            case .twoMonths: 60
            case .threeMonths: 90
            }
        }
    }

    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]

    @State private var selectedRange: Range = .threeMonths
    @State private var searchText = ""
    @State private var selectedLift: MainLift = .bench
    @State private var selectedCountdown: CountdownPreset = .oneMonth

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

    private var liftSeries: [(date: Date, value: Double)] {
        filteredSessions.compactMap { session in
            let sets = session.loggedExercises
                .filter { logged in
                    let name = logged.exercise?.name.lowercased() ?? ""
                    return selectedLift.aliases.contains(where: { name.contains($0) })
                }
                .flatMap(\.sets)
                .filter { !$0.isWarmup }

            guard !sets.isEmpty else { return nil }
            let peak = sets.map { StatsEngine.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            return (date: session.startedAt, value: peak)
        }
    }

    private var liftNow: Double {
        liftSeries.last?.value ?? 0
    }

    private var liftStart: Double {
        liftSeries.first?.value ?? 0
    }

    private var liftDeltaPercent: Double {
        guard liftStart > 0 else { return 0 }
        return ((liftNow - liftStart) / liftStart) * 100
    }

    private var targetDate: Date {
        Calendar.current.date(byAdding: .day, value: selectedCountdown.days, to: .now) ?? .now
    }

    private var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: .now, to: targetDate).day ?? 0)
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

                    oneRMHeaderCard

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

    private var oneRMHeaderCard: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                HStack {
                    Text("1RM Focus")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer()
                    Text("\(daysRemaining)d left")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }

                HStack(spacing: theme.spacing.s) {
                    Picker("Lift", selection: $selectedLift) {
                        ForEach(MainLift.allCases) { lift in
                            Text(lift.rawValue).tag(lift)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Countdown", selection: $selectedCountdown) {
                        ForEach(CountdownPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text("Current est. 1RM: \(Int(liftNow))")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textPrimary)
                    Spacer()
                    Text(String(format: "%+.1f%%", liftDeltaPercent))
                        .font(theme.typography.body)
                        .foregroundStyle(liftDeltaPercent >= 0 ? theme.colors.success : theme.colors.danger)
                }

                if liftSeries.isEmpty {
                    Text("No \(selectedLift.rawValue.lowercased()) data yet in selected range.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                } else {
                    Chart(liftSeries, id: \.date) { point in
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
                    .frame(height: 150)
                }
            }
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
