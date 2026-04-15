import SwiftUI

/// Data strip — the main data overlay floating above the map.
/// Matches the "Live data strip" from the design system document.
struct SpeedPill: View {
    @ObservedObject var speedViewModel: SpeedViewModel
    let onTap: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            onTap()
        } label: {
            VStack(spacing: 0) {
                // Top row — primary data values + status
                HStack(alignment: .top, spacing: Design.Spacing.lg) {
                    // Speed
                    dataKV(
                        label: "Snelheid",
                        value: String(format: "%.1f", speedViewModel.speedKnots),
                        unit: "kn",
                        isWarning: speedViewModel.isExceedingLimit
                    )

                    // Speed km/h
                    dataKV(
                        label: "km/h",
                        value: String(format: "%.1f", speedViewModel.speedKmh),
                        unit: nil,
                        isWarning: speedViewModel.isExceedingLimit
                    )

                    Spacer()

                    // Status pills
                    VStack(alignment: .trailing, spacing: Design.Spacing.xs) {
                        // Speed limit if present
                        if let limit = speedViewModel.currentSpeedLimit {
                            statusPill(
                                text: String(format: "%.0f km/h", limit),
                                dotColor: speedViewModel.isExceedingLimit ? Design.Red.r5 : Design.Blue.b5,
                                textColor: speedViewModel.isExceedingLimit ? Design.Red.r5 : Design.Blue.b5,
                                bg: speedViewModel.isExceedingLimit
                                    ? Color(hex: 0x200505)
                                    : Design.Ink.secondary,
                                border: speedViewModel.isExceedingLimit
                                    ? Color(hex: 0x3A0A0A)
                                    : Color(hex: 0x1E4060)
                            )
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 12)

                // Bottom row — secondary data
                HStack(spacing: Design.Spacing.xl) {
                    smallData(label: "GPS", value: speedViewModel.isValid ? "actief" : "wacht...")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, Design.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Design.Colors.border)
                        .frame(height: 1)
                }
            }
            .surfaceCard(cornerRadius: Design.Corner.lg)
        }
        .buttonStyle(.boatNav)
    }

    // MARK: - Data key-value

    private func dataKV(label: String, value: String, unit: String?, isWarning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Design.Colors.text3)
                .tracking(0.5)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(isWarning ? Design.Red.r4 : Design.Colors.text)

                if let unit {
                    Text(unit)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundStyle(Design.Colors.text3)
                }
            }
        }
    }

    // MARK: - Status pill

    private func statusPill(text: String, dotColor: Color, textColor: Color, bg: Color, border: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dotColor)
                .frame(width: 5, height: 5)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, Design.Spacing.xs)
        .tintedCard(tint: bg, border: border, cornerRadius: Design.Corner.pill)
    }

    // MARK: - Small data

    private func smallData(label: String, value: String) -> some View {
        HStack(spacing: Design.Spacing.xs) {
            Text(label + ":")
                .font(.system(size: 11))
                .foregroundStyle(Design.Colors.text3)
            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Design.Colors.text2)
        }
    }
}
