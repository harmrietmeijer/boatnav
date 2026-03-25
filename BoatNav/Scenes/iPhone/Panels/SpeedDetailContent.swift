import SwiftUI

struct SpeedDetailContent: View {
    @EnvironmentObject var speedViewModel: SpeedViewModel
    @Binding var activePanel: ActivePanel

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack {
                Text("Snelheid")
                    .font(.title3.weight(.bold))
                Spacer()
            }
            .padding(.bottom, 24)

            VStack(spacing: 32) {
                // Primary speed - km/h
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", speedViewModel.speedKmh))
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(speedViewModel.isValid ? .primary : .secondary)

                    Text("km/h")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                // Secondary speed - knots
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", speedViewModel.speedKnots))
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(speedViewModel.isValid ? .blue : .secondary)

                    Text("knopen")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if !speedViewModel.isValid {
                    HStack(spacing: 8) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 14))
                        Text("Wachten op GPS signaal...")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
