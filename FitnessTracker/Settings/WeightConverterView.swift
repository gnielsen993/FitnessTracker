import SwiftUI
import DesignKit

struct WeightConverterView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme

    @State private var inputText = ""
    @State private var sourceUnit: WeightUnit = .lbs

    private var theme: Theme { themeManager.theme(for: colorScheme) }

    private var targetUnit: WeightUnit { sourceUnit == .lbs ? .kg : .lbs }

    private var convertedValue: String {
        guard let value = Double(inputText), value >= 0 else { return "—" }
        let result = WeightUnitSettings.convert(value, from: sourceUnit, to: targetUnit)
        return String(format: "%.1f", result)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing.l) {
                DKCard(theme: theme) {
                    VStack(alignment: .leading, spacing: theme.spacing.m) {
                        Text("Weight Converter")
                            .font(theme.typography.headline)
                            .foregroundStyle(theme.colors.textPrimary)

                        Picker("Source unit", selection: $sourceUnit) {
                            Text("LBS").tag(WeightUnit.lbs)
                            Text("KG").tag(WeightUnit.kg)
                        }
                        .pickerStyle(.segmented)

                        TextField("Enter weight", text: $inputText)
                        #if os(iOS)
                            .keyboardType(.decimalPad)
                        #endif
                            .font(theme.typography.title)
                            .foregroundStyle(theme.colors.textPrimary)

                        Divider()

                        HStack {
                            Text(convertedValue)
                                .font(theme.typography.title)
                                .foregroundStyle(theme.colors.accentPrimary)
                            Text(targetUnit.displayName)
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }
                }
            }
            .padding(.vertical, theme.spacing.l)
            .padding(.horizontal, theme.spacing.s)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("Weight Converter")
    }
}
