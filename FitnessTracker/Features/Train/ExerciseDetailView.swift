import SwiftUI
import SwiftData
import DesignKit

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: TrainViewModel
    let logged: LoggedExercise
    let previousSets: [LoggedSet]?
    let selectedWeightUnit: WeightUnit
    let onRestTimer: () -> Void
    let onError: (String) -> Void

    // Set editor state
    @State private var setReps = "10"
    @State private var setWeight = "45"
    @State private var setIsWarmup = false
    @State private var cardioDurationMinutes = "20"
    @State private var cardioSpeedDescription = "6 mph"
    @State private var cardioZoneDescription = "Zone 2"
    @State private var cardioDistance = ""
    @State private var cardioInclinePercent = ""
    private enum LoggerMode: String, CaseIterable, Identifiable { case weight = "Weight", pin = "Pin", bodyweight = "Bodyweight"; var id: String { rawValue } }
    @State private var loggerMode: LoggerMode = .weight
    @State private var setUsesPinTracking = false
    @State private var setPinPosition = "8th pin"
    private enum SetMetric: String, CaseIterable, Identifiable { case reps = "Reps", time = "Time"; var id: String { rawValue } }
    @State private var setMetric: SetMetric = .reps
    @State private var setDurationSeconds = "00:45.00"
    @State private var timedEntryElapsedCentiseconds: Int = 0
    @State private var timedEntryTimer: Timer?
    @State private var editingSet: LoggedSet?
    @State private var showingSetEditor = false

    private var theme: Theme { themeManager.theme(for: colorScheme) }

    private var isCardio: Bool {
        (logged.exercise?.category ?? "") == "Cardio"
    }

    private var sortedSets: [LoggedSet] {
        logged.sets.sorted { $0.createdAt < $1.createdAt }
    }

    private var workingSetCount: Int {
        logged.sets.filter { !$0.isWarmup }.count
    }

    private var knownVariants: [String] {
        let vals = Set(logged.sets.compactMap { $0.machineVariant }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        let ordered = vals.sorted()
        return ordered.isEmpty ? ["Default"] : (["Default"] + ordered.filter { $0 != "Default" })
    }

    private var isCompleted: Bool {
        if logged.isMarkedDone { return true }
        if isCardio {
            return logged.sets.contains(where: { !$0.isWarmup })
        }
        return workingSetCount >= max(1, logged.targetWorkingSets)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.l) {
                headerSection
                setupNoteSection
                previousPerformanceSection
                progressSummarySection
                setsListSection
                if !isCompleted {
                    quickAddSection
                }
                progressiveOverloadSection
            }
            .padding(.horizontal, theme.spacing.s)
            .padding(.vertical, theme.spacing.l)
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
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle(logged.exercise?.name ?? "Exercise")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(logged.isMarkedDone ? "Undo" : "Done") {
                    let shouldDismiss = !logged.isMarkedDone
                    logged.isMarkedDone.toggle()
                    try? modelContext.save()
                    if shouldDismiss {
                        dismiss()
                    }
                }
                .foregroundStyle(logged.isMarkedDone ? theme.colors.success : theme.colors.textSecondary)
            }
