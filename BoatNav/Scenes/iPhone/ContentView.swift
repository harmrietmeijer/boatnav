import SwiftUI

struct ContentView: View {
    @EnvironmentObject var mapViewModel: MapViewModel
    @EnvironmentObject var speedViewModel: SpeedViewModel
    @EnvironmentObject var navigationViewModel: NavigationViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    @EnvironmentObject var hazardReportViewModel: HazardReportViewModel

    @State private var activePanel: ActivePanel = .none
    @State private var panelDetent: PanelDetent = .half

    var body: some View {
        ZStack {
            // Layer 0: Full-screen map (always visible)
            MapViewRepresentable(
                mapViewModel: mapViewModel,
                navigationViewModel: navigationViewModel,
                annotations: mapViewModel.annotations,
                hazardAnnotations: hazardReportViewModel.annotations,
                routeCoordinates: navigationViewModel.currentRoute?.coordinates ?? [],
                startCoordinate: navigationViewModel.startSelection.coordinate,
                destinationCoordinate: navigationViewModel.destinationSelection.coordinate,
                isSelectingOnMap: navigationViewModel.isSelectingOnMap,
                mapStyle: settingsViewModel.mapStyle,
                showSeamarks: settingsViewModel.showSeamarks,
                showBuoys: settingsViewModel.showBuoys,
                showBridges: settingsViewModel.showBridges
            )
            .ignoresSafeArea()

            // Layer 1: Top overlays
            VStack {
                // Weather bar
                WeatherBarView()
                    .padding(.top, 4)

                // Map selection banner
                if navigationViewModel.isSelectingOnMap {
                    MapSelectionBanner(
                        isSelectingStart: navigationViewModel.mapSelectingFor == .start,
                        onCancel: {
                            navigationViewModel.cancelMapSelection()
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                activePanel = .navigation
                                panelDetent = .half
                            }
                        }
                    )
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Active navigation strip
                if navigationViewModel.isNavigating,
                   let route = navigationViewModel.currentRoute,
                   activePanel != .navigation {
                    ActiveNavigationStrip(route: route) {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            activePanel = .navigation
                            panelDetent = .half
                        }
                    }
                    .padding(.top, navigationViewModel.isSelectingOnMap ? 4 : 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }

            // Layer 2: Menu buttons (right side) + hazard report button
            VStack {
                Spacer()
                HStack {
                    HazardReportButton()
                        .padding(.leading, 16)
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
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            activePanel = .speedDetail
                            panelDetent = .half
                        }
                    }
                    .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Layer 4: Overlay panel
            if activePanel != .none {
                OverlayPanel(detent: $panelDetent) {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
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
                    case .none:
                        EmptyView()
                    }
                }
                .transition(.move(edge: .bottom))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.15), value: activePanel)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: navigationViewModel.isSelectingOnMap)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: navigationViewModel.isNavigating)
        // Auto-open navigation panel after map selection
        .onChange(of: navigationViewModel.isSelectingOnMap) { wasSelecting, isSelecting in
            if wasSelecting && !isSelecting {
                withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                    activePanel = .navigation
                    panelDetent = .half
                }
            }
        }
        .alert(
            "Melding in de buurt",
            isPresented: Binding(
                get: { hazardReportViewModel.proximityAlert != nil },
                set: { if !$0 { hazardReportViewModel.proximityAlert = nil } }
            )
        ) {
            if let report = hazardReportViewModel.proximityAlert {
                Button("Ja, nog aanwezig") {
                    hazardReportViewModel.confirmStillPresent(for: report.id)
                }
                Button("Nee, verwijderd", role: .destructive) {
                    hazardReportViewModel.voteRemoval(for: report.id)
                }
            }
        } message: {
            if let report = hazardReportViewModel.proximityAlert {
                Text("\(report.category.displayName) gemeld op deze locatie. Is dit er nog?")
            }
        }
        .task {
            await navigationViewModel.loadWaterwayGraph()
        }
    }
}
