import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mapViewModel: MapViewModel
    @EnvironmentObject var speedViewModel: SpeedViewModel
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @EnvironmentObject var hazardReportViewModel: HazardReportViewModel
    @EnvironmentObject var locationSharingViewModel: LocationSharingViewModel

    @State private var activePanel: ActivePanel = .none
    @State private var panelDetent: PanelDetent = .half
    @State private var favoriteName = ""
    @State private var favoriteDescription = ""

    var body: some View {
        ZStack {
            // Layer 0: Full-screen map (always visible)
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
            VStack {
                Spacer()
                HStack {
                    HazardReportButton()
                        .padding(.leading, Design.Spacing.lg)
                        .padding(.bottom, 100)
                    Spacer()
                }
            }

            MapButtonCluster(activePanel: $activePanel)

            // Layer 3: Speed pill (bottom center)
            if activePanel == .none {
                VStack {
                    Spacer()
                    SpeedPill(speedViewModel: speedViewModel) {
                        withAnimation(Design.Animation.panel) {
                            activePanel = .speedDetail
                            panelDetent = .half
                        }
                    }
                    .padding(.bottom, Design.Spacing.xxl)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Layer 4: Overlay panel
            if activePanel != .none {
                OverlayPanel(detent: $panelDetent) {
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
        .overlay {
            // Hazard category picker
            BrandedDialog(
                isPresented: hazardReportViewModel.showCategoryPicker,
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
        .overlay {
            // Add favorite dialog
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
        .overlay {
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
        .task {
            await navigationViewModel.loadWaterwayGraph()
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