#if os(iOS)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
#endif
        }
        .sheet(isPresented: $showingSetEditor) {
            if let set = editingSet {
                setEditorSheet(editing: set)
            }
        }
        .onAppear {
            prefillFromHistoryIfNeeded()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        DKCard(theme: theme) {
            HStack {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? theme.colors.success : theme.colors.textTertiary)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(logged.exercise?.name ?? "Exercise")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)
                    if isCardio {
                        Text("Cardio")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.accentPrimary)
                    }
                }
                Spacer()
                Text(isCompleted ? "Complete" : "In Progress")
                    .font(theme.typography.caption)
                    .foregroundStyle(isCompleted ? theme.colors.success : theme.colors.textSecondary)
            }
        }
    }

    // MARK: - Previous Performance

    @ViewBuilder
    private var previousPerformanceSection: some View {
        if let sets = previousSets {
            let workingSets = sets.filter { !$0.isWarmup }
            if !workingSets.isEmpty {
                DKCard(theme: theme) {
                    VStack(alignment: .leading, spacing: theme.spacing.s) {
                        Text("Previous Session")
                            .font(theme.typography.headline)
                            .foregroundStyle(theme.colors.textPrimary)
                        ForEach(sets) { set in
                            HStack(spacing: 4) {
                                Text(set.isWarmup ? "W" : "\u{2022}")
                                    .foregroundStyle(set.isWarmup ? theme.colors.textTertiary : theme.colors.accentPrimary)
                                Text(setSummaryText(set))
                                    .foregroundStyle(theme.colors.textSecondary)
                            }
                            .font(theme.typography.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Progress Summary

    private var setupNoteSection: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.xs) {
                Text("Setup Note")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                TextField("e.g., Rack 8 / Cable 10", text: Binding(
                    get: { logged.setupNote },
                    set: { logged.setupNote = $0; try? modelContext.save() }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var progressSummarySection: some View {
        DKCard(theme: theme) {
            HStack(spacing: theme.spacing.s) {
                Text(progressText)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
                Spacer()
            }
        }
    }

    private var progressText: String {
        if isCardio {
            return "Cardio entries logged: \(workingSetCount) • Complete after first entry"
        }
        if logged.sets.contains(where: { ($0.pinPosition?.isEmpty == false) }) {
            return "Target \(logged.targetWorkingSets) sets • Logged \(workingSetCount) • Pin tracking"
        }
        let unit = logged.sets.last?.weightUnit ?? selectedWeightUnit.rawValue
        return "Target \(logged.targetWorkingSets) sets • Logged \(workingSetCount) • Volume \(Int(StatsEngine.exerciseVolume(logged))) \(unit)"
    }

    // MARK: - Sets List

    private var setsListSection: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text(isCardio ? "Cardio Log" : "Logged Sets")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)

                if sortedSets.isEmpty {
                    Text(isCardio ? "No cardio entries logged yet." : "No sets logged yet.")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                }

                ForEach(sortedSets) { set in
                    Button {
                        openSetEditor(for: set)
                    } label: {
                        HStack(spacing: theme.spacing.xs) {
                            Text(set.isWarmup ? "W" : "\u{2022}")
                                .foregroundStyle(set.isWarmup ? theme.colors.textTertiary : theme.colors.accentPrimary)
                            Text(setSummaryText(set))
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
    }

    // MARK: - Quick Add

    @ViewBuilder
    private var quickAddSection: some View {
        DKCard(theme: theme) {
            VStack(alignment: .leading, spacing: theme.spacing.s) {
                Text(isCardio ? "Add Cardio Entry" : "Set Logger")
                    .font(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)

                if isCardio {
                    cardioQuickAdd
                } else {
                    Picker("Logger Mode", selection: $loggerMode) {
                        ForEach(LoggerMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch loggerMode {
                    case .weight: weightQuickAdd
                    case .pin: pinQuickAdd
                    case .bodyweight: bodyweightQuickAdd
                    }
                }
            }
        }
    }

    private var weightQuickAdd: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Toggle("Warm-up", isOn: $setIsWarmup)
                .font(theme.typography.caption)

            HStack {
                Button("-") {
                    let w = Double(setWeight) ?? 0
                    setWeight = String(format: "%g", max(0, w - 5))
                }
                TextField("Weight (\(selectedWeightUnit.displayName.uppercased()))", text: $setWeight)
                    .font(theme.typography.body)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                Button("+") {
                    let w = Double(setWeight) ?? 0
                    setWeight = String(format: "%g", w + 5)
                }
            }

            Picker("Metric", selection: $setMetric) {
                ForEach(SetMetric.allCases) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            if setMetric == .reps {
                HStack {
                    Button("-") { if let r = Int(setReps), r > 1 { setReps = String(r - 1) } }
                    TextField("Reps", text: $setReps)
                        .font(theme.typography.body)
#if os(iOS)
                        .keyboardType(.numberPad)
#endif
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                    Button("+") { let r = Int(setReps) ?? 0; setReps = String(r + 1) }
                }
            } else {
                TextField("Time (MM:SS.CC)", text: $setDurationSeconds)
                    .font(theme.typography.body)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                timedSetControls
            }

            Button("Log Set") {
                saveQuickAdd()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cardioQuickAdd: some View {
        VStack(spacing: theme.spacing.s) {
            TextField("Duration (min)", text: $cardioDurationMinutes)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif
                .textFieldStyle(.roundedBorder)
            TextField("Speed / Pace", text: $cardioSpeedDescription)
                .textFieldStyle(.roundedBorder)
            TextField("Zone", text: $cardioZoneDescription)
                .textFieldStyle(.roundedBorder)
            TextField("Distance (optional)", text: $cardioDistance)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif
                .textFieldStyle(.roundedBorder)
            TextField("Incline % (optional)", text: $cardioInclinePercent)
#if os(iOS)
                .keyboardType(.decimalPad)
#endif
                .textFieldStyle(.roundedBorder)
            Toggle("Warm-up", isOn: $setIsWarmup)
                .font(theme.typography.caption)
            Button("Save Entry") {
                saveCardioSet()
            }
            .font(theme.typography.caption)
            .foregroundStyle(theme.colors.accentPrimary)
        }
    }

    private var pinQuickAdd: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Toggle("Warm-up", isOn: $setIsWarmup)
                .font(theme.typography.caption)

            TextField("Pin (e.g., 8th pin)", text: $setPinPosition)
                .font(theme.typography.body)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

            Picker("Metric", selection: $setMetric) {
                ForEach(SetMetric.allCases) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            if setMetric == .reps {
                TextField("Reps", text: $setReps)
                    .font(theme.typography.body)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            } else {
                TextField("Time (MM:SS.CC)", text: $setDurationSeconds)
                    .font(theme.typography.body)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                timedSetControls
            }

            Button("Log Set") {
                savePinSet()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bodyweightQuickAdd: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            Toggle("Warm-up", isOn: $setIsWarmup)
                .font(theme.typography.caption)

            Picker("Metric", selection: $setMetric) {
                ForEach(SetMetric.allCases) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)

            if setMetric == .reps {
                TextField("Reps", text: $setReps)
                    .font(theme.typography.body)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
            } else {
                TextField("Time (MM:SS.CC)", text: $setDurationSeconds)
                    .font(theme.typography.body)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: .infinity)
                timedSetControls
            }

            Button("Log Set") {
                saveBodyweightSet()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }


    private var timedSetControls: some View {
        HStack(spacing: theme.spacing.s) {
            Text("Timer: \(formatDurationCentiseconds(max(0, timedEntryElapsedCentiseconds)))")
                .font(theme.typography.caption)
                .monospacedDigit()
                .foregroundStyle(theme.colors.textSecondary)
            Spacer()
            Button(timedEntryTimer == nil ? "Start" : "Pause") {
                timedEntryTimer == nil ? startTimedEntryCountdown() : pauseTimedEntryCountdown()
            }
            .font(theme.typography.caption)
            .buttonStyle(.bordered)

            Button("Reset") {
                resetTimedEntryCountdown()
            }
            .font(theme.typography.caption)
            .buttonStyle(.bordered)
        }
    }

    private func parseDurationInput(_ raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seconds = Int(trimmed), seconds > 0 { return seconds }
        let main = trimmed.split(separator: ".").first.map(String.init) ?? trimmed
        if main.contains(":") {
            let parts = main.split(separator: ":").map(String.init)
            if parts.count == 2, let mm = Int(parts[0]), let ss = Int(parts[1]) {
                let total = (mm * 60) + ss
                return total > 0 ? total : nil
            }
        }
        return nil
    }

    private func formatDurationInput(_ seconds: Int) -> String {
        let mm = max(0, seconds) / 60
        let ss = max(0, seconds) % 60
        return String(format: "%02d:%02d.00", mm, ss)
    }

    private func formatDurationCentiseconds(_ centiseconds: Int) -> String {
        let total = max(0, centiseconds)
        let mm = total / 6000
        let ss = (total % 6000) / 100
        let cs = total % 100
        return String(format: "%02d:%02d.%02d", mm, ss, cs)
    }

    private func startTimedEntryCountdown() {
        timedEntryTimer?.invalidate()
        if timedEntryElapsedCentiseconds <= 0 {
            timedEntryElapsedCentiseconds = 0
            setDurationSeconds = "00:00.00"
        }
        let timer = Timer(timeInterval: 0.01, repeats: true) { t in
            DispatchQueue.main.async {
                timedEntryElapsedCentiseconds += 1
                setDurationSeconds = formatDurationCentiseconds(timedEntryElapsedCentiseconds)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        timedEntryTimer = timer
    }

    private func pauseTimedEntryCountdown() {
        timedEntryTimer?.invalidate()
        timedEntryTimer = nil
    }

    private func resetTimedEntryCountdown() {
        timedEntryTimer?.invalidate()
        timedEntryTimer = nil
        timedEntryElapsedCentiseconds = 0
        setDurationSeconds = "00:00.00"
    }

    // MARK: - Progressive Overload

    @ViewBuilder
    private var progressiveOverloadSection: some View {
        if let suggestion = progressiveSuggestion() {
            DKCard(theme: theme) {
                VStack(alignment: .leading, spacing: theme.spacing.s) {
                    Text("Progressive Overload")
                        .font(theme.typography.headline)
                        .foregroundStyle(theme.colors.textPrimary)

                    Text(suggestion.message)
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)

                    if let oneRM = suggestion.estimatedOneRM {
                        Text("Estimated 1RM (Epley): \(Int(oneRM.rounded()))")
                            .font(theme.typography.caption)
                            .foregroundStyle(theme.colors.textTertiary)
                    }

                    ForEach(suggestion.recommendations) { rec in
                        HStack {
                            Text("\(rec.reps) reps")
                                .font(theme.typography.caption)
                            Spacer()
                            Text("~\(Int(rec.weight))")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)
                            Button("Apply") {
                                setReps = String(rec.reps)
                                setWeight = String(Int(rec.weight.rounded()))
                            }
                            .font(theme.typography.caption)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func setSummaryText(_ set: LoggedSet) -> String {
        if isCardio {
            var parts: [String] = []
            let duration = set.cardioDurationMinutes.map { String(format: "%g min", $0) } ?? "-"
            parts.append(duration)
            if let speed = set.cardioSpeedDescription, !speed.isEmpty { parts.append(speed) }
            if let zone = set.cardioZoneDescription, !zone.isEmpty { parts.append(zone) }
            if let distance = set.cardioDistance { parts.append(String(format: "%g mi", distance)) }
            if let incline = set.cardioInclinePercent { parts.append(String(format: "%g%% incline", incline)) }
            return parts.joined(separator: " • ")
        }
        if let duration = set.durationSeconds {
            if set.isBodyweight { return "Bodyweight • \(duration)s" }
            if let pin = set.pinPosition, !pin.isEmpty { return "\(pin) • \(duration)s" }
            return "\(String(format: "%g", set.weight)) \(set.weightUnit) • \(duration)s"
        }
        if set.isBodyweight {
            return "Bodyweight × \(set.reps)"
        }
        if let pin = set.pinPosition, !pin.isEmpty {
            return "\(pin) × \(set.reps)"
        }
        return "\(String(format: "%g", set.weight)) \(set.weightUnit) × \(set.reps)"
    }

    private func prefillFromLastSet() {
        if let last = sortedSets.last {
            setReps = String(last.reps)
            setWeight = String(format: "%g", last.weight)
            setIsWarmup = last.isWarmup
            cardioDurationMinutes = last.cardioDurationMinutes.map { String(format: "%g", $0) } ?? "20"
            cardioSpeedDescription = last.cardioSpeedDescription ?? "6 mph"
            cardioZoneDescription = last.cardioZoneDescription ?? "Zone 2"
            cardioDistance = last.cardioDistance.map { String(format: "%g", $0) } ?? ""
            cardioInclinePercent = last.cardioInclinePercent.map { String(format: "%g", $0) } ?? ""
            setUsesPinTracking = (last.pinPosition?.isEmpty == false)
            setPinPosition = last.pinPosition ?? "8th pin"
            loggerMode = last.isBodyweight ? .bodyweight : (setUsesPinTracking ? .pin : .weight)
            setMetric = (last.durationSeconds != nil) ? .time : .reps
            setDurationSeconds = last.durationSeconds.map(formatDurationInput) ?? "00:00.00"
            timedEntryElapsedCentiseconds = (last.durationSeconds ?? 0) * 100
        }
    }

    private func prefillFromHistoryIfNeeded() {
        // Prefer in-progress workout data first.
        if let last = sortedSets.last {
            setReps = String(last.reps)
            setWeight = String(format: "%g", last.weight)
            setIsWarmup = false
            cardioDurationMinutes = last.cardioDurationMinutes.map { String(format: "%g", $0) } ?? "20"
            cardioSpeedDescription = last.cardioSpeedDescription ?? "6 mph"
            cardioZoneDescription = last.cardioZoneDescription ?? "Zone 2"
            cardioDistance = last.cardioDistance.map { String(format: "%g", $0) } ?? ""
            cardioInclinePercent = last.cardioInclinePercent.map { String(format: "%g", $0) } ?? ""
            setUsesPinTracking = (last.pinPosition?.isEmpty == false)
            setPinPosition = last.pinPosition ?? "8th pin"
            loggerMode = last.isBodyweight ? .bodyweight : (setUsesPinTracking ? .pin : .weight)
            setMetric = (last.durationSeconds != nil) ? .time : .reps
            setDurationSeconds = last.durationSeconds.map(formatDurationInput) ?? "00:00.00"
            timedEntryElapsedCentiseconds = (last.durationSeconds ?? 0) * 100
            return
        }

        // Otherwise hydrate from most recent historical set for this exercise.
        if let lastHistorical = previousSets?.last {
            setReps = String(lastHistorical.reps)
            setWeight = String(format: "%g", lastHistorical.weight)
            setIsWarmup = false
            cardioDurationMinutes = lastHistorical.cardioDurationMinutes.map { String(format: "%g", $0) } ?? "20"
            cardioSpeedDescription = lastHistorical.cardioSpeedDescription ?? "6 mph"
            cardioZoneDescription = lastHistorical.cardioZoneDescription ?? "Zone 2"
            cardioDistance = lastHistorical.cardioDistance.map { String(format: "%g", $0) } ?? ""
            cardioInclinePercent = lastHistorical.cardioInclinePercent.map { String(format: "%g", $0) } ?? ""
            setUsesPinTracking = (lastHistorical.pinPosition?.isEmpty == false)
            setPinPosition = lastHistorical.pinPosition ?? "8th pin"
            loggerMode = lastHistorical.isBodyweight ? .bodyweight : (setUsesPinTracking ? .pin : .weight)
            setMetric = (lastHistorical.durationSeconds != nil) ? .time : .reps
            setDurationSeconds = lastHistorical.durationSeconds.map(formatDurationInput) ?? "00:00.00"
            timedEntryElapsedCentiseconds = (lastHistorical.durationSeconds ?? 0) * 100
        }
    }

    private func saveQuickAdd() {
        guard let weight = Double(setWeight) else {
            onError("Enter valid weight.")
            return
        }
        let reps = (setMetric == .reps) ? (Int(setReps) ?? 0) : 1
        let duration = (setMetric == .time) ? max(1, timedEntryElapsedCentiseconds / 100) : nil
        guard (setMetric == .reps ? reps > 0 : (duration ?? 0) > 0) else {
            onError(setMetric == .reps ? "Enter valid reps." : "Start timer and log elapsed time.")
            return
        }
        do {
            try viewModel.addSet(
                reps: reps, weight: weight, isWarmup: setIsWarmup,
                durationSeconds: duration,
                machineVariant: nil,
                weightUnit: selectedWeightUnit.rawValue,
                to: logged, context: modelContext
            )
            if !setIsWarmup { onRestTimer() }
            prefillFromLastSet()
        } catch {
            onError(error.localizedDescription)
        }
    }

    private func saveCardioSet() {
        let reps = 1
        do {
            try viewModel.addSet(
                reps: reps, weight: 0, isWarmup: setIsWarmup,
                cardioDurationMinutes: Double(cardioDurationMinutes),
                cardioSpeedDescription: cardioSpeedDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                cardioZoneDescription: cardioZoneDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                cardioDistance: Double(cardioDistance),
                cardioInclinePercent: Double(cardioInclinePercent),
                weightUnit: selectedWeightUnit.rawValue,
                to: logged, context: modelContext
            )
            if !setIsWarmup { onRestTimer() }
        } catch {
            onError(error.localizedDescription)
        }
    }

    private func saveBodyweightSet() {
        let reps = (setMetric == .reps) ? (Int(setReps) ?? 0) : 1
        let duration = (setMetric == .time) ? max(1, timedEntryElapsedCentiseconds / 100) : nil
        guard (setMetric == .reps ? reps > 0 : (duration ?? 0) > 0) else {
            onError(setMetric == .reps ? "Enter valid reps." : "Start timer and log elapsed time.")
            return
        }
        do {
            try viewModel.addSet(
                reps: reps, weight: 0, isWarmup: setIsWarmup,
                isBodyweight: true,
                durationSeconds: duration,
                machineVariant: nil,
                weightUnit: selectedWeightUnit.rawValue,
                to: logged, context: modelContext
            )
            if !setIsWarmup { onRestTimer() }
            prefillFromLastSet()
        } catch {
            onError(error.localizedDescription)
        }
    }

    private func savePinSet() {
        let reps = (setMetric == .reps) ? (Int(setReps) ?? 0) : 1
        let duration = (setMetric == .time) ? max(1, timedEntryElapsedCentiseconds / 100) : nil
        guard (setMetric == .reps ? reps > 0 : (duration ?? 0) > 0) else {
            onError(setMetric == .reps ? "Enter valid reps." : "Start timer and log elapsed time.")
            return
        }
        do {
            try viewModel.addSet(
                reps: reps, weight: 0, isWarmup: setIsWarmup,
                pinPosition: setPinPosition.trimmingCharacters(in: .whitespacesAndNewlines),
                durationSeconds: duration,
                machineVariant: nil,
                weightUnit: selectedWeightUnit.rawValue,
                to: logged, context: modelContext
            )
            if !setIsWarmup { onRestTimer() }
            prefillFromLastSet()
        } catch {
            onError(error.localizedDescription)
        }
    }

    private func openSetEditor(for set: LoggedSet) {
        editingSet = set
        setReps = String(set.reps)
        setWeight = String(format: "%g", set.weight)
        setIsWarmup = set.isWarmup
        cardioDurationMinutes = set.cardioDurationMinutes.map { String(format: "%g", $0) } ?? "20"
        cardioSpeedDescription = set.cardioSpeedDescription ?? "6 mph"
        cardioZoneDescription = set.cardioZoneDescription ?? "Zone 2"
        cardioDistance = set.cardioDistance.map { String(format: "%g", $0) } ?? ""
        cardioInclinePercent = set.cardioInclinePercent.map { String(format: "%g", $0) } ?? ""
        setUsesPinTracking = (set.pinPosition?.isEmpty == false)
        setPinPosition = set.pinPosition ?? "8th pin"
        loggerMode = set.isBodyweight ? .bodyweight : (setUsesPinTracking ? .pin : .weight)
        setMetric = (set.durationSeconds != nil) ? .time : .reps
        setDurationSeconds = set.durationSeconds.map(formatDurationInput) ?? "00:00.00"
        timedEntryElapsedCentiseconds = (set.durationSeconds ?? 0) * 100
        showingSetEditor = true
    }

    private func setEditorSheet(editing set: LoggedSet) -> some View {
        NavigationStack {
            Form {
                Section("Set") {
                    if isCardio {
                        TextField("Duration (min)", text: $cardioDurationMinutes)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                        TextField("Speed / Pace (e.g., 6 mph)", text: $cardioSpeedDescription)
                        TextField("Zone (e.g., Zone 2)", text: $cardioZoneDescription)
                        TextField("Distance (optional)", text: $cardioDistance)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                        TextField("Incline % (optional)", text: $cardioInclinePercent)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                    } else {
                        Picker("Metric", selection: $setMetric) {
                            Text("Reps").tag(SetMetric.reps)
                            Text("Time").tag(SetMetric.time)
                        }
                        .pickerStyle(.segmented)

                        if setMetric == .reps {
                            TextField("Reps", text: $setReps)
#if os(iOS)
                                .keyboardType(.numberPad)
#endif
                        } else {
                            TextField("Time (MM:SS.CC)", text: $setDurationSeconds)
#if os(iOS)
                                .keyboardType(.numberPad)
#endif
                        }

                        Picker("Mode", selection: $loggerMode) {
                            Text("Weight").tag(LoggerMode.weight)
                            Text("Pin").tag(LoggerMode.pin)
                            Text("Bodyweight").tag(LoggerMode.bodyweight)
                        }
                        .pickerStyle(.segmented)

                        if loggerMode == .pin {
                            TextField("Pin (e.g., 8th pin)", text: $setPinPosition)
                        } else if loggerMode == .weight {
                            TextField("Weight (\(selectedWeightUnit.displayName.uppercased()))", text: $setWeight)

#if os(iOS)
                                .keyboardType(.decimalPad)
#endif
                            if let typedWeight = Double(setWeight), typedWeight > 0 {
                                let opposite: WeightUnit = selectedWeightUnit == .lbs ? .kg : .lbs
                                let converted = WeightUnitSettings.convert(typedWeight, from: selectedWeightUnit, to: opposite)
                                Text("\u{2248} \(String(format: "%.1f", converted)) \(opposite.displayName.uppercased())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Toggle("Warm-up Set", isOn: $setIsWarmup)
                }

                Section {
                    Button(role: .destructive) {
                        do {
                            try viewModel.deleteSet(set, from: logged, context: modelContext)
                        } catch {
                            onError(error.localizedDescription)
                        }
                        showingSetEditor = false
                        editingSet = nil
                    } label: {
                        Text(isCardio ? "Delete Entry" : "Delete Set")
                    }
                }
            }
            .navigationTitle(isCardio ? "Edit Cardio Entry" : "Edit Set")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingSetEditor = false
                        editingSet = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            let reps = (setMetric == .reps) ? (Int(setReps) ?? 0) : 1
                            let weight = (loggerMode == .weight) ? (Double(setWeight) ?? 0) : 0
                            let unit = selectedWeightUnit.rawValue
                            try viewModel.updateSet(
                                set, reps: reps, weight: weight, isWarmup: setIsWarmup,
                                cardioDurationMinutes: Double(cardioDurationMinutes),
                                cardioSpeedDescription: cardioSpeedDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                                cardioZoneDescription: cardioZoneDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                                cardioDistance: Double(cardioDistance),
                                cardioInclinePercent: Double(cardioInclinePercent),
                                pinPosition: loggerMode == .pin ? setPinPosition.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                                isBodyweight: loggerMode == .bodyweight,
                                durationSeconds: setMetric == .time ? parseDurationInput(setDurationSeconds) : nil,
                                machineVariant: nil,
                                weightUnit: unit,
                                context: modelContext
                            )
                            showingSetEditor = false
                            editingSet = nil
                        } catch {
                            onError(error.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Progressive Overload

    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    private func progressiveSuggestion() -> ProgressiveSuggestion? {
        guard let exercise = logged.exercise else { return nil }
        guard !isCardio else { return nil }
        guard !logged.sets.contains(where: { ($0.pinPosition?.isEmpty == false) }) else { return nil }

        let activeSessionId = viewModel.activeSession?.id
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

        let currentSessionSets = logged.sets
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
}
