import SwiftUI

/// Floating dashboard overlay for iPad — displays speed, navigation, weather
/// and action buttons over the fullscreen map. Designed to be CarPlay-ready:
/// same data structure can feed CarPlay template updates.
struct DashboardOverlay: View {
    @EnvironmentObject var speedViewModel: SpeedViewModel
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @EnvironmentObject var maneuverProximityService: ManeuverProximityService
    @EnvironmentObject var mapViewModel: MapViewModel

    @Binding var activePanel: ActivePanel
    @Binding var panelDetent: PanelDetent

    var body: some View {
        VStack(spacing: 0) {
            // 1. Speed block
            speedSection

            divider

            // 2. Navigation instruction (when navigating)
            if navigationViewModel.isNavigating {
                navigationSection
                divider
            }

            // 3. Weather strip
            if let w = weatherViewModel.weather {
                weatherSection(w)
                divider
            }

            Spacer(minLength: 0)

            // 4. Action buttons
            actionButtons
        }
        .frame(width: 260)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.2), radius: 16, y: 4)
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Speed

    private var speedSection: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", speedViewModel.speedKnots))
                    .font(.system(size: 44, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(speedViewModel.isExceedingLimit ? Design.Red.r4 : .white)
                Text("kn")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Text(String(format: "%.1f km/h", speedViewModel.speedKmh))
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))

            // Speed limit badge
            if let limit = speedViewModel.currentSpeedLimit {
                HStack(spacing: 8) {
                    Text(String(format: "%.0f", limit))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(Design.Red.r4)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.white)
                                .overlay(Circle().stroke(Design.Red.r4, lineWidth: 3))
                        )
                    Text("km/h max")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
    }

    // MARK: - Navigation

    private var navigationSection: some View {
        VStack(spacing: 12) {
            // Upcoming maneuver
            if let maneuver = maneuverProximityService.upcomingManeuver,
               let distance = maneuverProximityService.distanceToManeuver,
               distance <= 500 {
                HStack(spacing: 12) {
                    Image(systemName: maneuverIcon(for: maneuver.type))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Design.Amber.a5)
                        .frame(width: 40, height: 40)
                        .background(Design.Amber.a5.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(maneuver.instruction)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(String(format: "over %.0f m", distance))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(Design.Amber.a5)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Route summary
            if let route = navigationViewModel.currentRoute {
                HStack(spacing: 16) {
                    routeStat(value: route.distanceString, label: "Afstand", color: Design.Blue.b5)
                    routeStat(value: route.timeString, label: "Tijd", color: Design.Green.g5)
                    if !route.bridges.isEmpty {
                        routeStat(value: "\(route.bridges.count)", label: "Bruggen", color: Design.Amber.a5)
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
    }

    // MARK: - Weather

    private func weatherSection(_ w: WeatherService.WeatherData) -> some View {
        HStack(spacing: 14) {
            // Temperature
            HStack(spacing: 4) {
                Image(systemName: w.weatherIcon)
                    .font(.system(size: 14))
                    .symbolRenderingMode(.multicolor)
                Text(String(format: "%.0f°", w.temperature))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            // Wind
            HStack(spacing: 4) {
                Image(systemName: "wind")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Bft \(w.beaufort)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                Text(w.windDirectionLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Precipitation
            if w.precipitation > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Design.Blue.b5)
                    Text(String(format: "%.1f", w.precipitation))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 0) {
            dashboardButton(icon: "arrow.triangle.turn.up.right.diamond.fill", label: "Route") {
                withAnimation(Design.Animation.panel) {
                    activePanel = .navigation
                    panelDetent = .half
                }
            }
            dashboardButton(icon: "location.fill", label: "Centreer") {
                mapViewModel.recenterTrigger = true
            }
            dashboardButton(icon: "sailboat.fill", label: "Boot") {
                withAnimation(Design.Animation.panel) {
                    activePanel = .boatProfile
                    panelDetent = .half
                }
            }
            dashboardButton(icon: "person.2.fill", label: "Delen") {
                withAnimation(Design.Animation.panel) {
                    activePanel = .locationSharing
                    panelDetent = .half
                }
            }
            dashboardButton(icon: "gearshape.fill", label: "Meer") {
                withAnimation(Design.Animation.panel) {
                    activePanel = .settings
                    panelDetent = .half
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
    }

    // MARK: - Helpers

    private func dashboardButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dashboard_\(label.lowercased())")
    }

    private func routeStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(height: 1)
    }

    private func maneuverIcon(for type: RouteManeuver.ManeuverType) -> String {
        switch type {
        case .depart: return "location.fill"
        case .turn(let dir):
            switch dir {
            case .left: return "arrow.turn.up.left"
            case .right: return "arrow.turn.up.right"
            case .slightLeft: return "arrow.up.left"
            case .slightRight: return "arrow.up.right"
            case .straight: return "arrow.up"
            }
        case .bridge: return "arrow.up.and.down.square.fill"
        case .lock: return "door.left.hand.closed"
        case .arrive: return "flag.checkered"
        }
    }
}
