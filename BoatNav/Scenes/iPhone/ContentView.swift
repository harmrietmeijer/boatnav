import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mapViewModel: MapViewModel
    @EnvironmentObject var speedViewModel: SpeedViewModel
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @EnvironmentObject var hazardReportViewModel: HazardReportViewModel
    @EnvironmentObject var locationSharingViewModel: LocationSharingViewModel
    @EnvironmentObject var weatherViewModel: WeatherViewModel

    @State private var activePanel: ActivePanel = .none
    @State private var panelDetent: PanelDetent = .half
    @State private var favoriteName = ""
    @State private var favoriteDescription = ""

    private var panelTheme: Design.PanelTheme {
        switch activePanel {
        case .navigation:
            return navigationViewModel.isNavigating ? .navigation : .route
        case .speedDetail:
            return .navigation
        case .settings, .boatProfile, .paywall, .locationSharing:
            return .standard
        case .none:
            return .standard
        }
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad landscape or large screen in landscape
    private var isWideLayout: Bool {
        horizontalSizeClass == .regular
    }

    var body: some View {
        if isWideLayout {
            wideBody
        } else {
            compactBody
        }
    }

    // MARK: - Wide layout (iPad landscape — CarPlay-style)

    private var wideBody: some View {
        HStack(spacing: 0) {
            // Left sidebar: data + controls
            VStack(spacing: 0) {
                // Speed display
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", speedViewModel.speedKnots))
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(speedViewModel.isExceedingLimit ? Design.Red.r4 : .white)
                        Text("kn")
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundStyle(Design.Blue.b6)
                    }
                    Text(String(format: "%.1f km/h", speedViewModel.speedKmh))
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(Design.Blue.b6)

                    if let limit = speedViewModel.currentSpeedLimit {
                        HStack(spacing: 8) {
                            Text(String(format: "%.0f", limit))
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(Design.Red.r4)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(.white)
                                        .overlay(Circle().stroke(Design.Red.r4, lineWidth: 3))
                                )
                            Text("km/h max")
                                .font(.caption)
                                .foregroundStyle(Design.Blue.b6)
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Design.Spacing.xl)

                Divider().overlay(Color.white.opacity(0.1))

                // Navigation info
                if navigationViewModel.isNavigating, let route = navigationViewModel.currentRoute {
                    VStack(spacing: 12) {
                        if let maneuver = route.maneuvers.first {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.turn.up.right")
                                    .font(.title2)
                                    .foregroundStyle(Design.Blue.b6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(maneuver.instruction)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                }
                            }
                        }

                        HStack(spacing: Design.Spacing.xl) {
                            VStack(spacing: 2) {
                                Text(route.distanceString)
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                Text("Afstand")
                                    .font(.caption2)
                                    .foregroundStyle(Design.Blue.b6)
                            }
                            VStack(spacing: 2) {
                                Text(route.timeString)
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                Text("Tijd")
                                    .font(.caption2)
                                    .foregroundStyle(Design.Blue.b6)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Design.Spacing.lg)
                }

                // Weather
                if let w = weatherViewModel.weather {
                    Divider().overlay(Color.white.opacity(0.1))
                    HStack(spacing: Design.Spacing.md) {
                        Image(systemName: w.weatherIcon)
                            .symbolRenderingMode(.multicolor)
                        Text(String(format: "%.0f°", w.temperature))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(Design.Blue.b6)
                        Text("Bft \(w.beaufort)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Design.Blue.b6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Design.Spacing.lg)
                }

                Spacer()

                // Action buttons
                VStack(spacing: Design.Spacing.sm) {
                    sidebarButton(icon: "location.fill", label: "Centreer") {
                        mapViewModel.recenterTrigger = true
                    }
                    sidebarButton(icon: "arrow.triangle.turn.up.right.diamond.fill", label: "Navigatie") {
                        withAnimation(Design.Animation.panel) {
                            activePanel = .navigation
                            panelDetent = .half
                        }
                    }
                    sidebarButton(icon: "sailboat.fill", label: "Boot") {
                        withAnimation(Design.Animation.panel) {
                            activePanel = .boatProfile
                            panelDetent = .half
                        }
                    }
                    sidebarButton(icon: "gearshape.fill", label: "Instellingen") {
                        withAnimation(Design.Animation.panel) {
                            activePanel = .settings
                            panelDetent = .half
                        }
                    }
                }
                .padding(.bottom, Design.Spacing.xl)
            }
            .frame(width: 200)
            .background(Design.Ink.primary)

            // Right: full map + overlays
            ZStack {
                mapLayer
                overlayLayers
            }
        }
        .ignoresSafeArea()
    }

    private func sidebarButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(Design.Blue.b6)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.Spacing.sm)
        }
    }

    // MARK: - Compact layout (iPhone — original)

    private var compactBody: some View {
        ZStack {
            mapLayer
            compactOverlays
        }
        .animation(Design.Animation.panel, value: activePanel)
        .animation(Design.Animation.panel, value: navigationViewModel.isSelectingOnMap)
        .animation(Design.Animation.panel, value: navigationViewModel.isNavigating)
        .onChange(of: navigationViewModel.isSelectingOnMap) { wasSelecting, isSelecting in
            if wasSelecting && !isSelecting {
                withAnimation(Design.Animation.panel) {
                    activePanel = .navigation
                    panelDetent = .half
                }
            }
        }
        .overlay { hazardCategoryOverlay }
        .overlay { addFavoriteOverlay }
        .overlay { proximityAlertOverlay }
        .task { await navigationViewModel.loadWaterwayGraph() }
    }

    // MARK: - Shared map layer

    private var mapLayer: some View {
        MapViewRepresentable(
                mapViewModel: mapViewModel,
                navigationViewModel: navigationViewModel,
                annotations: mapViewModel.annotations,
                hazardAnnotations: hazardReportViewModel.annotations,
                friendAnnotations: locationSharingViewModel.friendAnnotations,
                routeCoordinates: navigationViewModel.currentRoute?.coordinates ?? [],
                startCoordinate: navigationViewModel.startSelection.coordinate,
                destinationCoordinate: navigationViewModel.destinationSelection.coordinate,
                isSelectingOnMap: navigationViewModel.isSelectingOnMap,
                mapStyle: settingsViewModel.mapStyle,
                showSeamarks: settingsViewModel.showSeamarks,
                showBuoys: settingsViewModel.showBuoys,
                showBridges: settingsViewModel.showBridges,
                showRestaurants: settingsViewModel.showRestaurants,
                recenterOnUser: mapViewModel.recenterTrigger,
                rwsLockService: mapViewModel.rwsLockService ?? RWSLockService()
            )
            .ignoresSafeArea()
    }

    // MARK: - Overlay layers (shared between layouts)

    private var overlayLayers: some View {
        ZStack {
            // Panels for wide layout
            if activePanel != .none {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(Design.Animation.panel) { activePanel = .none }
                    }
                OverlayPanel(detent: $panelDetent, theme: panelTheme) {
                    withAnimation(Design.Animation.panel) { activePanel = .none }
                } content: {
                    panelContent
                }
                .transition(.move(edge: .bottom))
            }
        }
        .animation(Design.Animation.panel, value: activePanel)
        .overlay { hazardCategoryOverlay }
        .overlay { addFavoriteOverlay }
        .overlay { proximityAlertOverlay }
        .task { await navigationViewModel.loadWaterwayGraph() }
    }

    private var compactOverlays: some View {
        ZStack {
            // Layer 1: Top overlays
            VStack {
                // Weather bar
                WeatherBarView()
                    .padding(.top, Design.Spacing.xs)

                // Map selection banner
                if navigationViewModel.isSelectingOnMap {
                    MapSelectionBanner(
                        isSelectingStart: navigationViewModel.mapSelectingFor == .start,
                        onCancel: {
                            navigationViewModel.cancelMapSelection()
                            withAnimation(Design.Animation.panel) {
                                activePanel = .navigation
                                panelDetent = .half
                            }
                        }
                    )
                    .padding(.top, Design.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Active navigation strip
                if navigationViewModel.isNavigating,
                   let route = navigationViewModel.currentRoute,
                   activePanel != .navigation {
                    ActiveNavigationStrip(route: route) {
                        withAnimation(Design.Animation.panel) {
                            activePanel = .navigation
                            panelDetent = .half
                        }
                    }
                    .padding(.top, navigationViewModel.isSelectingOnMap ? Design.Spacing.xs : Design.Spacing.sm)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }

            // Layer 2: Menu buttons (right side) + hazard report button
            GeometryReader { geo in
                let isLandscape = geo.size.width > geo.size.height
                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        HazardReportButton()
                            .padding(.leading, isLandscape ? geo.safeAreaInsets.leading + Design.Spacing.lg : Design.Spacing.lg)
                        Spacer()
                    }
                    .padding(.bottom, isLandscape ? 80 : 160)
                }
            }

            MapButtonCluster(activePanel: $activePanel)

            // Layer 3: Data strip (bottom, full width)
            if activePanel == .none {
                GeometryReader { geo in
                    let isLandscape = geo.size.width > geo.size.height
                    VStack {
                        Spacer()
                        SpeedPill(speedViewModel: speedViewModel) {
                            withAnimation(Design.Animation.panel) {
                                activePanel = .speedDetail
                                panelDetent = .half
                            }
                        }
                        .padding(.horizontal, isLandscape ? geo.safeAreaInsets.leading + Design.Spacing.lg : Design.Spacing.lg)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, Design.Spacing.sm))
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Layer 4: Overlay panel
            if activePanel != .none {
                OverlayPanel(detent: $panelDetent, theme: panelTheme) {
                    withAnimation(Design.Animation.panel) {
                        activePanel = .none
                    }
                } content: {
                    switch activePanel {
                    case .navigation:
                        NavigationPanelContent(
                            panelDetent: $panelDetent,
                            activePanel: $activePanel
                        )
                    case .settings:
                        SettingsPanelContent(activePanel: $activePanel)
                    case .speedDetail:
                        SpeedDetailContent(activePanel: $activePanel)
                    case .boatProfile:
                        BoatProfilePanelContent()
                    case .paywall:
                        PaywallPanelContent(activePanel: $activePanel)
                    case .locationSharing:
                        LocationSharingPanelContent(activePanel: $activePanel)
                    case .none:
                        EmptyView()
                    }
                }
                .transition(.move(edge: .bottom))
            }
        }
        .animation(Design.Animation.panel, value: activePanel)
        .animation(Design.Animation.panel, value: navigationViewModel.isSelectingOnMap)
        .animation(Design.Animation.panel, value: navigationViewModel.isNavigating)
        // Auto-open navigation panel after map selection
        .onChange(of: navigationViewModel.isSelectingOnMap) { wasSelecting, isSelecting in
            if wasSelecting && !isSelecting {
                withAnimation(Design.Animation.panel) {
                    activePanel = .navigation
                    panelDetent = .half
                }
            }
        }
        .overlay { hazardCategoryOverlay }
        .overlay { addFavoriteOverlay }
        .overlay { proximityAlertOverlay }
        .task { await navigationViewModel.loadWaterwayGraph() }
    }

    // MARK: - Panel content (shared)

    @ViewBuilder
    private var panelContent: some View {
        switch activePanel {
        case .navigation:
            NavigationPanelContent(panelDetent: $panelDetent, activePanel: $activePanel)
        case .settings:
            SettingsPanelContent(activePanel: $activePanel)
        case .speedDetail:
            SpeedDetailContent(activePanel: $activePanel)
        case .boatProfile:
            BoatProfilePanelContent()
        case .paywall:
            PaywallPanelContent(activePanel: $activePanel)
        case .locationSharing:
            LocationSharingPanelContent(activePanel: $activePanel)
        case .none:
            EmptyView()
        }
    }

    // MARK: - Overlay dialogs (shared)

    @ViewBuilder
    private var hazardCategoryOverlay: some View {
        BrandedDialog(
            isPresented: hazardReportViewModel.showCategoryPicker,
            isFlitsStyle: true,
            onDismiss: {
                withAnimation(Design.Animation.quick) {
                    hazardReportViewModel.showCategoryPicker = false
                }
            }
        ) {
            HazardCategoryPicker()
                .environmentObject(hazardReportViewModel)
        }
    }

    @ViewBuilder
    private var addFavoriteOverlay: some View {
        BrandedDialog(
            isPresented: navigationViewModel.showAddFavoriteSheet,
            onDismiss: {
                withAnimation(Design.Animation.quick) {
                    favoriteName = ""
                    favoriteDescription = ""
                    navigationViewModel.showAddFavoriteSheet = false
                }
            }
        ) {
            addFavoriteContent
        }
    }

    @ViewBuilder
    private var proximityAlertOverlay: some View {
        if let report = hazardReportViewModel.proximityAlert {
            BrandedDialog(
                isPresented: true,
                onDismiss: { hazardReportViewModel.proximityAlert = nil }
            ) {
                BrandedAlertContent(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: Design.Colors.amber,
                    title: "Melding in de buurt",
                    message: "\(report.category.displayName) gemeld op deze locatie. Is dit er nog?",
                    buttons: [
                        BrandedAlertButton(title: "Ja, nog aanwezig", style: .primary) {
                            hazardReportViewModel.confirmStillPresent(for: report.id)
                        },
                        BrandedAlertButton(title: "Nee, verwijderd", style: .destructive) {
                            hazardReportViewModel.voteRemoval(for: report.id)
                        }
                    ]
                )
            }
        }
    }

    // MARK: - Add Favorite Content (Branded)

    private var addFavoriteContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Favoriet toevoegen")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(Design.Animation.quick) {
                        favoriteName = ""
                        favoriteDescription = ""
                        navigationViewModel.showAddFavoriteSheet = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .background(.quaternary, in: Circle())
                }
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.top, Design.Spacing.xl)
            .padding(.bottom, Design.Spacing.lg)

            VStack(spacing: 10) {
                TextField("Naam (bijv. Jachthaven Westergoot)", text: $favoriteName)
                    .font(.subheadline)
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: Design.Corner.small))

                TextField("Omschrijving (optioneel)", text: $favoriteDescription)
                    .font(.subheadline)
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: Design.Corner.small))
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.bottom, Design.Spacing.lg)

            VStack(spacing: 2) {
                if navigationViewModel.destinationSelection != .none {
                    Button {
                        guard let coord = navigationViewModel.destinationSelection.coordinate else { return }
                        navigationViewModel.addFavorite(
                            name: favoriteName.isEmpty ? navigationViewModel.destinationSelection.displayName : favoriteName,
                            description: favoriteDescription,
                            coordinate: coord
                        )
                        withAnimation(Design.Animation.quick) {
                            favoriteName = ""
                            favoriteDescription = ""
                            navigationViewModel.showAddFavoriteSheet = false
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "flag.fill")
                                .foregroundStyle(Design.Red.r4)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bestemming")
                                    .font(.subheadline.weight(.medium))
                                Text(navigationViewModel.destinationSelection.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Design.Colors.accent)
                        }
                        .padding(.horizontal, Design.Spacing.xl)
                        .padding(.vertical, 12)
                    }
                    .foregroundStyle(.primary)
                }

                if navigationViewModel.startSelection != .none,
                   navigationViewModel.startSelection != .currentLocation {
                    if navigationViewModel.destinationSelection != .none {
                        Divider().padding(.leading, 56)
                    }
                    Button {
                        guard let coord = navigationViewModel.startSelection.coordinate else { return }
                        navigationViewModel.addFavorite(
                            name: favoriteName.isEmpty ? navigationViewModel.startSelection.displayName : favoriteName,
                            description: favoriteDescription,
                            coordinate: coord
                        )
                        withAnimation(Design.Animation.quick) {
                            favoriteName = ""
                            favoriteDescription = ""
                            navigationViewModel.showAddFavoriteSheet = false
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(Design.Green.g4)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Startlocatie")
                                    .font(.subheadline.weight(.medium))
                                Text(navigationViewModel.startSelection.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Design.Colors.accent)
                        }
                        .padding(.horizontal, Design.Spacing.xl)
                        .padding(.vertical, 12)
                    }
                    .foregroundStyle(.primary)
                }

                Divider().padding(.leading, 56)

                Button {
                    withAnimation(Design.Animation.quick) {
                        navigationViewModel.showAddFavoriteSheet = false
                    }
                    navigationViewModel.startMapSelection(for: .destination)
                    withAnimation(Design.Animation.panel) {
                        panelDetent = .collapsed
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(Design.Colors.accent)
                            .frame(width: 24)
                        Text("Kies op kaart")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, Design.Spacing.xl)
                    .padding(.vertical, 12)
                }
                .foregroundStyle(.primary)
            }
            .padding(.bottom, Design.Spacing.lg)

            Text("Selecteer eerst een bestemming via zoeken of de kaart, en voeg die dan toe als favoriet.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Design.Spacing.xl)
                .padding(.bottom, Design.Spacing.xl)
        }
    }
}
