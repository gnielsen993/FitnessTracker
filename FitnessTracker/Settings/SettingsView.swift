import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import DesignKit

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WorkoutType.name) private var workoutTypes: [WorkoutType]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var exportDocument: BackupJSONDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var statusMessage: String?

    private let exportService = ExportImportService()
    private let storageVersionService = StorageVersionService()

    private var theme: Theme {
        themeManager.theme(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.l) {
                    DKCard(theme: theme) {
                        VStack(alignment: .leading, spacing: theme.spacing.m) {
                            Text("Appearance")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colors.textPrimary)

                            Picker("Theme", selection: $themeManager.mode) {
                                Text("System").tag(ThemeMode.system)
                                Text("Light").tag(ThemeMode.light)
                                Text("Dark").tag(ThemeMode.dark)
                            }
                            .pickerStyle(.segmented)

                            Picker("Preset", selection: $themeManager.preset) {
                                ForEach(ThemePreset.allCases) { preset in
                                    Text(preset.displayName).tag(preset)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    DKCard(theme: theme) {
                        VStack(alignment: .leading, spacing: theme.spacing.m) {
                            Text("Data")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colors.textPrimary)

                            Text("Storage mode: Local-first")
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textPrimary)

                            Text("Schema version: \(storageVersionService.currentVersion)")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textSecondary)

                            Divider()

                            Text("Backup")
                                .font(theme.typography.headline)
                                .foregroundStyle(theme.colors.textPrimary)

                            DKButton("Export JSON", theme: theme) {
                                do {
                                    let data = try exportService.exportData(from: sessions)
                                    exportDocument = BackupJSONDocument(data: data)
                                    showingExporter = true
                                } catch {
                                    statusMessage = "Export failed: \(error.localizedDescription)"
                                }
                            }

                            DKButton("Import JSON", style: .secondary, theme: theme) {
                                showingImporter = true
                            }

                            if let statusMessage {
                                Text(statusMessage)
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colors.textSecondary)
                            }
                        }
                    }
                }
                .padding(.vertical, theme.spacing.l)
                .padding(.horizontal, theme.spacing.s)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.colors.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "fitnesstracker-backup-v1"
            ) { result in
                switch result {
                case .success:
                    statusMessage = "Export complete."
                case .failure(let error):
                    statusMessage = "Export failed: \(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case .success(let url):
                    do {
                        let data = try Data(contentsOf: url)
                        try exportService.importData(
                            data,
                            into: modelContext,
                            availableWorkoutTypes: workoutTypes,
                            availableExercises: exercises
                        )
                        statusMessage = "Import complete."
                    } catch {
                        statusMessage = "Import failed: \(error.localizedDescription)"
                    }
                case .failure(let error):
                    statusMessage = "Import canceled: \(error.localizedDescription)"
                }
            }
        }
    }
}
