import SwiftUI

struct SettingsPanelContent: View {
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @Binding var activePanel: ActivePanel

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Text("Instellingen")
                    .font(.title3.weight(.bold))
                Spacer()
            }
            .padding(.bottom, 20)

            VStack(spacing: 20) {
                // Map style section
                sectionHeader("Kaartstijl")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(MapStyle.allCases) { style in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                settingsViewModel.mapStyle = style
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: style.iconName)
                                    .font(.system(size: 22))
                                    .foregroundStyle(settingsViewModel.mapStyle == style ? .white : .primary)

                                Text(style.displayName)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(settingsViewModel.mapStyle == style ? .white : .primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                settingsViewModel.mapStyle == style
                                    ? AnyShapeStyle(Color.blue.gradient)
                                    : AnyShapeStyle(.regularMaterial),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        }
                    }
                }

                // Map layers section
                sectionHeader("Kaartlagen")

                VStack(spacing: 0) {
                    settingsToggle(
                        icon: "circle.fill",
                        iconColor: .red,
                        label: "Boeien en bakens",
                        isOn: $settingsViewModel.showBuoys
                    )
                    Divider().padding(.leading, 48)
                    settingsToggle(
                        icon: "arrow.up.and.down.square.fill",
                        iconColor: .orange,
                        label: "Brughoogtes",
                        isOn: $settingsViewModel.showBridges
                    )
                    Divider().padding(.leading, 48)
                    settingsToggle(
                        icon: "fork.knife",
                        iconColor: .brown,
                        label: "Restaurants aan het water",
                        isOn: $settingsViewModel.showRestaurants
                    )
                    Divider().padding(.leading, 48)
                    settingsToggle(
                        icon: "water.waves",
                        iconColor: .blue,
                        label: "Zeemerken (OpenSeaMap)",
                        isOn: $settingsViewModel.showSeamarks
                    )
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                // Cruising speed section
                sectionHeader("Kruissnelheid")

                VStack(spacing: 8) {
                    HStack {
                        Text(String(format: "%.0f km/h", settingsViewModel.cruisingSpeedKmh))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(String(format: "%.1f knopen", UnitConversion.kmhToKnots(settingsViewModel.cruisingSpeedKmh)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Slider(
                        value: $settingsViewModel.cruisingSpeedKmh,
                        in: 5...30,
                        step: 1
                    )
                    .tint(.blue)
                }
                .padding(14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                // Subscription
                sectionHeader("Abonnement")

                Button {
                    activePanel = .paywall
                } label: {
                    HStack {
                        Image(systemName: SubscriptionManager.shared.isPro ? "crown.fill" : "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 18))
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(SubscriptionManager.shared.isPro ? "BoatNav Pro" : "Upgrade naar Pro")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(SubscriptionManager.shared.isPro ? "Je hebt alle functies" : "Route-navigatie, CarPlay & meer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }

                // About
                sectionHeader("Over")

                VStack(spacing: 0) {
                    infoRow(label: "Versie", value: "1.0.0")
                    Divider().padding(.leading, 14)
                    infoRow(label: "Kaartdata", value: "PDOK / OpenSeaMap")
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))

                Text("Kaartdata is afkomstig van PDOK (Rijkswaterstaat) en OpenSeaMap. Gebruik deze app niet als vervanging voor officiele vaarkaarten.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)

                Spacer(minLength: 20)
            }
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsToggle(icon: String, iconColor: Color, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12), in: Circle())

            Text(label)
                .font(.subheadline)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.blue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
