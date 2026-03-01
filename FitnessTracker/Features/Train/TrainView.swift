import SwiftUI
import SwiftData
import DesignKit

struct TrainView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var restDurationSeconds: Double = RestTimerSettings.load()

    @Query(sort: \WorkoutType.name) private var workoutTypes: [WorkoutType]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @StateObject private var viewModel = TrainViewModel()

    @State private var showingExercisePicker = false
    @State private var showingTemplatePicker = false
    @State private var showingCoverageDetails = false
    @State private var setEditorTarget: LoggedExercise?
    @State private var editingSet: LoggedSet?
    @State private var exerciseSearchText = ""
    @State private var expandedExerciseCategories: Set<String> = []
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
                                    exerciseRow(for: logged)
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
            .sheet(isPresented: $showingTemplatePicker) {
                if let split = viewModel.selectedSplit {
                    TemplateEditorSheet(split: split, exercises: exercises)
                        .environmentObject(themeManager)
                }
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
                    set: { if !$0 { setEditorTarget = nil; editingSet = nil } }
                )
            ) {
                if let target = setEditorTarget {
                    setEditorSheet(for: target)
                }
            }
            .onAppear {
                restDurationSeconds = RestTimerSettings.load()
            }
            .onDisappear {
                stopRestTimer()
            }
        }
    }

    // MARK: - Exercise row

    @ViewBuilder
    private func exerciseRow(for logged: LoggedExercise) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            HStack {
                Text(logged.exercise?.name ?? "Exercise")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                Spacer()
                Button("Add Set") {
                    openSetEditor(for: nil, in: logged)
                }
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.accentPrimary)
            }
            .contextMenu {
                Button(role: .destructive) {
                    do {
                        try viewModel.removeExercise(logged, context: modelContext)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } label: {
                    Label("Remove Exercise", systemImage: "trash")
                }
            }

            Text("Sets: \(logged.sets.count) • Volume: \(Int(StatsEngine.exerciseVolume(logged))) lbs")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            let sortedSets = logged.sets.sorted { $0.createdAt < $1.createdAt }
            ForEach(sortedSets) { set in
                Button {
                    openSetEditor(for: set, in: logged)
                } label: {
                    HStack(spacing: theme.spacing.xs) {
                        Text(set.isWarmup ? "W" : "•")
                            .foregroundStyle(set.isWarmup ? theme.colors.textTertiary : theme.colors.accentPrimary)
                        Text("\(String(format: "%g", set.weight)) lbs × \(set.reps)")
                            .foregroundStyle(theme.colors.textPrimary)
                        Spacer()
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .foregroundStyle(theme.colors.textTertiary)
                    }
                    .font(theme.typography.caption)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func openSetEditor(for set: LoggedSet?, in logged: LoggedExercise) {
        if let set {
            editingSet = set
            setReps = String(set.reps)
            setWeight = String(format: "%g", set.weight)
            setIsWarmup = set.isWarmup
        } else {
            editingSet = nil
            // Pre-fill from last logged set for this exercise.
            if let last = logged.sets.sorted(by: { $0.createdAt < $1.createdAt }).last {
                setReps = String(last.reps)
                setWeight = String(format: "%g", last.weight)
                setIsWarmup = last.isWarmup
            } else {
                setReps = "10"
                setWeight = "45"
                setIsWarmup = false
            }
        }
        setEditorTarget = logged
    }

    // MARK: - Split picker

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
                .disabled(viewModel.activeSession != nil)

                if let split = viewModel.selectedSplit, viewModel.activeSession == nil {
                    Button {
                        showingTemplatePicker = true
                    } label: {
                        HStack(spacing: theme.spacing.xs) {
                            Image(systemName: "list.bullet")
                            Text(split.templateExercises.isEmpty
                                 ? "Set Up Template"
                                 : "\(split.templateExercises.count) template exercise\(split.templateExercises.count == 1 ? "" : "s")")
                        }
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.accentPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Workout controls

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

    // MARK: - Rest timer

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

    // MARK: - Exercise picker sheet

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
                        Section {
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: {
                                        !exerciseSearchText.isEmpty || expandedExerciseCategories.contains(group.category)
                                    },
                                    set: { isExpanded in
                                        if isExpanded {
                                            expandedExerciseCategories.insert(group.category)
                                        } else {
                                            expandedExerciseCategories.remove(group.category)
                                        }
                                    }
                                )
                            ) {
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
                                            Text("\(exercise.equipment)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(group.category)
                                    Spacer()
                                    Text("\(group.items.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
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

    // MARK: - Set editor sheet

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

                if let suggestion = progressiveSuggestion(for: loggedExercise) {
                    Section("Progressive Overload") {
                        Text(suggestion.message)
                            .font(.subheadline)

                        if let oneRM = suggestion.estimatedOneRM {
                            Text("Estimated 1RM (Epley): \(Int(oneRM.rounded()))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ForEach(suggestion.recommendations) { rec in
                            HStack {
                                Text("\(rec.reps) reps")
                                Spacer()
                                Text("~\(Int(rec.weight))")
                                    .foregroundStyle(.secondary)
                                Button("Apply") {
                                    applyRecommendation(rec)
                                }
                                .font(.caption)
                            }
                        }
                    }
                }

                if editingSet != nil {
                    Section {
                        Button(role: .destructive) {
                            if let set = editingSet {
                                do {
                                    try viewModel.deleteSet(set, from: loggedExercise, context: modelContext)
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                setEditorTarget = nil
                                editingSet = nil
                            }
                        } label: {
                            Text("Delete Set")
                        }
                    }
                }
            }
            .navigationTitle(editingSet != nil ? "Edit Set" : (loggedExercise.exercise?.name ?? "Add Set"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        setEditorTarget = nil
                        editingSet = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            let reps = Int(setReps) ?? 0
                            let weight = Double(setWeight) ?? 0
                            if let existing = editingSet {
                                try viewModel.updateSet(existing, reps: reps, weight: weight, isWarmup: setIsWarmup, context: modelContext)
                            } else {
                                try viewModel.addSet(
                                    reps: reps,
                                    weight: weight,
                                    isWarmup: setIsWarmup,
                                    to: loggedExercise,
                                    context: modelContext
                                )
                                if !setIsWarmup { startRestTimer() }
                            }
                            setEditorTarget = nil
                            editingSet = nil
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled((Int(setReps) ?? 0) <= 0 || (Double(setWeight) ?? 0) < 0)
                }
            }
        }
    }

    // MARK: - Progressive overload suggestion

    private func progressiveSuggestion(for loggedExercise: LoggedExercise) -> ProgressiveSuggestion? {
        guard let exercise = loggedExercise.exercise else { return nil }

        let activeSessionId = viewModel.activeSession?.id

        // Historical working sets from past sessions (exclude current session).
        let pastSessions = sessions.filter { session in
            guard let activeId = activeSessionId else { return true }
            return session.id != activeId
        }
        let pastLoggedForExercise = pastSessions
            .flatMap { $0.loggedExercises }
            .filter { $0.exercise?.id == exercise.id }
        let historicalSets = pastLoggedForExercise
            .flatMap(\.sets)
            .filter { !$0.isWarmup }
            .sorted { $0.createdAt < $1.createdAt }

        // Working sets already logged this session for this exercise.
        let currentSessionSets = loggedExercise.sets
            .filter { !$0.isWarmup }
            .sorted { $0.createdAt < $1.createdAt }

        let allSets = historicalSets + currentSessionSets
        let latest = allSets.last
        return ProgressiveOverloadEngine.suggestion(
            exercise: exercise,
            latestWorkingSet: latest,
            recentWorkingSets: Array(allSets.suffix(12))
        )
    }

    private func applyRecommendation(_ recommendation: WorkingWeightRecommendation) {
        setReps = String(recommendation.reps)
        setWeight = String(Int(recommendation.weight.rounded()))
    }

    // MARK: - Rest timer helpers

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

// MARK: - Coverage details

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
                                        VStack(alignment: .leading, spacing: theme.spacing.xs) {
                                            HStack {
                                                Image(systemName: region.progress >= 0.75 ? "checkmark.circle.fill" : "circle")
                                                    .foregroundStyle(region.progress >= 0.75 ? theme.colors.success : theme.colors.textTertiary)
                                                Text(region.name)
                                                    .foregroundStyle(theme.colors.textSecondary)
                                                Spacer()
                                                Text("\(region.workingSetCount) sets")
                                                    .font(theme.typography.caption)
                                                    .foregroundStyle(theme.colors.textTertiary)
                                            }

                                            SwiftUI.ProgressView(value: region.progress)
                                                .tint(theme.colors.accentPrimary)

                                            if !region.contributingExercises.isEmpty {
                                                Text(region.contributingExercises.joined(separator: ", "))
                                                    .font(theme.typography.caption)
                                                    .foregroundStyle(theme.colors.textTertiary)
                                            }
                                        }
                                        .padding(.vertical, theme.spacing.xs)
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

// MARK: - Template editor

private struct TemplateEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    let split: WorkoutType
    let exercises: [Exercise]

    @State private var searchText = ""

    private var theme: Theme { themeManager.theme(for: colorScheme) }

    private var filteredExercises: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return exercises }
        return exercises.filter {
            $0.name.lowercased().contains(query) || $0.category.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !split.templateExercises.isEmpty {
                    Section("Current Template") {
                        ForEach(split.templateExercises.sorted { $0.name < $1.name }) { exercise in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                    Text(exercise.category)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(theme.colors.accentPrimary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                split.templateExercises.removeAll { $0.id == exercise.id }
                                try? modelContext.save()
                            }
                        }
                    }
                }

                Section("All Exercises") {
                    ForEach(filteredExercises) { exercise in
                        let isInTemplate = split.templateExercises.contains { $0.id == exercise.id }
                        if !isInTemplate {
                            Button {
                                split.templateExercises.append(exercise)
                                try? modelContext.save()
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                    Text(exercise.category)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Template: \(split.name)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
