import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Kaartstijl") {
                    ForEach(MapStyle.allCases) { style in
                        HStack {
                            Image(systemName: style.iconName)
                                .foregroundStyle(settingsViewModel.mapStyle == style ? .blue : .secondary)
                                .frame(width: 28)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(style.displayName)
                                    .font(.body)
                                Text(style.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if settingsViewModel.mapStyle == style {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Design.Colors.accent)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation {
                                settingsViewModel.mapStyle = style
                            }
                        }
                    }
                }

                Section("Kaartlagen") {
                    Toggle("Boeien en bakens", isOn: $settingsViewModel.showBuoys)
                    Toggle("Brughoogtes", isOn: $settingsViewModel.showBridges)
                    Toggle("Zeemerken (OpenSeaMap)", isOn: $settingsViewModel.showSeamarks)
                }

                Section("Navigatie") {
                    HStack {
                        Text("Kruissnelheid")
                        Spacer()
                        Text(String(format: "%.0f km/h", settingsViewModel.cruisingSpeedKmh))
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $settingsViewModel.cruisingSpeedKmh,
                        in: 5...30,
                        step: 1
                    )
                    Text(String(format: "%.1f knopen", UnitConversion.kmhToKnots(settingsViewModel.cruisingSpeedKmh)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Over") {
                    LabeledContent("Versie", value: "1.0.0")
                    LabeledContent("Kaartdata", value: "PDOK / OpenSeaMap")
                }

                Section {
                    Text("Kaartdata is afkomstig van PDOK (Rijkswaterstaat) en OpenSeaMap. Gebruik deze app niet als vervanging voor officiele vaarkaarten.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Instellingen")
        }
    }
}
