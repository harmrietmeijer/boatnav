import SwiftUI

struct SpeedDashboardView: View {
    @EnvironmentObject var speedViewModel: SpeedViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                // Main speed display - km/h
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", speedViewModel.speedKmh))
                        .font(.system(size: 96, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(speedViewModel.isValid ? .primary : .secondary)

                    Text("km/h")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                // Secondary speed display - knots
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", speedViewModel.speedKnots))
                        .font(.system(size: 56, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(speedViewModel.isValid ? .blue : .secondary)

                    Text("knopen")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !speedViewModel.isValid {
                    Label("Wachten op GPS signaal...", systemImage: "location.slash")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .navigationTitle("Snelheid")
        }
    }
}
