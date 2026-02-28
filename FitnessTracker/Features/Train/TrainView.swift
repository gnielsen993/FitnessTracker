import SwiftUI
import SwiftData
import DesignKit

struct TrainView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("train.rest.seconds") private var restDurationSeconds: Double = 90

    @Query(sort: \WorkoutType.name) private var workoutTypes: [WorkoutType]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @StateObject private var viewModel = TrainViewModel()

    @State private var showingExercisePicker = false
    @State private var showingCoverageDetails = false
    @State private var setEditorTarget: LoggedExercise?
    @State private var exerciseSearchText = ""
    @State private var setReps = "10"
    @State private var setWeight = "45"
    @State private var setIsWarmup = false
    @State private var errorMessage: String?

    @State private var restRemainingSeconds = 0
    @State private var restTimer: Timer?

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }

    private var groupedFilteredExercises: [(category: String, items: [Exercise])] {
        let query = exerciseSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = exercises.filter { exercise in
            guard !query.isEmpty else { return true }
            return exercise.name.lowercased().contains(query)
                || exercise.category.lowercased().contains(query)
                || exercise.equipment.lowercased().contains(query)
        }

        let grouped = Dictionary(grouping: filtered) { $0.category }
        return grouped.keys.sorted().map { key in
            (category: key, items: grouped[key]?.sorted(by: { $0.name < $1.name }) ?? [])
        }
    }

    private var formattedRest: String {
        let minutes = restRemainingSeconds / 60
        let seconds = restRemainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    splitPicker

                    if let report = viewModel.coverageReport {
                        Button {
                            showingCoverageDetails = true
                        } label: {
                            CoverageCardView(report: report, theme: theme)
                        }
                        .buttonStyle(.plain)
                    }

                    workoutControls

                    if viewModel.activeSession != nil {
                        restCard
                    }

                    if let session = viewModel.activeSession {
                        DKCard(theme: theme) {
                            VStack(alignment: .leading, spacing: theme.spacing.m) {
                                Text("Logged Exercises")
                                    .font(theme.typography.headline)
                                    .foregroundStyle(theme.colors.textPrimary)

                                if session.loggedExercises.isEmpty {
                                    Text("Add an exercise to begin logging sets.")
                                        .font(theme.typography.body)
                                        .foregroundStyle(theme.colors.textSecondary)
                                }

                                ForEach(session.loggedExercises.sorted(by: { $0.orderIndex < $1.orderIndex })) { logged in
                                    VStack(alignment: .leading, spacing: theme.spacing.s) {
                                        HStack {
                                            Text(logged.exercise?.name ?? "Exercise")
                                                .foregroundStyle(theme.colors.textPrimary)
                                            Spacer()
                                            Button("Add Set") {
                                                setEditorTarget = logged
                                                setReps = "10"
                                                setWeight = "45"
                                                setIsWarmup = false
                                            }
                                            .font(theme.typography.caption)
                                            .foregroundStyle(theme.colors.accentPrimary)
                                        }

                                        Text("Sets: \(logged.sets.count) • Volume: \(Int(StatsEngine.exerciseVolume(logged)))")
                                            .font(theme.typography.caption)
                                            .foregroundStyle(theme.colors.textSecondary)
                                    }
                                    .padding(.vertical, theme.spacing.xs)
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
            .navigationTitle("Train")
            .sheet(isPresented: $showingExercisePicker) {
                exercisePickerSheet
            }
            .sheet(isPresented: $showingCoverageDetails) {
                CoverageDetailsView(report: viewModel.coverageReport, theme: theme)
            }
            .alert("Workout Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .sheet(
                isPresented: Binding(
                    get: { setEditorTarget != nil },
                    set: { if !$0 { setEditorTarget = nil } }
                )
            ) {
                if let target = setEditorTarget {
                    setEditorSheet(for: target)
                }
            }
            .onDisappear {
                stopRestTimer()
            }
        }
    }

    private var splitPicker: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text("Split")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)

                Picker("Workout Type", selection: $viewModel.selectedSplit) {
                    Text("Select Split").tag(Optional<WorkoutType>.none)
                    ForEach(workoutTypes) { split in
                        Text(split.name).tag(Optional(split))
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var workoutControls: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.m) {
                HStack(spacing: theme.spacing.s) {
                    DKButton(
                        viewModel.activeSession == nil ? "Start Workout" : "End Workout",
                        theme: theme,
                        isEnabled: viewModel.activeSession != nil || viewModel.selectedSplit != nil
                    ) {
                        do {
                            if viewModel.activeSession == nil {
                                guard let split = viewModel.selectedSplit else { return }
                                try viewModel.startWorkout(using: split, context: modelContext)
                                startRestTimer()
                            } else {
                                try viewModel.endWorkout(context: modelContext)
                                stopRestTimer()
                            }
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }

                    if viewModel.activeSession != nil {
                        DKButton("Add Exercise", style: .secondary, theme: theme) {
                            showingExercisePicker = true
                        }
                    }
                }

                if viewModel.activeSession != nil {
                    Text("Coverage updates instantly as you log working sets.")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }
        }
    }

    private var restCard: some View {
        DKCard(theme: theme) {
            HStack(spacing: theme.spacing.m) {
                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                    Text("Rest Timer")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                    Text("Auto-start: \(Int(restDurationSeconds)) sec")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                Spacer()
                Text(formattedRest)
                    .font(theme.typography.title)
                    .foregroundStyle(theme.colors.accentPrimary)

                Button(restRemainingSeconds > 0 ? "Reset" : "Start") {
                    startRestTimer()
                }
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.accentPrimary)
            }
        }
    }

    private var exercisePickerSheet: some View {
        NavigationStack {
            List {
                if groupedFilteredExercises.isEmpty {
                    ContentUnavailableView(
                        "No matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try another workout name or category.")
                    )
                } else {
                    ForEach(groupedFilteredExercises, id: \.category) { group in
                        Section(group.category) {
                            ForEach(group.items) { exercise in
                                Button {
                                    do {
                                        try viewModel.addExercise(exercise, context: modelContext)
                                        showingExercisePicker = false
                                    } catch {
                                        errorMessage = error.localizedDescription
                                    }
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(exercise.name)
                                        Text("\(exercise.category) • \(exercise.equipment)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $exerciseSearchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Close") {
                        exerciseSearchText = ""
                        showingExercisePicker = false
                    }
                }
            }
        }
    }

    private func setEditorSheet(for loggedExercise: LoggedExercise) -> some View {
        NavigationStack {
            Form {
                Section("Set") {
                    TextField("Reps", text: $setReps)
#if os(iOS)
                        .keyboardType(.numberPad)
#endif
                    TextField("Weight", text: $setWeight)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                    Toggle("Warm-up Set", isOn: $setIsWarmup)
                }
            }
            .navigationTitle(loggedExercise.exercise?.name ?? "Set")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { setEditorTarget = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            let reps = Int(setReps) ?? 0
                            let weight = Double(setWeight) ?? 0
                            try viewModel.addSet(
                                reps: reps,
                                weight: weight,
                                isWarmup: setIsWarmup,
                                to: loggedExercise,
                                context: modelContext
                            )
                            setEditorTarget = nil
                            if !setIsWarmup { startRestTimer() }
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled((Int(setReps) ?? 0) <= 0 || (Double(setWeight) ?? 0) < 0)
                }
            }
        }
    }

    private func startRestTimer() {
        stopRestTimer()
        restRemainingSeconds = Int(restDurationSeconds)
        guard restRemainingSeconds > 0 else { return }

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if restRemainingSeconds > 0 {
                restRemainingSeconds -= 1
            } else {
                timer.invalidate()
            }
        }
    }

    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
    }
}

private struct CoverageDetailsView: View {
    let report: CoverageReport?
    let theme: Theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.m) {
                    if let report {
                        ForEach(report.groups) { group in
                            DKCard(theme: theme) {
                                VStack(alignment: .leading, spacing: theme.spacing.s) {
                                    Text(group.name)
                                        .font(theme.typography.headline)
                                        .foregroundStyle(theme.colors.textPrimary)
                                    ForEach(group.regions) { region in
                                        HStack {
                                            Image(systemName: region.touched ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(region.touched ? theme.colors.success : theme.colors.textTertiary)
                                            Text(region.name)
                                                .foregroundStyle(theme.colors.textSecondary)
                                        }
                                    }
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
            .navigationTitle("Coverage")
        }
    }
}
