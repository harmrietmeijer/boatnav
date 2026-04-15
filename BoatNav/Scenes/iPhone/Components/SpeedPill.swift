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

                speedValue(
                    value: speedViewModel.speedKmh,
                    unit: "km/h",
                    isValid: speedViewModel.isValid,
                    isWarning: speedViewModel.isExceedingLimit,
                    isPrimary: true
                )

                Capsule()
                    .fill(.quaternary)
                    .frame(width: 1, height: 28)

                speedValue(
                    value: speedViewModel.speedKnots,
                    unit: "kn",
                    isValid: speedViewModel.isValid,
                    isPrimary: false
                )
            }
            .padding(.horizontal, Design.Spacing.xxl)
            .padding(.vertical, 14)
            .glassCard(cornerRadius: Design.Corner.pill)
        }
        .buttonStyle(.boatNav)
        .accessibilityLabel("Snelheid: \(String(format: "%.1f", speedViewModel.speedKmh)) kilometer per uur, \(String(format: "%.1f", speedViewModel.speedKnots)) knopen")
        .accessibilityHint("Tik voor snelheidsdetails")
    }

    private func speedLimitBadge(limit: Double) -> some View {
        Text(String(format: "%.0f", limit))
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.red)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(.white)
                    .overlay(Circle().stroke(.red, lineWidth: 2.5))
            )
    }

    private func speedValue(value: Double, unit: String, isValid: Bool, isWarning: Bool = false, isPrimary: Bool = true) -> some View {
        HStack(spacing: Design.Spacing.xs + 2) {
            Text(String(format: "%.1f", value))
                .font(.system(size: isPrimary ? 26 : 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isWarning ? Color.red : (isValid ? (isPrimary ? Color.primary : Design.Colors.accent) : Color.secondary))

            Text(unit)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }
}
