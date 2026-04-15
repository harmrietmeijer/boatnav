import SwiftUI

struct WeatherBarView: View {
    @EnvironmentObject var weatherVM: WeatherViewModel

    var body: some View {
        if let w = weatherVM.weather {
            HStack(spacing: Design.Spacing.md) {
                // Weather condition
                HStack(spacing: 5) {
                    Image(systemName: w.weatherIcon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(iconColor(for: w.weatherCode))
                        .symbolRenderingMode(.multicolor)
                    Text(String(format: "%.0f°", w.temperature))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }

                thinDivider

                // Wind
                HStack(spacing: 4) {
                    Image(systemName: "wind")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Design.Colors.sky)
                    Text("Bft \(w.beaufort)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                        .rotationEffect(.degrees(w.windDirection))
                        .foregroundStyle(.secondary)
                    Text(w.windDirectionLabel)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                thinDivider

                // Precipitation
                HStack(spacing: 4) {
                    Image(systemName: w.precipitation > 0 ? "drop.fill" : "drop")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(w.precipitation > 0 ? Design.Colors.accent : .secondary)
                    Text(w.precipitation > 0
                         ? String(format: "%.1f mm", w.precipitation)
                         : "Droog")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(w.precipitation > 0 ? .primary : .secondary)
                }
            }
            .padding(.horizontal, Design.Spacing.lg)
            .padding(.vertical, Design.Spacing.sm + 2)
            .glassCard(cornerRadius: Design.Corner.pill)
        }
    }

    private var thinDivider: some View {
        Capsule()
            .fill(.quaternary)
            .frame(width: 1, height: 14)
    }

    private func iconColor(for code: Int) -> Color {
        switch code {
        case 0: return .yellow
        case 1, 2: return Design.Colors.amber
        default: return .gray
        }
    }
}
