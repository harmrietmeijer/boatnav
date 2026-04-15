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
                }
                .foregroundStyle(Design.Colors.text)

                divider

                // Wind
                HStack(spacing: 4) {
                    Image(systemName: "wind")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Design.Blue.b4)
                    Text("Bft \(w.beaufort)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Design.Colors.text)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                        .rotationEffect(.degrees(w.windDirection))
                        .foregroundStyle(Design.Colors.text3)
                    Text(w.windDirectionLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Design.Colors.text3)
                }

                divider

                // Precipitation
                HStack(spacing: 4) {
                    Image(systemName: w.precipitation > 0 ? "drop.fill" : "drop")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(w.precipitation > 0 ? Design.Blue.b4 : Design.Colors.text3)
                    Text(w.precipitation > 0
                         ? String(format: "%.1f mm", w.precipitation)
                         : "Droog")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(w.precipitation > 0 ? Design.Colors.text : Design.Colors.text3)
                }
            }
            .padding(.horizontal, Design.Spacing.lg)
            .padding(.vertical, Design.Spacing.sm + 2)
            .surfaceCard(cornerRadius: Design.Corner.pill)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Design.Colors.border)
            .frame(width: 1, height: 14)
    }
}
