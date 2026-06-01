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
    @State private var pendingFavoriteFromMap = false

    private var panelTheme: Design.PanelTheme {
        switch activePanel {
        case .navigation, .speedDetail:
            return .standard
        case .settings, .boatProfile, .paywall, .locationSharing, .waterLevel:
            return .standard
        case .none:
            return .standard
        }
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad (any orientation) or large screen
    private var isWideLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
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
        ZStack(alignment: .topLeading) {
            // Full-screen map
            mapLayer
                .ignoresSafeArea()

            // Floating dashboard (top-left)
            if activePanel == .none {
                DashboardOverlay(
                    activePanel: $activePanel,
                    panelDetent: $panelDetent
                )
                .padding(.top, 16)
                .padding(.leading, 16)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            // Sidebar panel (when a panel is active)
            if activePanel != .none {
                HStack(spacing: 0) {
                    // Panel sidebar
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(Design.Animation.panel) { activePanel = .none }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, height: 30)
                                    .background(.quaternary, in: Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                        ScrollView {
                            panelContent
                                .padding(.horizontal, 16)
                                .padding(.bottom, 20)
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                    .frame(width: 360)
                    .background(AnyShapeStyle(.ultraThickMaterial))
                    .environment(\.colorScheme, panelTheme == .flits ? .dark : .light)

                    // Dimmed map area — tap to close
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(Design.Animation.panel) { activePanel = .none }
                        }
                }
                .transition(.move(edge: .leading))
            }

            // Map action buttons (bottom-right, always visible)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    HazardReportButton()
                        .padding(.trailing, 16)
                        .padding(.bottom, 20)
                }
            }
        }
        .animation(Design.Animation.panel, value: activePanel)
        .onChange(of: navigationViewModel.isSelectingOnMap) { wasSelecting, isSelecting in
            if wasSelecting && !isSelecting {
                if pendingFavoriteFromMap {
                    pendingFavoriteFromMap = false
                    withAnimation(Design.Animation.panel) {
                        navigationViewModel.showAddFavoriteSheet = true
                    }
                } else {
                    withAnimation(Design.Animation.panel) {
                        activePanel = .navigation
                        panelDetent = .half
                    }
                }
            }
        }
        .overlay { hazardCategoryOverlay }
        .overlay { addFavoriteOverlay }
        .overlay { proximityAlertOverlay }
        .task { await navigationViewModel.loadWaterwayGraph() }
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
                if pendingFavoriteFromMap {
                    // Return to add-favorite dialog after map selection
                    pendingFavoriteFromMap = false
                    withAnimation(Design.Animation.panel) {
                        navigationViewModel.showAddFavoriteSheet = true
                    }
                } else {
                    withAnimation(Design.Animation.panel) {
                        activePanel = .navigation
                        panelDetent = .half
                    }
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
                routePolylines: navigationViewModel.currentRoute?.polylines ?? [],
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
                    case .waterLevel:
                        WaterLevelPanelContent(activePanel: $activePanel)
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
                if pendingFavoriteFromMap {
                    // Return to add-favorite dialog after map selection
                    pendingFavoriteFromMap = false
                    withAnimation(Design.Animation.panel) {
                        navigationViewModel.showAddFavoriteSheet = true
                    }
                } else {
                    withAnimation(Design.Animation.panel) {
                        activePanel = .navigation
                        panelDetent = .half
                    }
                }
            }
        }
        .overlay { hazardCategoryOverlay }
        .overlay { addFavoriteOverlay }
        .overlay { proximityAlertOverlay }
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
        case .waterLevel:
            WaterLevelPanelContent(activePanel: $activePanel)
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
                    pendingFavoriteFromMap = true
                    withAnimation(Design.Animation.quick) {
                        navigationViewModel.showAddFavoriteSheet = false
                    }
                    navigationViewModel.startMapSelection(for: .destination)
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
