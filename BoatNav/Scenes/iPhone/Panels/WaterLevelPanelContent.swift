import SwiftUI

struct WaterLevelPanelContent: View {
    @EnvironmentObject var waterLevelVM: WaterLevelViewModel
    @Binding var activePanel: ActivePanel

    var body: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack(spacing: Design.Spacing.sm) {
                Image(systemName: "water.waves")
                    .foregroundStyle(Design.Colors.accent)
                Text("Waterstand")
                    .font(.title3.weight(.regular))
                Spacer()
            }
            .padding(.bottom, Design.Spacing.xl)

            if let wl = waterLevelVM.waterLevel {
                VStack(spacing: Design.Spacing.xl) {
                    // Station + current level
                    currentLevelCard(wl)

                    // Tide graph
                    if !wl.history.isEmpty {
                        tideGraph(wl)
                    }

                    // Next high/low
                    if wl.nextHighTide != nil || wl.nextLowTide != nil {
                        tideExtremes(wl)
                    }

                    Spacer(minLength: 20)
                }
            } else if waterLevelVM.isLoading {
                VStack(spacing: Design.Spacing.md) {
                    ProgressView()
                        .tint(Design.Colors.accent)
                    Text("Waterstand ophalen...")
                        .font(.subheadline)
                        .foregroundStyle(Design.Colors.text3)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                VStack(spacing: Design.Spacing.md) {
                    Image(systemName: "water.waves.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(Design.Colors.text3)
                    Text("Geen waterstanddata beschikbaar")
                        .font(.subheadline)
                        .foregroundStyle(Design.Colors.text3)
                    Button("Opnieuw proberen") {
                        waterLevelVM.forceRefresh()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Design.Colors.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            }
        }
    }

    // MARK: - Current level card

    private func currentLevelCard(_ wl: WaterLevelService.WaterLevelData) -> some View {
        VStack(spacing: Design.Spacing.sm) {
            Text(wl.stationName)
                .font(.caption.weight(.medium))
                .foregroundStyle(Design.Colors.text3)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%+.0f", wl.waterLevelCm))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(Design.Colors.text)
                    .contentTransition(.numericText())

                Text("cm NAP")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Design.Colors.text3)

                Image(systemName: trendIcon(wl.trend))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(trendColor(wl.trend))
            }

            Text(trendLabel(wl.trend))
                .font(.caption)
                .foregroundStyle(trendColor(wl.trend))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tide graph

    private func tideGraph(_ wl: WaterLevelService.WaterLevelData) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            Text("Verloop")
                .font(.caption.weight(.medium))
                .foregroundStyle(Design.Colors.text3)

            TideGraphView(
                history: wl.history,
                predictions: wl.predictions,
                currentLevel: wl.waterLevelCm,
                currentTime: wl.measurementTime
            )
            .frame(height: 160)

            // Time axis labels
            HStack {
                Text(axisLabel(hoursAgo: 6))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Design.Colors.text3)
                Spacer()
                Text("Nu")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Design.Colors.accent)
                Spacer()
                Text(axisLabel(hoursAhead: 8))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Design.Colors.text3)
            }
        }
    }

    // MARK: - Tide extremes

    private func tideExtremes(_ wl: WaterLevelService.WaterLevelData) -> some View {
        HStack(spacing: Design.Spacing.md) {
            if let high = wl.nextHighTide {
                extremeCard(
                    icon: "arrow.up.to.line",
                    label: "Hoogwater",
                    time: high.time,
                    level: high.levelCm,
                    color: Design.Blue.b4
                )
            }
            if let low = wl.nextLowTide {
                extremeCard(
                    icon: "arrow.down.to.line",
                    label: "Laagwater",
                    time: low.time,
                    level: low.levelCm,
                    color: Design.Red.r4
                )
            }
        }
    }

    private func extremeCard(icon: String, label: String, time: Date, level: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Design.Colors.text3)

            Text(timeFormatter.string(from: time))
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(Design.Colors.text)

            Text(String(format: "%+.0f cm", level))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Design.Colors.text2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Design.Spacing.md)
        .background(Design.Colors.surface, in: RoundedRectangle(cornerRadius: Design.Corner.md))
        .overlay(
            RoundedRectangle(cornerRadius: Design.Corner.md)
                .strokeBorder(Design.Colors.border, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func trendIcon(_ trend: WaterLevelService.WaterLevelData.Trend) -> String {
        switch trend {
        case .rising:  return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable:  return "arrow.right"
        }
    }

    private func trendColor(_ trend: WaterLevelService.WaterLevelData.Trend) -> Color {
        switch trend {
        case .rising:  return Design.Blue.b4
        case .falling: return Design.Red.r4
        case .stable:  return Design.Gray.g4
        }
    }

    private func trendLabel(_ trend: WaterLevelService.WaterLevelData.Trend) -> String {
        switch trend {
        case .rising:  return "Stijgend"
        case .falling: return "Dalend"
        case .stable:  return "Stabiel"
        }
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    private func axisLabel(hoursAgo: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date().addingTimeInterval(-Double(hoursAgo) * 3600))
    }

    private func axisLabel(hoursAhead: Int) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date().addingTimeInterval(Double(hoursAhead) * 3600))
    }
}

// MARK: - Tide Graph

