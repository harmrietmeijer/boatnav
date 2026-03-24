import CarPlay
import MapKit
import Combine

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var mapTemplate: CPMapTemplate?
    private var carWindow: CPWindow?
    private var mapViewController: CarPlayMapViewController?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        self.interfaceController = interfaceController
        self.carWindow = window

        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        // Create map view controller
        let mapVC = CarPlayMapViewController(
            mapViewModel: appDelegate.mapViewModel,
            speedViewModel: appDelegate.speedViewModel
        )
        self.mapViewController = mapVC

        // Set the map VC as the window's root
        window.rootViewController = mapVC

        // Create CarPlay map template
        let mapTemplate = CPMapTemplate()
        mapTemplate.mapDelegate = mapVC

        // Add speed bar button
        let speedButton = CPBarButton(title: "-- km/h") { _ in }
        mapTemplate.leadingNavigationBarButtons = [speedButton]

        // Add now playing button
        let nowPlayingButton = CPBarButton(image: UIImage(systemName: "music.note")!) { [weak self] _ in
            let nowPlayingTemplate = CPNowPlayingTemplate.shared
            self?.interfaceController?.pushTemplate(nowPlayingTemplate, animated: true, completion: nil)
        }
        mapTemplate.trailingNavigationBarButtons = [nowPlayingButton]

        // Add map control buttons
        let zoomInButton = CPMapButton { [weak mapVC] _ in
            mapVC?.zoomIn()
        }
        zoomInButton.image = UIImage(systemName: "plus.magnifyingglass")

        let zoomOutButton = CPMapButton { [weak mapVC] _ in
            mapVC?.zoomOut()
        }
        zoomOutButton.image = UIImage(systemName: "minus.magnifyingglass")

        let recenterButton = CPMapButton { [weak mapVC] _ in
            mapVC?.recenterOnUser()
        }
        recenterButton.image = UIImage(systemName: "location.fill")

        let navigateButton = CPMapButton { [weak self] _ in
            self?.showNavigationDestinations()
        }
        navigateButton.image = UIImage(systemName: "arrow.triangle.turn.up.right.diamond.fill")

        mapTemplate.mapButtons = [recenterButton, zoomInButton, zoomOutButton, navigateButton]

        self.mapTemplate = mapTemplate
        interfaceController.setRootTemplate(mapTemplate, animated: true, completion: nil)

        // Subscribe to speed updates
        appDelegate.speedViewModel.$displayString
            .receive(on: DispatchQueue.main)
            .sink { [weak speedButton] speedText in
                speedButton?.title = speedText
            }
            .store(in: &cancellables)

        // Start location updates
        appDelegate.locationService.startUpdating()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnect interfaceController: CPInterfaceController,
        from window: CPWindow
    ) {
        self.interfaceController = nil
        self.carWindow = nil
        self.mapTemplate = nil
        self.mapViewController = nil
        self.cancellables.removeAll()
    }

    // MARK: - Navigation

    private func showNavigationDestinations() {
        guard let interfaceController else { return }
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        let destinations = appDelegate.navigationViewModel.availableDestinations

        let items = destinations.map { [weak self] destination -> CPListItem in
            let item = CPListItem(
                text: destination.name,
                detailText: destination.description
            )
            item.handler = { _, completion in
                self?.handleDestinationSelected(destination)
                completion()
            }
            return item
        }

        let section = CPListSection(items: items)
        let listTemplate = CPListTemplate(
            title: "Bestemming kiezen",
            sections: [section]
        )

        interfaceController.pushTemplate(listTemplate, animated: true, completion: nil)
    }
}

// MARK: - Destination Selection

extension CarPlaySceneDelegate {

    func handleDestinationSelected(_ destination: Waypoint) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate

        Task {
            do {
                let route = try await appDelegate.navigationViewModel.calculateRoute(to: destination)
                await MainActor.run {
                    startNavigation(with: route)
                }
            } catch {
                // Route calculation failed
            }
        }
    }

    private func startNavigation(with route: WaterwayRoute) {
        guard let mapTemplate else { return }

        let trip = CPTrip(
            origin: MKMapItem(placemark: MKPlacemark(coordinate: route.origin)),
            destination: MKMapItem(placemark: MKPlacemark(coordinate: route.destination)),
            routeChoices: [
                CPRouteChoice(
                    summaryVariants: [route.summary],
                    additionalInformationVariants: [route.distanceString],
                    selectionSummaryVariants: [route.summary]
                )
            ]
        )

        let textConfig = CPTripPreviewTextConfiguration(
            startButtonTitle: "Start",
            additionalRoutesButtonTitle: nil,
            overviewButtonTitle: "Overzicht"
        )

        mapTemplate.showTripPreviews([trip], textConfiguration: textConfig)

        mapTemplate.mapDelegate = mapViewController

        mapViewController?.showRoute(route)
        interfaceController?.popToRootTemplate(animated: true, completion: nil)
    }
}
