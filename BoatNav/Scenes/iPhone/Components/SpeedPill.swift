import SwiftUI

struct SpeedPill: View {
    @ObservedObject var speedViewModel: SpeedViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Speed limit indicator
                if let limit = speedViewModel.currentSpeedLimit {
                    speedLimitBadge(limit: limit)
                }

                speedValue(
                    value: speedViewModel.speedKmh,
                    unit: "km/h",
                    isValid: speedViewModel.isValid,
                    isWarning: speedViewModel.isExceedingLimit
                )

                Divider()
                    .frame(height: 32)

                speedValue(
                    value: speedViewModel.speedKnots,
                    unit: "kn",
                    isValid: speedViewModel.isValid
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
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

    private func speedValue(value: Double, unit: String, isValid: Bool, isWarning: Bool = false) -> some View {
        HStack(spacing: 4) {
            Text(String(format: "%.1f", value))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isWarning ? Color.red : (isValid ? Color.primary : Color.secondary))

            Text(unit)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
