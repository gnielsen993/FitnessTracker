import SwiftUI
import SwiftData
import DesignKit

struct RoutinesLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \WorkoutType.name) private var routines: [WorkoutType]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var draftName: String = ""
    @State private var selectedRoutine: WorkoutType?

    private var theme: Theme { themeManager.theme(for: colorScheme) }

    var body: some View {
        List {
            Section("Create Routine") {
                HStack {
                    TextField("Routine name", text: $draftName)
                    Button("Add") {
                        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        modelContext.insert(WorkoutType(name: trimmed))
                        try? modelContext.save()
                        draftName = ""
                    }
                    .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section("Routines") {
                if routines.isEmpty {
                    Text("No routines yet. Add one above.")
                        .foregroundStyle(.secondary)
                }

                ForEach(routines) { routine in
                    Button {
                        selectedRoutine = routine
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(routine.name)
                                Text("\(routine.templateItems.count) exercises")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for index in offsets {
                        BootstrapService.markRoutineDeleted(routines[index].name)
                        modelContext.delete(routines[index])
                    }
                    try? modelContext.save()
                }
            }
        }
        .navigationTitle("Routines")
        .sheet(item: $selectedRoutine) { routine in
            TemplateEditorSheet(split: routine, exercises: exercises)
        }
    }
}
