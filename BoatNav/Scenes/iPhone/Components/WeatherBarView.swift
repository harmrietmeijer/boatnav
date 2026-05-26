import SwiftUI

struct WeatherBarView: View {
    @EnvironmentObject var weatherVM: WeatherViewModel
    @EnvironmentObject var waterLevelVM: WaterLevelViewModel

    var body: some View {
        if weatherVM.weather != nil || waterLevelVM.waterLevel != nil {
            HStack(spacing: Design.Spacing.md) {
                if let w = weatherVM.weather {
                    // Weather condition
                    HStack(spacing: 5) {
                        Image(systemName: w.weatherIcon)
                            .font(.system(size: 14, weight: .medium))
                            .symbolRenderingMode(.multicolor)
                        Text(String(format: "%.0f°", w.temperature))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Design.Blue.b6)
                    }

                    divider

                    // Wind
                    HStack(spacing: 4) {
                        Image(systemName: "wind")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Design.Blue.b4)
                        Text("Bft \(w.beaufort)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Design.Blue.b6)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 8, weight: .bold))
                            .rotationEffect(.degrees(w.windDirection))
                            .foregroundStyle(Design.Gray.g5)
                        Text(w.windDirectionLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Design.Gray.g5)
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

                // Water level / tide
                if let wl = waterLevelVM.waterLevel {
                    if weatherVM.weather != nil { divider }

                    TideChip(waterLevel: wl)
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
            .fill(Color.white.opacity(0.2))
            .frame(width: 1, height: 14)
    }
}

// MARK: - Tide chip

struct TideChip: View {
    let waterLevel: WaterLevelService.WaterLevelData

    private var trendIcon: String {
        switch waterLevel.trend {
        case .rising:  return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable:  return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch waterLevel.trend {
        case .rising:  return Design.Blue.b4
        case .falling: return Design.Red.r4
        case .stable:  return Design.Gray.g4
        }
    }

    private var nextExtremeText: String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        if let high = waterLevel.nextHighTide, let low = waterLevel.nextLowTide {
            // Show whichever comes first
            if high.time < low.time {
                return "HW \(formatter.string(from: high.time))"
            } else {
                return "LW \(formatter.string(from: low.time))"
            }
        } else if let high = waterLevel.nextHighTide {
            return "HW \(formatter.string(from: high.time))"
        } else if let low = waterLevel.nextLowTide {
            return "LW \(formatter.string(from: low.time))"
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "water.waves")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Design.Blue.b4)

            Text(String(format: "%+.0f", waterLevel.waterLevelCm))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Design.Blue.b5)

            Text("cm")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Design.Gray.g5)

            Image(systemName: trendIcon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(trendColor)

            if let extreme = nextExtremeText {
                Text(extreme)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Design.Gray.g5)
            }
        }
    }
}
