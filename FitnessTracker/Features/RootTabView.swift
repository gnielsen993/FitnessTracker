import SwiftUI
import SwiftData
import DesignKit

struct RootTabView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var selectedTab: Int = 0
    @State private var now: Date = .now

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }

    private var activeSession: WorkoutSession? {
        sessions.first(where: { $0.endedAt == nil })
    }

    private var lastLoggedExerciseName: String {
        guard let session = activeSession else { return "Workout" }
        let sorted = session.loggedExercises.sorted(by: { $0.orderIndex < $1.orderIndex })
        let current = sorted
            .filter { !$0.sets.isEmpty }
            .max(by: { ($0.sets.map(\.createdAt).max() ?? .distantPast) < ($1.sets.map(\.createdAt).max() ?? .distantPast) })
            ?? sorted.first
        return current?.exercise?.name ?? "Workout"
    }

    private var timerRemaining: Int {
        RestTimerRuntime.remainingSeconds(now: now)
    }

    private var timerFormatted: String {
        let minutes = timerRemaining / 60
        let seconds = timerRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            TrainView()
                .tabItem { Label("Train", systemImage: "figure.strengthtraining.traditional") }
                .tag(1)

            HistoryView()
                .tabItem { Label("History", systemImage: "calendar") }
                .tag(2)

            ProgressView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(3)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(4)
        }
        .overlay(alignment: .bottom) {
            if let session = activeSession, selectedTab != 1 {
                activeWorkoutBar(session: session)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 56)
            }
        }

        .onAppear {
            WorkoutActivityManager.shared.cleanupOrphanedActivities(hasActiveWorkout: activeSession != nil)
            if activeSession == nil {
                RestTimerRuntime.setEndDate(nil)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }

        .onReceive(NotificationCenter.default.publisher(for: AppNavigationSignals.startSuggestedWorkout)) { _ in
            selectedTab = 1
        }
        .tint(theme.colors.accentPrimary)
    }

    @ViewBuilder
    private func activeWorkoutBar(session: WorkoutSession) -> some View {
        Button {
            selectedTab = 1
        } label: {
            HStack(spacing: 10) {
                Image(systemName: timerRemaining > 0 ? "timer" : "figure.strengthtraining.traditional")
                    .foregroundStyle(theme.colors.accentPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.workoutType?.name ?? "Current Workout")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("Resume: \(lastLoggedExerciseName)")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }

                Spacer()

                if timerRemaining > 0 {
                    Text(timerFormatted)
                        .font(theme.typography.headline)
                        .monospacedDigit()
                        .foregroundStyle(theme.colors.textPrimary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(theme.colors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(theme.colors.surfaceElevated)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}
