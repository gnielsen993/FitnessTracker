import SwiftUI
import SwiftData
import DesignKit

struct HistoryView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    @State private var displayedMonth = Date()
    @State private var selectedDate: Date?

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }

    private var calendar: Calendar { .current }

    private var sessionsByDay: [Date: [WorkoutSession]] {
        Dictionary(grouping: sessions) { calendar.startOfDay(for: $0.startedAt) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    monthHeader

                    DKCard(theme: theme) {
                        VStack(alignment: .leading, spacing: theme.spacing.s) {
                            weekdayHeader
                            monthGrid
                        }
                    }

                    DKCard(theme: theme) {
                        VStack(alignment: .leading, spacing: theme.spacing.s) {
                            Text("This Month")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colors.textPrimary)

                            let monthSessions = sessionsInDisplayedMonth
                            Text("Sessions: \(monthSessions.count)")
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textSecondary)

                            Text("Active days: \(activeDaysInDisplayedMonth)")
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }
                }
                .padding(.vertical, theme.spacing.l)
                .padding(.horizontal, theme.spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("History")
            .sheet(isPresented: Binding(get: { selectedDate != nil }, set: { if !$0 { selectedDate = nil } })) {
                if let date = selectedDate {
                    DayHistorySheet(
                        date: date,
                        sessions: sessionsByDay[calendar.startOfDay(for: date)] ?? [],
                        theme: theme
                    )
                    .environmentObject(themeManager)
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundStyle(theme.colors.textPrimary)
            }

            Spacer()

            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)

            Spacer()

            Button {
                displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(theme.colors.textPrimary)
            }
        }
        .padding(.horizontal, theme.spacing.s)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortWeekdaySymbols
        return HStack(spacing: theme.spacing.xs) {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let days = daysForDisplayedMonth()

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: theme.spacing.xs), count: 7), spacing: theme.spacing.xs) {
            ForEach(days, id: \.self) { date in
                if calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .frame(height: 38)
                }
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let dayStart = calendar.startOfDay(for: date)
        let daySessions = sessionsByDay[dayStart] ?? []
        let count = daySessions.count
        let intensity = min(1.0, Double(count) / 3.0)

        return Button {
            selectedDate = dayStart
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(count == 0 ? theme.colors.surfaceElevated : theme.colors.accentPrimary.opacity(0.20 + intensity * 0.45))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(theme.colors.border, lineWidth: 1)
                    }

                Text("\(calendar.component(.day, from: date))")
                    .font(theme.typography.body)
                    .foregroundStyle(count == 0 ? theme.colors.textSecondary : theme.colors.textPrimary)
            }
            .frame(height: 38)
        }
        .buttonStyle(.plain)
    }

    private func daysForDisplayedMonth() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end.addingTimeInterval(-1))
        else { return [] }

        var days: [Date] = []
        var current = monthFirstWeek.start

        while current < monthLastWeek.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        return days
    }

    private var sessionsInDisplayedMonth: [WorkoutSession] {
        sessions.filter { calendar.isDate($0.startedAt, equalTo: displayedMonth, toGranularity: .month) }
    }

    private var activeDaysInDisplayedMonth: Int {
        Set(sessionsInDisplayedMonth.map { calendar.startOfDay(for: $0.startedAt) }).count
    }
}

private struct DayHistorySheet: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    let date: Date
    let sessions: [WorkoutSession]
    let theme: Theme

    private var resolvedTheme: Theme {
        themeManager.theme(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: resolvedTheme.spacing.l) {
                    if sessions.isEmpty {
                        DKCard(theme: resolvedTheme) {
                            Text("No workouts logged for this day.")
                                .font(resolvedTheme.typography.body)
                                .foregroundStyle(resolvedTheme.colors.textSecondary)
                        }
                    } else {
                        ForEach(sessions.sorted(by: { $0.startedAt > $1.startedAt })) { session in
                            NavigationLink {
                                SessionDetailView(session: session)
                                    .environmentObject(themeManager)
                            } label: {
                                DKCard(theme: resolvedTheme) {
                                    VStack(alignment: .leading, spacing: resolvedTheme.spacing.s) {
                                        Text(session.workoutType?.name ?? "Workout")
                                            .font(resolvedTheme.typography.headline)
                                            .foregroundStyle(resolvedTheme.colors.textPrimary)

                                        Text(session.startedAt.formatted(date: .omitted, time: .shortened))
                                            .font(resolvedTheme.typography.caption)
                                            .foregroundStyle(resolvedTheme.colors.textSecondary)

                                        Text("Volume \(Int(StatsEngine.totalSessionVolume(session)))")
                                            .font(resolvedTheme.typography.body)
                                            .foregroundStyle(resolvedTheme.colors.textSecondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, resolvedTheme.spacing.l)
                .padding(.horizontal, resolvedTheme.spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(resolvedTheme.colors.background.ignoresSafeArea())
            .navigationTitle(date.formatted(date: .abbreviated, time: .omitted))
        }
    }
}

private struct SessionDetailView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    let session: WorkoutSession

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                DKCard(theme: theme) {
                    VStack(alignment: .leading, spacing: theme.spacing.s) {
                        Text(session.workoutType?.name ?? "Workout")
                            .font(theme.typography.title)
                            .foregroundStyle(theme.colors.textPrimary)
                        Text(session.startedAt.formatted(date: .complete, time: .shortened))
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }

                ForEach(session.loggedExercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { logged in
                    DKCard(theme: theme) {
                        VStack(alignment: .leading, spacing: theme.spacing.s) {
                            Text(logged.exercise?.name ?? "Exercise")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colors.textPrimary)
                            Text("Sets \(logged.sets.count) • Volume \(Int(StatsEngine.exerciseVolume(logged)))")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }
                }
            }
            .padding(.vertical, theme.spacing.l)
            .padding(.horizontal, theme.spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("Session")
    }
}
