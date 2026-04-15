import SwiftUI

struct SpeedPill: View {
    @ObservedObject var speedViewModel: SpeedViewModel
    let onTap: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            onTap()
        } label: {
            HStack(spacing: Design.Spacing.lg) {
                // Speed limit indicator
                if let limit = speedViewModel.currentSpeedLimit {
                    speedLimitBadge(limit: limit)
                }

                dataValue(
                    value: String(format: "%.1f", speedViewModel.speedKmh),
                    unit: "km/h",
                    isWarning: speedViewModel.isExceedingLimit
                )

                Rectangle()
                    .fill(Design.Colors.border)
                    .frame(width: 1, height: 28)

                dataValue(
                    value: String(format: "%.1f", speedViewModel.speedKnots),
                    unit: "kn",
                    isWarning: false
                )
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.vertical, Design.Spacing.md)
            .surfaceCard(cornerRadius: Design.Corner.lg)
        }
        .buttonStyle(.boatNav)
    }

    private func speedLimitBadge(limit: Double) -> some View {
        Text(String(format: "%.0f", limit))
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .foregroundStyle(Design.Red.r4)
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(Design.Colors.surface)
                    .overlay(Circle().stroke(Design.Red.r3, lineWidth: 2.5))
            )
    }

    private func dataValue(value: String, unit: String, isWarning: Bool) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(isWarning ? Design.Red.r4 : Design.Colors.text)

            Text(unit)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Design.Colors.text3)
                .padding(.top, 6)
        }
    }
}
