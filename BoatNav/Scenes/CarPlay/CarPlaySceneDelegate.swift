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

        // Pro-only feature: show paywall message if not subscribed
        guard FeatureGating.canUseCarPlay else {
            window.rootViewController = Self.makePaywallViewController()
            let info = CPInformationTemplate(
                title: "BoatNav Pro vereist",
                layout: .leading,
                items: [
                    CPInformationItem(title: "CarPlay-weergave", detail: "is alleen beschikbaar voor BoatNav Pro abonnees.")
                ],
                actions: [
                    CPTextButton(title: "Open BoatNav op je iPhone", textStyle: .confirm) { _ in }
                ]
            )
            interfaceController.setRootTemplate(info, animated: true, completion: nil)
            return
        }

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

        let favorites = appDelegate.navigationViewModel.favorites

        let items = favorites.map { [weak self] fav -> CPListItem in
            let item = CPListItem(
                text: fav.name,
                detailText: fav.description
            )
            item.handler = { _, completion in
                self?.handleFavoriteSelected(fav)
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

// MARK: - Paywall fallback

extension CarPlaySceneDelegate {
    static func makePaywallViewController() -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = UIColor(red: 0.043, green: 0.098, blue: 0.161, alpha: 1) // ink
        let label = UILabel()
        label.text = "BoatNav Pro vereist voor CarPlay"
        label.textColor = UIColor(red: 0.52, green: 0.72, blue: 0.92, alpha: 1) // blue.b5
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -32)
        ])
        return vc
    }
}

// MARK: - Destination Selection

extension CarPlaySceneDelegate {

    func handleFavoriteSelected(_ fav: FavoriteLocation) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let waypoint = Waypoint(id: fav.id, name: fav.name, description: fav.description, coordinate: fav.coordinate)

        Task {
            do {
                let route = try await appDelegate.navigationViewModel.calculateRoute(to: waypoint)
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
