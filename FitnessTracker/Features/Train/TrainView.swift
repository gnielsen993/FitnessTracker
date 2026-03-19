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
    @State private var showingNewRoutineSheet = false
    @State private var newRoutineName = ""
    @State private var setEditorTarget: LoggedExercise?
    @State private var editingSet: LoggedSet?
    @State private var exerciseSearchText = ""
    @State private var expandedExerciseCategories: Set<String> = []
    @State private var setReps = "10"
    @State private var setWeight = "45"
    @State private var selectedWeightUnit: WeightUnit = WeightUnitSettings.load()
    @State private var setIsWarmup = false
    @State private var cardioDurationMinutes = "20"
    @State private var cardioSpeedDescription = "6 mph"
    @State private var cardioZoneDescription = "Zone 2"
    @State private var setUsesPinTracking = false
    @State private var setPinPosition = "8th pin"
    @State private var errorMessage: String?
    @State private var showingConverter = false
    @State private var pendingTemplateEdit = false
    @State private var routineToDelete: WorkoutType?

    @State private var restRemainingSeconds = 0
    @State private var restTimer: Timer?

    // Phase 2: Inline set logging state per exercise
    @State private var inlineWeight: [UUID: String] = [:]
    @State private var inlineReps: [UUID: String] = [:]
    @State private var inlineIsWarmup: [UUID: Bool] = [:]

    private let lastRoutineDefaultsKey = "train.lastRoutineID"

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }

    private var groupedFilteredExercises: [(category: String, items: [Exercise])] {
        exercises.groupedByCategory(filter: exerciseSearchText)
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

                        if viewModel.activeSession != nil {
                            routineProgressCard
                        }

                        if let report = viewModel.coverageReport {
                            Button {
                                showingCoverageDetails = true
                            } label: {
                                CoverageCardView(report: report, theme: theme)
                            }
                            .buttonStyle(.plain)
                        }

                        workoutControls

                        // Phase 6: Workout notes
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
                    // Extra bottom padding so content isn't hidden behind floating timer
                    .padding(.bottom, viewModel.activeSession != nil && restRemainingSeconds > 0 ? 60 : 0)
                }

                // Phase 4: Floating rest timer pill
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
                selectedWeightUnit = WeightUnitSettings.load()
                restoreLastSelectedRoutine()
                // Phase 1C: Resume active session on appear
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
        }
    }


    private var completedExerciseCount: Int {
        guard let session = viewModel.activeSession else { return 0 }
        return session.loggedExercises.filter(isExerciseCompleted).count
    }

    private var totalExerciseCount: Int {
        viewModel.activeSession?.loggedExercises.count ?? 0
    }

    private var nextSuggestedExercise: LoggedExercise? {
        guard let session = viewModel.activeSession else { return nil }
        return session.loggedExercises
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .first(where: { !isExerciseCompleted($0) })
    }

    private func workingSetCount(for logged: LoggedExercise) -> Int {
        logged.sets.filter { !$0.isWarmup }.count
    }

    private func isExerciseCompleted(_ logged: LoggedExercise) -> Bool {
        if logged.isMarkedDone { return true }
        return workingSetCount(for: logged) >= max(1, logged.targetWorkingSets)
    }

    // MARK: - Routine progress

    private var routineProgressCard: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text("Today's Routine")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)

                Text("Completed \(completedExerciseCount) of \(totalExerciseCount)")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)

                if let nextSuggestedExercise {
                    Text("Next up: \(nextSuggestedExercise.exercise?.name ?? "Exercise")")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textPrimary)
                }

                let activeList = viewModel.activeSession?.loggedExercises.sorted(by: { $0.orderIndex < $1.orderIndex }) ?? []
                if !activeList.isEmpty {
                    ForEach(activeList) { logged in
                        HStack(spacing: theme.spacing.xs) {
                            Image(systemName: isExerciseCompleted(logged) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isExerciseCompleted(logged) ? theme.colors.success : theme.colors.textTertiary)
                            Text(logged.exercise?.name ?? "Exercise")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)
                            Spacer()
                            if (logged.exercise?.category ?? "") == "Cardio" {
                                Text("Cardio")
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colors.accentPrimary)
                            }
                        }
                    }
                }
            }
        }
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
                        let routine = WorkoutType(name: trimmed, includedMuscleGroups: [], templateExercises: [])
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
        let matches = exercises.filter { ex in
            targets.contains(ex.category.lowercased()) && !split.templateExercises.contains(where: { $0.id == ex.id })
        }
        for exercise in matches.prefix(8) {
            split.templateExercises.append(exercise)
        }
        try? modelContext.save()
    }

    // MARK: - Phase 3: Previous performance

    private func lastSessionSets(for exercise: Exercise) -> [LoggedSet]? {
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

    private func previousPerformanceSummary(for exercise: Exercise) -> String? {
        guard let sets = lastSessionSets(for: exercise) else { return nil }
        let workingSets = sets.filter { !$0.isWarmup }
        guard !workingSets.isEmpty else { return nil }
        let descriptions = workingSets.map { set in
            if let pin = set.pinPosition, !pin.isEmpty {
                return "\(pin)x\(set.reps)"
            }
            return "\(String(format: "%g", set.weight))x\(set.reps)"
        }
        return "Last: " + descriptions.joined(separator: ", ")
    }

    // MARK: - Exercise row

    @ViewBuilder
    private func exerciseRow(for logged: LoggedExercise) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            HStack {
                Image(systemName: isExerciseCompleted(logged) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isExerciseCompleted(logged) ? theme.colors.success : theme.colors.textTertiary)
                Text(logged.exercise?.name ?? "Exercise")
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textPrimary)
                if (logged.exercise?.category ?? "") == "Cardio" {
                    Text("Cardio")
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.accentPrimary)
                }
                Spacer()
                Button(logged.isMarkedDone ? "Undo" : "Done") {
                    logged.isMarkedDone.toggle()
                    try? modelContext.save()
                }
                .font(theme.typography.caption)
                .foregroundStyle(logged.isMarkedDone ? theme.colors.success : theme.colors.textSecondary)

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

            // Phase 3: Previous performance
            if let exercise = logged.exercise, let prevSummary = previousPerformanceSummary(for: exercise) {
                Text(prevSummary)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textTertiary)
            }

            HStack(spacing: theme.spacing.s) {
                Text(exerciseProgressSummary(logged))
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                Spacer()
                Button {
                    logged.targetWorkingSets = max(1, logged.targetWorkingSets - 1)
                    try? modelContext.save()
                } label: { Image(systemName: "minus.circle") }
                .buttonStyle(.plain)
                .foregroundStyle(theme.colors.textSecondary)

                Button {
                    logged.targetWorkingSets += 1
                    try? modelContext.save()
                } label: { Image(systemName: "plus.circle") }
                .buttonStyle(.plain)
                .foregroundStyle(theme.colors.accentPrimary)
            }

            let sortedSets = logged.sets.sorted { $0.createdAt < $1.createdAt }
            ForEach(sortedSets) { set in
                Button {
                    openSetEditor(for: set, in: logged)
                } label: {
                    HStack(spacing: theme.spacing.xs) {
                        Text(set.isWarmup ? "W" : "•")
                            .foregroundStyle(set.isWarmup ? theme.colors.textTertiary : theme.colors.accentPrimary)
                        Text(cardioSetSummary(set, for: logged))
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

            // Phase 2: Inline quick-add row (non-cardio, non-pin exercises only)
            if let exercise = logged.exercise,
               exercise.category != "Cardio",
               !logged.sets.contains(where: { ($0.pinPosition?.isEmpty == false) }) {
                inlineSetRow(for: logged)
            }
        }
    }

    // MARK: - Phase 2: Inline set logging

    @ViewBuilder
    private func inlineSetRow(for logged: LoggedExercise) -> some View {
        let exerciseId = logged.id
        HStack(spacing: theme.spacing.xs) {
            Button {
                let current = inlineIsWarmup[exerciseId] ?? false
                inlineIsWarmup[exerciseId] = !current
            } label: {
                Text(inlineIsWarmup[exerciseId] == true ? "W" : "•")
                    .font(theme.typography.caption)
                    .foregroundStyle(inlineIsWarmup[exerciseId] == true ? theme.colors.textTertiary : theme.colors.accentPrimary)
                    .frame(width: 20)
            }
            .buttonStyle(.plain)

            TextField("wt", text: Binding(
                get: { inlineWeight[exerciseId] ?? defaultInlineWeight(for: logged) },
                set: { inlineWeight[exerciseId] = $0 }
            ))
            .font(theme.typography.caption)
#if os(iOS)
            .keyboardType(.decimalPad)
#endif
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 70)

            Text(selectedWeightUnit.displayName)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textTertiary)

            Text("×")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textTertiary)

            TextField("reps", text: Binding(
                get: { inlineReps[exerciseId] ?? defaultInlineReps(for: logged) },
                set: { inlineReps[exerciseId] = $0 }
            ))
            .font(theme.typography.caption)
