import SwiftUI

struct SpeedDetailContent: View {
    @EnvironmentObject var speedViewModel: SpeedViewModel
    @Binding var activePanel: ActivePanel

    private var speedColor: Color {
        if speedViewModel.isExceedingLimit { return Design.Colors.danger }
        let s = speedViewModel.speedKmh
        if s < 6 { return Design.Colors.sky }
        if s < 12 { return Design.Colors.mint }
        if s < 20 { return Design.Colors.amber }
        return Design.Colors.coral
    }

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack(spacing: Design.Spacing.sm) {
                Image(systemName: "gauge.open.with.lines.needle.33percent")
                    .foregroundStyle(Design.Colors.accent)
                Text("Snelheid")
                    .font(.title3.weight(.bold))
                Spacer()
            }
            .padding(.bottom, Design.Spacing.xxl)

            VStack(spacing: 32) {
                // Primary speed - km/h
                ZStack {
                    Circle()
                        .stroke(Design.Colors.accent.opacity(0.12), lineWidth: 10)
                        .frame(width: 190, height: 190)
                    Circle()
                        .trim(from: 0, to: min(speedViewModel.speedKmh / 30.0, 1.0))
                        .stroke(
                            speedColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 190, height: 190)
                        .rotationEffect(.degrees(-90))
                        .animation(Design.Animation.slow, value: speedViewModel.speedKmh)
                    VStack(spacing: Design.Spacing.xs) {
                        Text(String(format: "%.1f", speedViewModel.speedKmh))
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(speedViewModel.isValid ? .primary : .secondary)
                            .contentTransition(.numericText())
                        Text("km/h")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                // Secondary speed - knots
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", speedViewModel.speedKnots))
                        .font(.system(size: 48, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(speedViewModel.isValid ? Design.Colors.sky : .secondary)

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
                    .padding(Design.Spacing.md)
                    .groupedCard(cornerRadius: Design.Corner.small)
                }

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
