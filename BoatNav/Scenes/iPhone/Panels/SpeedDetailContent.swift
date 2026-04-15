import SwiftUI

struct SpeedDetailContent: View {
    @EnvironmentObject var speedViewModel: SpeedViewModel
    @Binding var activePanel: ActivePanel

    private var speedColor: Color {
        if speedViewModel.isExceedingLimit { return Design.Red.r4 }
        let s = speedViewModel.speedKmh
        if s < 6 { return Design.Blue.b5 }
        if s < 12 { return Design.Green.g5 }
        if s < 20 { return Design.Amber.a5 }
        return Design.Red.r4
    }

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack(spacing: Design.Spacing.sm) {
                Image(systemName: "gauge.open.with.lines.needle.33percent")
                    .foregroundStyle(Design.Blue.b4)
                Text("Snelheid")
                    .font(.title3.weight(.bold))
                Spacer()
            }
            .padding(.bottom, Design.Spacing.xxl)

            VStack(spacing: 32) {
                // Primary speed - km/h
                ZStack {
                    Circle()
                        .stroke(Design.Blue.b4.opacity(0.12), lineWidth: 8)
                        .frame(width: 190, height: 190)
                    Circle()
                        .trim(from: 0, to: min(speedViewModel.speedKmh / 30.0, 1.0))
                        .stroke(
                            Design.Blue.b4,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 190, height: 190)
                        .rotationEffect(.degrees(-90))
                        .animation(Design.Animation.slow, value: speedViewModel.speedKmh)
                    VStack(spacing: Design.Spacing.xs) {
                        Text(String(format: "%.1f", speedViewModel.speedKmh))
                            .font(.system(size: 72, weight: .bold, design: .monospaced))
                            .foregroundStyle(speedViewModel.isValid ? .primary : .secondary)
                            .contentTransition(.numericText())
                        Text("km/h")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Design.Colors.text3)
                    }
                }

                // Secondary speed - knots
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", speedViewModel.speedKnots))
                        .font(.system(size: 48, weight: .semibold, design: .monospaced))
                        .foregroundStyle(speedViewModel.isValid ? Design.Blue.b5 : .secondary)

                    Text("knopen")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Design.Colors.text3)
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
                    .surfaceCard(cornerRadius: Design.Corner.sm)
                }

                Spacer(minLength: 20)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
