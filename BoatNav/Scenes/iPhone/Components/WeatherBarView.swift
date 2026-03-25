import SwiftUI

struct WeatherBarView: View {
    @EnvironmentObject var weatherVM: WeatherViewModel

    var body: some View {
        if let w = weatherVM.weather {
            HStack(spacing: 16) {
                // Weather condition
                HStack(spacing: 6) {
                    Image(systemName: w.weatherIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor(for: w.weatherCode))
                        .symbolRenderingMode(.multicolor)
                    Text(String(format: "%.0f°", w.temperature))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                }

                divider

                // Wind
                HStack(spacing: 5) {
                    Image(systemName: "wind")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.cyan)
                    Text("Bft \(w.beaufort)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(w.windDirection))
                        .foregroundStyle(.secondary)
                    Text(w.windDirectionLabel)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                divider

                // Precipitation
                HStack(spacing: 5) {
                    Image(systemName: w.precipitation > 0 ? "drop.fill" : "drop")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(w.precipitation > 0 ? .blue : .secondary)
                    Text(w.precipitation > 0
                         ? String(format: "%.1f mm", w.precipitation)
                         : "Droog")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(w.precipitation > 0 ? .primary : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 16)
    }

    private func iconColor(for code: Int) -> Color {
        switch code {
        case 0: return .yellow
        case 1, 2: return .orange
        default: return .gray
        }
    }
}
