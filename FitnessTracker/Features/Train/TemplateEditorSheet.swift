import SwiftUI
import SwiftData
import DesignKit

// MARK: - Template editor

struct TemplateEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    let split: WorkoutType
    let exercises: [Exercise]

    @State private var routineName: String = ""
    @State private var searchText = ""
    @State private var cardioName = ""
    @State private var customExerciseName = ""
    @State private var customExerciseCategory = "Custom"
    @State private var customExerciseEquipment = "Machine"
    @State private var expandedCategories: Set<String> = []

    private let quickCardio = ["Incline Treadmill Walk", "Jogging", "Cycling", "Rowing", "Hiking"]

    private var theme: Theme { themeManager.theme(for: colorScheme) }

    private var groupedFilteredExercises: [(category: String, items: [Exercise])] {
        exercises.groupedByCategory(filter: searchText)
    }

    private func addTemplateItem(for exercise: Exercise) {
        guard !split.templateItems.contains(where: { $0.exercise?.id == exercise.id }) else { return }
        let nextIndex = (split.templateItems.map(\.orderIndex).max() ?? -1) + 1
        let item = TemplateExercise(orderIndex: nextIndex, defaultSets: 3, routine: split, exercise: exercise)
        modelContext.insert(item)
        split.templateItems.append(item)
        try? modelContext.save()
    }

    private func addCustomExercise() {
        let name = customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = customExerciseCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom" : customExerciseCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let equipment = customExerciseEquipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Machine" : customExerciseEquipment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let existing = exercises.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            addTemplateItem(for: existing)
        } else {
            let created = Exercise(name: name, category: category, equipment: equipment)
            modelContext.insert(created)
            addTemplateItem(for: created)
        }

        customExerciseName = ""
    }

    private func addCardioExercise(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let existing = exercises.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            addTemplateItem(for: existing)
            return
        }

        let newExercise = Exercise(name: name, category: "Cardio", equipment: "Cardio")
        modelContext.insert(newExercise)
        addTemplateItem(for: newExercise)
    }

    private func removeTemplateItem(_ item: TemplateExercise) {
        split.templateItems.removeAll { $0.id == item.id }
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = split.sortedTemplateItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.orderIndex = index
        }
        try? modelContext.save()
    }


    private func setDefaultSets(_ value: Int, for item: TemplateExercise) {
        item.defaultSets = min(20, max(1, value))
        try? modelContext.save()
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Routine Name") {
                    TextField("Name", text: $routineName)
                        .font(theme.typography.body)
                }

                if !split.templateItems.isEmpty {
                    Section("Current Template") {
                        ForEach(split.sortedTemplateItems) { item in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(item.exercise?.name ?? "Exercise")
                                    Text(item.exercise?.category ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 6) {
                                    Button {
                                        setDefaultSets(item.defaultSets - 1, for: item)
                                    } label: {
                                        Image(systemName: "minus.circle")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)

                                    TextField("Sets", text: Binding(
                                        get: { String(item.defaultSets) },
                                        set: { raw in
                                            if let value = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                                setDefaultSets(value, for: item)
                                            }
                                        }
                                    ))
#if os(iOS)
                                    .keyboardType(.numberPad)
#endif
                                    .multilineTextAlignment(.center)
                                    .frame(width: 44)
                                    .textFieldStyle(.roundedBorder)

                                    Button {
                                        setDefaultSets(item.defaultSets + 1, for: item)
                                    } label: {
                                        Image(systemName: "plus.circle")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.accentColor)
                                }
                                .font(.caption)
                            }
                            .contentShape(Rectangle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removeTemplateItem(item)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { offsets in
                            let items = split.sortedTemplateItems
                            for index in offsets {
                                removeTemplateItem(items[index])
                            }
                        }
                        .onMove(perform: moveItems)
                    }
                }

                Section("Custom Exercise") {
                    TextField("Exercise name", text: $customExerciseName)
                    TextField("Category (e.g., Chest)", text: $customExerciseCategory)
                    TextField("Equipment (e.g., Machine)", text: $customExerciseEquipment)
                    Button("Add Custom Exercise") {
                        addCustomExercise()
                    }
                    .disabled(customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Cardio") {
                    ForEach(quickCardio, id: \.self) { name in
                        Button {
                            addCardioExercise(named: name)
                        } label: {
                            HStack {
                                Text(name)
                                Spacer()
                                Text("Zone 2")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        TextField("Custom cardio", text: $cardioName)
                        Button("Add") {
                            addCardioExercise(named: cardioName)
                            cardioName = ""
                        }
                        .disabled(cardioName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                ForEach(groupedFilteredExercises, id: \.category) { group in
                    Section {
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: {
                                    !searchText.isEmpty || expandedCategories.contains(group.category)
                                },
                                set: { isExpanded in
                                    if isExpanded {
                                        expandedCategories.insert(group.category)
                                    } else {
                                        expandedCategories.remove(group.category)
                                    }
                                }
                            )
                        ) {
                            ForEach(group.items) { exercise in
                                let isInTemplate = split.templateItems.contains { $0.exercise?.id == exercise.id }
                                if !isInTemplate {
                                    Button {
                                        addTemplateItem(for: exercise)
                                    } label: {
                                        VStack(alignment: .leading) {
                                            Text(exercise.name)
                                            Text(exercise.equipment)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } label: {
                            Text(group.category)
                                .font(theme.typography.headline)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Routine Builder")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let trimmed = routineName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && trimmed != split.name {
                            split.name = trimmed
                            try? modelContext.save()
                        }
                        dismiss()
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .onAppear {
                routineName = split.name
            }
        }
    }
}