#if os(iOS)
            .keyboardType(.numberPad)
#endif
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: 50)

            Button {
                saveInlineSet(for: logged)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.colors.accentPrimary)
            }
            .buttonStyle(.plain)
        }
    }

    private func defaultInlineWeight(for logged: LoggedExercise) -> String {
        if let last = logged.sets.sorted(by: { $0.createdAt < $1.createdAt }).last {
            return String(format: "%g", last.weight)
        }
        return "45"
    }

    private func defaultInlineReps(for logged: LoggedExercise) -> String {
        if let last = logged.sets.sorted(by: { $0.createdAt < $1.createdAt }).last {
            return String(last.reps)
        }
        return "10"
    }

    private func saveInlineSet(for logged: LoggedExercise) {
        let exerciseId = logged.id
        let weightStr = inlineWeight[exerciseId] ?? defaultInlineWeight(for: logged)
        let repsStr = inlineReps[exerciseId] ?? defaultInlineReps(for: logged)
        let warmup = inlineIsWarmup[exerciseId] ?? false

        guard let weight = Double(weightStr), let reps = Int(repsStr), reps > 0 else {
            errorMessage = "Enter valid weight and reps."
            return
        }

        do {
            try viewModel.addSet(
                reps: reps,
                weight: weight,
                isWarmup: warmup,
                weightUnit: selectedWeightUnit.rawValue,
                to: logged,
                context: modelContext
            )
            // Reset inline state and pre-fill from new last set
            inlineWeight.removeValue(forKey: exerciseId)
            inlineReps.removeValue(forKey: exerciseId)
            inlineIsWarmup.removeValue(forKey: exerciseId)
            if !warmup { startRestTimer() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exerciseProgressSummary(_ logged: LoggedExercise) -> String {
        if logged.sets.contains(where: { ($0.pinPosition?.isEmpty == false) }) {
            return "Target \(logged.targetWorkingSets) sets • Logged \(workingSetCount(for: logged)) • Pin tracking"
        }
        let unit = logged.sets.last?.weightUnit ?? selectedWeightUnit.rawValue
        return "Target \(logged.targetWorkingSets) sets • Logged \(workingSetCount(for: logged)) • Volume \(Int(StatsEngine.exerciseVolume(logged))) \(unit)"
    }

    private func cardioSetSummary(_ set: LoggedSet, for logged: LoggedExercise) -> String {
        let isCardio = (logged.exercise?.category ?? "") == "Cardio"
        if isCardio {
            let duration = set.cardioDurationMinutes.map { String(format: "%g min", $0) } ?? "-"
            let speed = (set.cardioSpeedDescription?.isEmpty == false) ? set.cardioSpeedDescription! : "pace n/a"
            let zone = (set.cardioZoneDescription?.isEmpty == false) ? set.cardioZoneDescription! : "zone n/a"
            return "\(duration) • \(speed) • \(zone)"
        }

        if let pin = set.pinPosition, !pin.isEmpty {
            return "\(pin) × \(set.reps)"
        }

        return "\(String(format: "%g", set.weight)) \(set.weightUnit) × \(set.reps)"
    }

    private func openSetEditor(for set: LoggedSet?, in logged: LoggedExercise) {
        if let set {
            editingSet = set
            setReps = String(set.reps)
            setWeight = String(format: "%g", set.weight)
            setIsWarmup = set.isWarmup
            cardioDurationMinutes = set.cardioDurationMinutes.map { String(format: "%g", $0) } ?? "20"
            cardioSpeedDescription = set.cardioSpeedDescription ?? "6 mph"
            cardioZoneDescription = set.cardioZoneDescription ?? "Zone 2"
            setUsesPinTracking = (set.pinPosition?.isEmpty == false)
            setPinPosition = set.pinPosition ?? "8th pin"
        } else {
            editingSet = nil
            // Pre-fill from last logged set for this exercise.
            if let last = logged.sets.sorted(by: { $0.createdAt < $1.createdAt }).last {
                setReps = String(last.reps)
                setWeight = String(format: "%g", last.weight)
                setIsWarmup = last.isWarmup
                cardioDurationMinutes = last.cardioDurationMinutes.map { String(format: "%g", $0) } ?? "20"
                cardioSpeedDescription = last.cardioSpeedDescription ?? "6 mph"
                cardioZoneDescription = last.cardioZoneDescription ?? "Zone 2"
                setUsesPinTracking = (last.pinPosition?.isEmpty == false)
                setPinPosition = last.pinPosition ?? "8th pin"
            } else {
                setReps = "10"
                setWeight = "45"
                setIsWarmup = false
                cardioDurationMinutes = "20"
                cardioSpeedDescription = "6 mph"
                cardioZoneDescription = "Zone 2"
                setUsesPinTracking = false
                setPinPosition = "8th pin"
            }
        }
        setEditorTarget = logged
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
                            Text(split.templateExercises.isEmpty
                                 ? "Build Routine"
                                 : "\(split.templateExercises.count) items in routine")
                        }
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.accentPrimary)
                    }

                    if split.templateExercises.isEmpty && !split.includedMuscleGroups.isEmpty {
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
                        // Phase 1C: Abandon workout button
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

    // MARK: - Phase 4: Floating rest timer pill

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

    // MARK: - Set editor sheet

    private func setEditorSheet(for loggedExercise: LoggedExercise) -> some View {
        NavigationStack {
            Form {
                Section("Set") {
                    let isCardio = (loggedExercise.exercise?.category ?? "") == "Cardio"

                    if isCardio {
                        TextField("Duration (min)", text: $cardioDurationMinutes)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                        TextField("Speed / Pace (e.g., 6 mph)", text: $cardioSpeedDescription)
                        TextField("Zone (e.g., Zone 2)", text: $cardioZoneDescription)
                    } else {
                        TextField("Reps", text: $setReps)
#if os(iOS)
                            .keyboardType(.numberPad)
#endif
                        Toggle("Track by pin position", isOn: $setUsesPinTracking)

                        if setUsesPinTracking {
                            TextField("Pin (e.g., 8th pin)", text: $setPinPosition)
                        } else {
                            TextField("Weight (\(selectedWeightUnit.displayName.uppercased()))", text: $setWeight)
#if os(iOS)
                                .keyboardType(.decimalPad)
#endif
                            if let typedWeight = Double(setWeight), typedWeight > 0 {
                                let opposite: WeightUnit = selectedWeightUnit == .lbs ? .kg : .lbs
                                let converted = WeightUnitSettings.convert(typedWeight, from: selectedWeightUnit, to: opposite)
                                Text("≈ \(String(format: "%.1f", converted)) \(opposite.displayName.uppercased())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Toggle("Warm-up Set", isOn: $setIsWarmup)
                }

                // Phase 3: Previous session section in editor
                if let exercise = loggedExercise.exercise, let prevSets = lastSessionSets(for: exercise) {
                    Section("Previous Session") {
                        ForEach(prevSets) { set in
                            HStack(spacing: 4) {
                                Text(set.isWarmup ? "W" : "•")
                                    .foregroundStyle(set.isWarmup ? .secondary : .primary)
                                if let pin = set.pinPosition, !pin.isEmpty {
                                    Text("\(pin) × \(set.reps)")
                                } else {
                                    Text("\(String(format: "%g", set.weight)) \(set.weightUnit) × \(set.reps)")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
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
                            let weight = setUsesPinTracking ? 0 : (Double(setWeight) ?? 0)
                            let unit = selectedWeightUnit.rawValue
                            if let existing = editingSet {
                                try viewModel.updateSet(existing, reps: reps, weight: weight, isWarmup: setIsWarmup, cardioDurationMinutes: Double(cardioDurationMinutes), cardioSpeedDescription: cardioSpeedDescription.trimmingCharacters(in: .whitespacesAndNewlines), cardioZoneDescription: cardioZoneDescription.trimmingCharacters(in: .whitespacesAndNewlines), pinPosition: setUsesPinTracking ? setPinPosition.trimmingCharacters(in: .whitespacesAndNewlines) : nil, weightUnit: unit, context: modelContext)
                            } else {
                                try viewModel.addSet(
                                    reps: reps,
                                    weight: weight,
                                    isWarmup: setIsWarmup,
                                    cardioDurationMinutes: Double(cardioDurationMinutes),
                                    cardioSpeedDescription: cardioSpeedDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                                    cardioZoneDescription: cardioZoneDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                                    pinPosition: setUsesPinTracking ? setPinPosition.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                                    weightUnit: unit,
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
                    .disabled(((loggedExercise.exercise?.category ?? "") == "Cardio") ? ((Double(cardioDurationMinutes) ?? 0) <= 0) : ((Int(setReps) ?? 0) <= 0 || (!setUsesPinTracking && (Double(setWeight) ?? 0) < 0) || (setUsesPinTracking && setPinPosition.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)))
                }
            }
        }
    }

    // MARK: - Progressive overload suggestion

    private func progressiveSuggestion(for loggedExercise: LoggedExercise) -> ProgressiveSuggestion? {
        guard let exercise = loggedExercise.exercise else { return nil }
        guard exercise.category != "Cardio" else { return nil }
        guard !loggedExercise.sets.contains(where: { ($0.pinPosition?.isEmpty == false) }) else { return nil }

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
                // Phase 4: Haptic feedback when timer hits 0
                if restRemainingSeconds == 0 {
#if os(iOS)
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
#endif
                }
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