struct TideGraphView: View {
    let history: [WaterLevelService.WaterLevelData.DataPoint]
    let predictions: [WaterLevelService.WaterLevelData.DataPoint]
    let currentLevel: Double
    let currentTime: Date

    private var allPoints: [(time: Date, level: Double, isPrediction: Bool)] {
        let h = history.map { (time: $0.time, level: $0.levelCm, isPrediction: false) }
        let p = predictions.map { (time: $0.time, level: $0.levelCm, isPrediction: true) }
        return (h + p).sorted { $0.time < $1.time }
    }

    private var timeRange: ClosedRange<Date> {
        let start = Date().addingTimeInterval(-6 * 3600)
        let end = Date().addingTimeInterval(8 * 3600)
        return start...end
    }

    private var levelRange: ClosedRange<Double> {
        let levels = allPoints.map(\.level)
        guard let min = levels.min(), let max = levels.max(), max > min else {
            return (currentLevel - 50)...(currentLevel + 50)
        }
        let padding = (max - min) * 0.15
        return (min - padding)...(max + padding)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Grid lines
                gridLines(width: w, height: h)

                // History line (solid)
                let historyPts = history.map { pt in
                    pointFor(time: pt.time, level: pt.levelCm, width: w, height: h)
                }.filter { $0.x >= 0 && $0.x <= w }

                if historyPts.count >= 2 {
                    smoothPath(points: historyPts)
                        .stroke(Design.Colors.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }

                // Prediction line (dashed)
                let predPts = predictions.map { pt in
                    pointFor(time: pt.time, level: pt.levelCm, width: w, height: h)
                }.filter { $0.x >= 0 && $0.x <= w }

                if predPts.count >= 2 {
                    smoothPath(points: predPts)
                        .stroke(Design.Colors.accent.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 4]))
                }

                // "Now" indicator line
                let nowX = xFor(time: Date(), width: w)
                if nowX >= 0 && nowX <= w {
                    Path { p in
                        p.move(to: CGPoint(x: nowX, y: 0))
                        p.addLine(to: CGPoint(x: nowX, y: h))
                    }
                    .stroke(Design.Colors.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    // Current level dot
                    let nowY = yFor(level: currentLevel, height: h)
                    Circle()
                        .fill(Design.Colors.accent)
                        .frame(width: 8, height: 8)
                        .position(x: nowX, y: nowY)
                }

                // Zero line (NAP)
                let zeroY = yFor(level: 0, height: h)
                if zeroY > 0 && zeroY < h {
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: zeroY))
                        p.addLine(to: CGPoint(x: w, y: zeroY))
                    }
                    .stroke(Design.Colors.text3.opacity(0.3), lineWidth: 0.5)

                    Text("NAP")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Design.Colors.text3)
                        .position(x: 18, y: zeroY - 8)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Design.Corner.sm))
        .background(
            RoundedRectangle(cornerRadius: Design.Corner.sm)
                .fill(Design.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.Corner.sm)
                .strokeBorder(Design.Colors.border, lineWidth: 1)
        )
    }

    // MARK: - Coordinate mapping

    private func xFor(time: Date, width: CGFloat) -> CGFloat {
        let start = timeRange.lowerBound.timeIntervalSince1970
        let end = timeRange.upperBound.timeIntervalSince1970
        let t = time.timeIntervalSince1970
        return CGFloat((t - start) / (end - start)) * width
    }

    private func yFor(level: Double, height: CGFloat) -> CGFloat {
        let lo = levelRange.lowerBound
        let hi = levelRange.upperBound
        // Invert: higher level = lower y
        return CGFloat(1.0 - (level - lo) / (hi - lo)) * height
    }

    private func pointFor(time: Date, level: Double, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: xFor(time: time, width: width), y: yFor(level: level, height: height))
    }

    // MARK: - Smooth curve

    private func smoothPath(points: [CGPoint]) -> Path {
        Path { path in
            guard points.count >= 2 else { return }
            path.move(to: points[0])

            if points.count == 2 {
                path.addLine(to: points[1])
                return
            }

            for i in 0..<(points.count - 1) {
                let p0 = i > 0 ? points[i - 1] : points[i]
                let p1 = points[i]
                let p2 = points[i + 1]
                let p3 = i + 2 < points.count ? points[i + 2] : p2

                let tension: CGFloat = 0.3
                let cp1 = CGPoint(
                    x: p1.x + (p2.x - p0.x) * tension,
                    y: p1.y + (p2.y - p0.y) * tension
                )
                let cp2 = CGPoint(
                    x: p2.x - (p3.x - p1.x) * tension,
                    y: p2.y - (p3.y - p1.y) * tension
                )
                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }
        }
    }

    // MARK: - Grid

    private func gridLines(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, size in
            let lineColor = Design.Colors.border.resolve(in: context.environment)
            let style = StrokeStyle(lineWidth: 0.5, dash: [2, 4])

            // Horizontal lines (every ~25cm)
            let lo = levelRange.lowerBound
            let hi = levelRange.upperBound
            let step = max(10, ceil((hi - lo) / 5 / 10) * 10) // round to 10cm increments
            var level = ceil(lo / step) * step
            while level <= hi {
                let y = yFor(level: level, height: height)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: width, y: y))
                context.stroke(path, with: .color(Color(lineColor)), style: style)
                level += step
            }
        }
    }
}
