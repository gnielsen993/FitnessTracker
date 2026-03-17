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

    @State private var searchText = ""
    @State private var cardioName = ""
    @State private var customExerciseName = ""
    @State private var customExerciseCategory = "Custom"
    @State private var customExerciseEquipment = "Machine"

    private let quickCardio = ["Incline Treadmill Walk", "Jogging", "Cycling", "Rowing", "Hiking"]

    private var theme: Theme { themeManager.theme(for: colorScheme) }

    private var filteredExercises: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return exercises }
        return exercises.filter {
            $0.name.lowercased().contains(query) || $0.category.lowercased().contains(query)
        }
    }


    private func addCustomExercise() {
        let name = customExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = customExerciseCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom" : customExerciseCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let equipment = customExerciseEquipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Machine" : customExerciseEquipment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let existing = exercises.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            if !split.templateExercises.contains(where: { $0.id == existing.id }) {
                split.templateExercises.append(existing)
                try? modelContext.save()
            }
        } else {
            let created = Exercise(name: name, category: category, equipment: equipment)
            modelContext.insert(created)
            split.templateExercises.append(created)
            try? modelContext.save()
        }

        customExerciseName = ""
    }

    private func addCardioExercise(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if let existing = exercises.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            if !split.templateExercises.contains(where: { $0.id == existing.id }) {
                split.templateExercises.append(existing)
                try? modelContext.save()
            }
            return
        }

        let newExercise = Exercise(name: name, category: "Cardio", equipment: "Cardio")
        modelContext.insert(newExercise)
        split.templateExercises.append(newExercise)
        try? modelContext.save()
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
            .navigationTitle("Routine Builder: \(split.name)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
