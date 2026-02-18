import SwiftUI
import SwiftData
import DesignKit

struct HistoryView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    if sessions.isEmpty {
                        DKCard(theme: theme) {
                            Text("No sessions yet. Start your first workout in Train.")
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }

                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                                .environmentObject(themeManager)
                        } label: {
                            DKCard(theme: theme) {
                                VStack(alignment: .leading, spacing: theme.spacing.s) {
                                    HStack {
                                        Text(session.workoutType?.name ?? "Workout")
                                            .font(theme.typography.headline)
                                            .foregroundStyle(theme.colors.textPrimary)
                                        Spacer()
                                        if session.endedAt == nil {
                                            DKBadge("Active", theme: theme)
                                        }
                                    }

                                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(theme.typography.caption)
                                        .foregroundStyle(theme.colors.textSecondary)

                                    Text("Volume \(Int(StatsEngine.totalSessionVolume(session)))")
                                        .font(theme.typography.body)
                                        .foregroundStyle(theme.colors.textSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(theme.spacing.l)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("History")
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
            .padding(theme.spacing.l)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("Session")
    }
}
