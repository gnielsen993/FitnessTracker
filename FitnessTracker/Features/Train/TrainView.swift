import SwiftUI
import SwiftData
import DesignKit

struct TrainView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var restDurationSeconds: Double = RestTimerSettings.load()

    @Query(sort: \WorkoutType.name) private var workoutTypes: [WorkoutType]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @StateObject private var viewModel = TrainViewModel()

    @State private var showingExercisePicker = false
    @State private var showingTemplatePicker = false
    @State private var showingCoverageDetails = false
    @State private var showingNewRoutineSheet = false
    @State private var newRoutineName = ""
    @State private var exerciseSearchText = ""
    @State private var expandedExerciseCategories: Set<String> = []
    @State private var selectedWeightUnit: WeightUnit = WeightUnitSettings.load()
    @State private var errorMessage: String?
    @State private var showingConverter = false
    @State private var pendingTemplateEdit = false
    @State private var routineToDelete: WorkoutType?

    @State private var restRemainingSeconds = 0
    @State private var restTimer: Timer?
    @State private var restTimerEndDate: Date?

    private let lastRoutineDefaultsKey = "train.lastRoutineID"

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }

    private var groupedFilteredExercises: [(category: String, items: [Exercise])] {
        exercises.groupedByCategory(filter: exerciseSearchText)
    }

    /// Exercises sorted: incomplete first by orderIndex, then completed by orderIndex.
    private var sortedLoggedExercises: [LoggedExercise] {
        guard let session = viewModel.activeSession else { return [] }
        let all = session.loggedExercises.sorted(by: { $0.orderIndex < $1.orderIndex })
        let incomplete = all.filter { !isExerciseCompleted($0) }
        let completed = all.filter { isExerciseCompleted($0) }
        return incomplete + completed
    }

    private var formattedRest: String {
        let minutes = restRemainingSeconds / 60
        let seconds = restRemainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
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

                        // Workout notes
                        if let session = viewModel.activeSession {
                            DKCard(theme: theme) {
                                DisclosureGroup {
                                    TextEditor(text: Binding(
                                        get: { session.notes },
                                        set: { session.notes = $0; try? modelContext.save() }
                                    ))
                                    .frame(minHeight: 60)
                                    .font(theme.typography.body)
                                    .scrollContentBackground(.hidden)
                                } label: {
                                    Text("Notes")
                                        .font(theme.typography.headline)
                                        .foregroundStyle(theme.colors.textPrimary)
                                }
                            }
                        }

                        // Consolidated exercise master list
                        if let session = viewModel.activeSession {
                            DKCard(theme: theme) {
                                VStack(alignment: .leading, spacing: theme.spacing.m) {
                                    HStack {
                                        Text("Exercises")
                                            .font(theme.typography.headline)
                                            .foregroundStyle(theme.colors.textPrimary)
                                        Spacer()
                                        Text("\(completedExerciseCount)/\(totalExerciseCount) done")
                                            .font(theme.typography.caption)
                                            .foregroundStyle(theme.colors.textSecondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule()
                                                    .fill(theme.colors.surfaceElevated)
                                            )
                                    }

                                    if let current = currentExercise {
                                        Text("Current: \(current.exercise?.name ?? "Exercise")")
                                            .font(theme.typography.caption)
                                            .foregroundStyle(theme.colors.textTertiary)
                                    }

                                    if session.loggedExercises.isEmpty {
                                        Text("Add an exercise to begin logging sets.")
                                            .font(theme.typography.body)
                                            .foregroundStyle(theme.colors.textSecondary)
                                    }

                                    ForEach(sortedLoggedExercises) { logged in
                                        NavigationLink {
                                            ExerciseDetailView(
                                                viewModel: viewModel,
                                                logged: logged,
                                                previousSets: logged.exercise.flatMap { lastSessionSets(for: $0) },
                                                selectedWeightUnit: selectedWeightUnit,
                                                onRestTimer: { startRestTimer() },
                                                onError: { errorMessage = $0 }
                                            )
                                            .environmentObject(themeManager)
                                        } label: {
                                            masterListRow(for: logged)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button {
                                                withAnimation {
                                                    viewModel.moveExerciseUp(logged, context: modelContext)
                                                }
                                            } label: {
                                                Label("Move Up", systemImage: "arrow.up")
                                            }
                                            Button {
                                                withAnimation {
                                                    viewModel.moveExerciseDown(logged, context: modelContext)
                                                }
                                            } label: {
                                                Label("Move Down", systemImage: "arrow.down")
                                            }
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
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, theme.spacing.l)
                    .padding(.horizontal, theme.spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, viewModel.activeSession != nil && restRemainingSeconds > 0 ? 60 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture {
#if os(iOS)
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
                    }
                }
#if os(iOS)
                .scrollDismissesKeyboard(.interactively)
#endif

                // Floating rest timer pill
                if viewModel.activeSession != nil && restRemainingSeconds > 0 {
                    floatingRestTimerPill
                        .padding(.bottom, theme.spacing.m)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Train")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showingConverter = true
                        } label: {
                            Image(systemName: "scalemass")
                        }
                        Button("New Routine") {
                            showingNewRoutineSheet = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingConverter) {
                NavigationStack {
                    WeightConverterView()
                        .environmentObject(themeManager)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingConverter = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                exercisePickerSheet
            }
            .sheet(isPresented: $showingNewRoutineSheet) {
                newRoutineSheet
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
            .confirmationDialog(
                "Delete \"\(routineToDelete?.name ?? "Routine")\"?",
                isPresented: Binding(
                    get: { routineToDelete != nil },
                    set: { if !$0 { routineToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    guard let routine = routineToDelete else { return }
                    routineToDelete = nil
                    do {
                        try viewModel.deleteRoutine(routine, context: modelContext)
                        persistLastSelectedRoutine()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                Button("Cancel", role: .cancel) {
                    routineToDelete = nil
                }
            } message: {
                Text("This routine will be removed. Past workouts will keep their data but lose the routine label.")
            }
            .onAppear {
                restDurationSeconds = RestTimerSettings.load()
                selectedWeightUnit = WeightUnitSettings.load()
                restoreLastSelectedRoutine()
                if viewModel.activeSession == nil {
                    viewModel.resumeActiveSession(context: modelContext)
                }
            }
            .onChange(of: viewModel.selectedSplit?.id) { _, _ in
                persistLastSelectedRoutine()
            }
            .onChange(of: showingNewRoutineSheet) { _, isShowing in
                if !isShowing && pendingTemplateEdit {
                    pendingTemplateEdit = false
                    showingTemplatePicker = true
                }
            }
            .onChange(of: workoutTypes.count) { _, _ in
                restoreLastSelectedRoutine()
            }
            .onDisappear {
                stopRestTimer()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, let endDate = restTimerEndDate {
                    let remaining = Int(endDate.timeIntervalSinceNow)
                    if remaining > 0 {
                        restRemainingSeconds = remaining
                    } else {
                        restRemainingSeconds = 0
                        stopRestTimer()
#if os(iOS)
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
#endif
                        viewModel.updateLiveActivity(restTimerFinished: true)
                    }
                }
            }
        }
    }

    // MARK: - Master list row

    @ViewBuilder
    private func masterListRow(for logged: LoggedExercise) -> some View {
        let completed = isExerciseCompleted(logged)
        let working = workingSetCount(for: logged)

        HStack(spacing: theme.spacing.s) {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(completed ? theme.colors.success : theme.colors.textTertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text(logged.exercise?.name ?? "Exercise")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                HStack(spacing: theme.spacing.xs) {
                    Text("\(working)/\(logged.targetWorkingSets) sets")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                    if (logged.exercise?.category ?? "") == "Cardio" {
                        Text("Cardio")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.accentPrimary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(theme.colors.textTertiary)
        }
        .padding(.vertical, theme.spacing.xs)
    }

    // MARK: - Computed helpers

    private var completedExerciseCount: Int {
        guard let session = viewModel.activeSession else { return 0 }
        return session.loggedExercises.filter(isExerciseCompleted).count
    }

    private var totalExerciseCount: Int {
        viewModel.activeSession?.loggedExercises.count ?? 0
    }

    private var currentExercise: LoggedExercise? {
        guard let session = viewModel.activeSession else { return nil }
        let sorted = session.loggedExercises.sorted(by: { $0.orderIndex < $1.orderIndex })
        return sorted
            .filter { !$0.sets.isEmpty }
            .max(by: { ($0.sets.map(\.createdAt).max() ?? .distantPast) < ($1.sets.map(\.createdAt).max() ?? .distantPast) })
            ?? sorted.first
    }

    private func workingSetCount(for logged: LoggedExercise) -> Int {
        logged.sets.filter { !$0.isWarmup }.count
    }

    private func isExerciseCompleted(_ logged: LoggedExercise) -> Bool {
        if logged.isMarkedDone { return true }
        return workingSetCount(for: logged) >= max(1, logged.targetWorkingSets)
    }

    // MARK: - Previous performance

    func lastSessionSets(for exercise: Exercise) -> [LoggedSet]? {
        let activeSessionId = viewModel.activeSession?.id
        let completedSessions = sessions.filter { session in
            session.endedAt != nil && session.id != activeSessionId
        }
        for session in completedSessions {
            let matching = session.loggedExercises.first(where: { $0.exercise?.id == exercise.id })
            if let matching, !matching.sets.isEmpty {
                return matching.sets.sorted { $0.createdAt < $1.createdAt }
            }
        }
        return nil
    }

    // MARK: - New routine

    private var newRoutineSheet: some View {
        NavigationStack {
            Form {
                Section("Create a routine") {
                    TextField("Name (e.g., Workout A)", text: $newRoutineName)
                    Text("Build your own weekly workout names and start them anytime.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Routine")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingNewRoutineSheet = false
                        newRoutineName = ""
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = newRoutineName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let routine = WorkoutType(name: trimmed)
                        modelContext.insert(routine)
                        try? modelContext.save()
                        viewModel.selectedSplit = routine
                        pendingTemplateEdit = true
                        showingNewRoutineSheet = false
                        newRoutineName = ""
                    }
                    .disabled(newRoutineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func persistLastSelectedRoutine() {
        let defaults = UserDefaults.standard
        if let id = viewModel.selectedSplit?.id.uuidString {
            defaults.set(id, forKey: lastRoutineDefaultsKey)
        } else {
            defaults.removeObject(forKey: lastRoutineDefaultsKey)
        }
    }

    private func restoreLastSelectedRoutine() {
        guard viewModel.selectedSplit == nil else { return }
        let defaults = UserDefaults.standard
        guard let raw = defaults.string(forKey: lastRoutineDefaultsKey), let id = UUID(uuidString: raw) else { return }
        if let match = workoutTypes.first(where: { $0.id == id }) {
            viewModel.selectedSplit = match
        }
    }

    private func addStarterTemplate(to split: WorkoutType) {
        let targets = Set(split.includedMuscleGroups.map { $0.name.lowercased() })
        let existingExerciseIDs = Set(split.templateItems.compactMap { $0.exercise?.id })
        let matches = exercises.filter { ex in
            targets.contains(ex.category.lowercased()) && !existingExerciseIDs.contains(ex.id)
        }
        var nextIndex = (split.templateItems.map(\.orderIndex).max() ?? -1) + 1
        for exercise in matches.prefix(8) {
            let item = TemplateExercise(orderIndex: nextIndex, defaultSets: 3, routine: split, exercise: exercise)
            modelContext.insert(item)
            split.templateItems.append(item)
            nextIndex += 1
        }
        try? modelContext.save()
    }

    // MARK: - Split picker

    private var splitPicker: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text("Routine")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)

                Picker("Workout Routine", selection: $viewModel.selectedSplit) {
                    Text("Select Routine").tag(Optional<WorkoutType>.none)
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
                            Text(split.templateItems.isEmpty
                                 ? "Build Routine"
                                 : "\(split.templateItems.count) items in routine")
                        }
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.accentPrimary)
                    }

                    if split.templateItems.isEmpty && !split.includedMuscleGroups.isEmpty {
                        Button("Use Starter Preset") {
                            addStarterTemplate(to: split)
                        }
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                    }

                    Button(role: .destructive) {
                        routineToDelete = split
                    } label: {
                        HStack(spacing: theme.spacing.xs) {
                            Image(systemName: "trash")
                            Text("Delete Routine")
                        }
                        .font(theme.typography.caption)
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
                    HStack(spacing: theme.spacing.s) {
                        Button(role: .destructive) {
                            do {
                                try viewModel.abandonWorkout(context: modelContext)
                                stopRestTimer()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        } label: {
                            Text("Abandon Workout")
                                .font(theme.typography.caption)
                                .foregroundStyle(.red)
                        }

                        Spacer()

                        Text("Coverage updates instantly as you log working sets.")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Floating rest timer pill

    private var floatingRestTimerPill: some View {
        HStack(spacing: theme.spacing.m) {
            Image(systemName: "timer")
                .foregroundStyle(theme.colors.accentPrimary)
            Text(formattedRest)
                .font(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
                .monospacedDigit()
            Button {
                startRestTimer()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundStyle(theme.colors.accentPrimary)
            }
            .buttonStyle(.plain)
            Button {
                stopRestTimer()
                restRemainingSeconds = 0
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(theme.colors.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, theme.spacing.l)
        .padding(.vertical, theme.spacing.s)
        .background(
            Capsule()
                .fill(theme.colors.surfaceElevated)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
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

    // MARK: - Rest timer helpers

    private func startRestTimer() {
        stopRestTimer()
        restRemainingSeconds = Int(restDurationSeconds)
        guard restRemainingSeconds > 0 else { return }

        let endDate = Date.now.addingTimeInterval(restDurationSeconds)
        restTimerEndDate = endDate
        viewModel.updateLiveActivity(restTimerEndDate: endDate, restTimerFinished: false)

        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            DispatchQueue.main.async {
                let remaining = Int(endDate.timeIntervalSinceNow)
                if remaining > 0 {
                    restRemainingSeconds = remaining
                } else {
                    restRemainingSeconds = 0
                    restTimerEndDate = nil
#if os(iOS)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
#endif
                    viewModel.updateLiveActivity(restTimerFinished: true)
                    timer.invalidate()
                }
            }
        }
    }

    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restTimerEndDate = nil
        viewModel.updateLiveActivity(restTimerEndDate: nil)
    }
}
