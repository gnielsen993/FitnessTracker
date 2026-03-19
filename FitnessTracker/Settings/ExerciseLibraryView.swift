import SwiftUI
import SwiftData
import DesignKit

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var expandedCategories: Set<String> = []
    @State private var customName = ""
    @State private var customCategory = "Custom"
    @State private var customEquipment = "Machine"

    private var theme: Theme { themeManager.theme(for: colorScheme) }

    private var groupedExercises: [(category: String, items: [Exercise])] {
        exercises.groupedByCategory(filter: searchText)
    }

    var body: some View {
        List {
            Section("Add Custom Exercise") {
                TextField("Exercise name", text: $customName)
                TextField("Category (e.g., Chest)", text: $customCategory)
                TextField("Equipment (e.g., Machine)", text: $customEquipment)
                Button("Add Exercise") {
                    addCustomExercise()
                }
                .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if groupedExercises.isEmpty {
                ContentUnavailableView(
                    "No matches",
                    systemImage: "magnifyingglass",
                    description: Text("Try another name or category.")
                )
            } else {
                ForEach(groupedExercises, id: \.category) { group in
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
                                VStack(alignment: .leading) {
                                    Text(exercise.name)
                                    Text(exercise.equipment)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .onDelete { offsets in
                                deleteExercises(from: group.items, at: offsets)
                            }
                        } label: {
                            HStack {
                                Text(group.category)
                                    .font(theme.typography.headline)
                                Spacer()
                                Text("\(group.items.count)")
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
        .navigationTitle("Exercise Library")
    }

    private func addCustomExercise() {
        let name = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let category = customCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Custom"
            : customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let equipment = customEquipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Machine"
            : customEquipment.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !exercises.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return }

        let exercise = Exercise(name: name, category: category, equipment: equipment)
        modelContext.insert(exercise)
        try? modelContext.save()
        customName = ""
    }

    private func deleteExercises(from items: [Exercise], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
        try? modelContext.save()
    }
}
