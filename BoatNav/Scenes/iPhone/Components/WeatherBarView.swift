import SwiftUI

struct WeatherBarView: View {
    @EnvironmentObject var weatherVM: WeatherViewModel

    var body: some View {
        if let w = weatherVM.weather {
            HStack(spacing: Design.Spacing.md) {
                // Weather condition
                HStack(spacing: 5) {
                    Image(systemName: w.weatherIcon)
                        .font(.system(size: 14, weight: .medium))
                        .symbolRenderingMode(.multicolor)
                    Text(String(format: "%.0f°", w.temperature))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Design.Blue.b5)
                }

                divider

                // Wind
                HStack(spacing: 4) {
                    Image(systemName: "wind")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Design.Blue.b4)
                    Text("Bft \(w.beaufort)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Design.Blue.b5)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                        .rotationEffect(.degrees(w.windDirection))
                        .foregroundStyle(Design.Gray.g4)
                    Text(w.windDirectionLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Design.Gray.g4)
                }

                divider

                // Precipitation
                HStack(spacing: 4) {
                    Image(systemName: w.precipitation > 0 ? "drop.fill" : "drop")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(w.precipitation > 0 ? Design.Blue.b4 : Design.Gray.g4)
                    Text(w.precipitation > 0
                         ? String(format: "%.1f mm", w.precipitation)
                         : "Droog")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(w.precipitation > 0 ? Design.Blue.b5 : Design.Gray.g4)
                }
            }
            .padding(.horizontal, Design.Spacing.lg)
            .padding(.vertical, Design.Spacing.sm + 2)
            .tintedCard(
                tint: Design.Ink.secondary,
                border: Color.white.opacity(0.06),
                cornerRadius: Design.Corner.pill
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 14)
    }
}
