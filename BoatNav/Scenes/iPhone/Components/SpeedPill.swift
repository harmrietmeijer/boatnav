import SwiftUI

struct SpeedPill: View {
    @ObservedObject var speedViewModel: SpeedViewModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                speedValue(
                    value: speedViewModel.speedKmh,
                    unit: "km/h",
                    isValid: speedViewModel.isValid
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

    private func speedValue(value: Double, unit: String, isValid: Bool) -> some View {
        HStack(spacing: 4) {
            Text(String(format: "%.1f", value))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isValid ? .primary : .secondary)

            Text(unit)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
