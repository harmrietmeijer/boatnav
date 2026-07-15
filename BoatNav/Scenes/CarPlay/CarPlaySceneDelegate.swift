import CarPlay
import MapKit
import Combine

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var mapTemplate: CPMapTemplate?
    private var carWindow: CPWindow?
    private var mapViewController: CarPlayMapViewController?
    private var cancellables = Set<AnyCancellable>()
    private var isShowingPaywall = false
    private var currentTrip: CPTrip?
    private var currentRoute: WaterwayRoute?
    private var navigationSession: CPNavigationSession?
    private var sessionCancellables = Set<AnyCancellable>()

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController,
        to window: CPWindow
    ) {
        print("[CarPlay] didConnect – setting up CarPlay scene")

        // Clean up any previous connection
        self.cancellables.removeAll()
        self.mapViewController = nil
        self.mapTemplate = nil
        self.isShowingPaywall = false

        self.interfaceController = interfaceController
        self.carWindow = window

        guard let appDelegate = AppDelegate.shared else {
            print("[CarPlay] ERROR: AppDelegate.shared is nil")
            return
        }

        // Listen for pro status changes so we can switch from paywall → map
        SubscriptionManager.shared.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPro in
                guard let self else { return }
                if isPro && self.isShowingPaywall {
                    print("[CarPlay] Pro activated – switching to map")
                    self.setupMapInterface()
                }
            }
            .store(in: &cancellables)

        if FeatureGating.canUseCarPlay {
            setupMapInterface()
        } else {
            print("[CarPlay] Pro not active – showing paywall")
            showPaywall()
        }
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
        self.isShowingPaywall = false
        self.cancellables.removeAll()
    }

    // MARK: - Map Interface

    private func setupMapInterface() {
        guard let interfaceController, let carWindow,
              let appDelegate = AppDelegate.shared else { return }

        isShowingPaywall = false

        let mapVC = CarPlayMapViewController(
            mapViewModel: appDelegate.mapViewModel,
            speedViewModel: appDelegate.speedViewModel,
            settingsViewModel: appDelegate.settingsViewModel,
            weatherViewModel: appDelegate.weatherViewModel,
            waterLevelViewModel: appDelegate.waterLevelViewModel,
            navigationViewModel: appDelegate.navigationViewModel,
            maneuverProximityService: appDelegate.maneuverProximityService
        )
        self.mapViewController = mapVC
        carWindow.rootViewController = mapVC

        let mapTemplate = CPMapTemplate()
        mapTemplate.mapDelegate = mapVC

        // Nav bar — clean, zoom via touch gestures on CarPlay screen
        mapTemplate.leadingNavigationBarButtons = []
        mapTemplate.trailingNavigationBarButtons = []
        mapTemplate.automaticallyHidesNavigationBar = true

        // Map control buttons
        // Map buttons (max 4)
        let recenterButton = CPMapButton { [weak mapVC] _ in
            mapVC?.recenterOnUser()
        }
        recenterButton.image = Self.renderMapButtonIcon("location.fill")

        let navigateButton = CPMapButton { [weak self] _ in
            self?.showNavigationDestinations()
        }
        navigateButton.image = Self.renderMapButtonIcon("arrow.triangle.turn.up.right.diamond.fill")

        let reportButton = CPMapButton { [weak self] _ in
            self?.showHazardReport()
        }
        reportButton.image = Self.renderMapButtonIcon("exclamationmark.triangle.fill")

        mapTemplate.mapButtons = [recenterButton, navigateButton, reportButton]

        self.mapTemplate = mapTemplate
        print("[CarPlay] Setting root template – map template")

        // Workaround: iOS 26 crashes in CPSMapTemplateViewController._viewDidLoad
        // when setting CPMapTemplate synchronously. Deferring to the next run loop
        // lets the CarPlay window complete its initial layout first.
        DispatchQueue.main.async {
            interfaceController.setRootTemplate(mapTemplate, animated: true, completion: nil)
        }

        appDelegate.locationService.startUpdating()
    }

    // MARK: - Paywall

    private func showPaywall() {
        guard let interfaceController, let carWindow else { return }

        isShowingPaywall = true
        carWindow.rootViewController = Self.makePaywallViewController()

        let info = CPInformationTemplate(
            title: "BoatNav Pro",
            layout: .leading,
            items: [
                CPInformationItem(
                    title: "CarPlay navigatie",
                    detail: "is beschikbaar voor BoatNav Pro abonnees. Activeer Pro in de app op je iPhone."
                )
            ],
            actions: [
                CPTextButton(title: "Open BoatNav op iPhone", textStyle: .confirm) { _ in }
            ]
        )
        interfaceController.setRootTemplate(info, animated: true, completion: nil)
    }

    // MARK: - Navigation

    private func showNavigationDestinations() {
        guard let interfaceController, let appDelegate = AppDelegate.shared else { return }

        // Build sections: favorites first, then a search hint
        var sections: [CPListSection] = []

        let favorites = appDelegate.navigationViewModel.favorites
        if !favorites.isEmpty {
            let favItems = favorites.map { [weak self] fav -> CPListItem in
                let item = CPListItem(
                    text: fav.name,
                    detailText: fav.description,
                    image: UIImage(systemName: "star.fill")
                )
                item.handler = { [weak self] _, completion in
                    print("[CarPlay] Favorite tapped: \(fav.name)")
                    self?.handleFavoriteSelected(fav)
                    completion()
                }
                return item
            }
            sections.append(CPListSection(items: favItems, header: "Favorieten", sectionIndexTitle: nil))
        }

        // Add saved routes
        let savedRoutes = appDelegate.navigationViewModel.savedRoutes
        if !savedRoutes.isEmpty {
            let routeItems = savedRoutes.prefix(5).map { [weak self] route -> CPListItem in
                let item = CPListItem(
                    text: route.name,
                    detailText: route.destinationName,
                    image: UIImage(systemName: "map.fill")
                )
                item.handler = { _, completion in
                    self?.handleSavedRouteSelected(route)
                    completion()
                }
                return item
            }
            sections.append(CPListSection(items: routeItems, header: "Routes", sectionIndexTitle: nil))
        }

        if sections.isEmpty {
            let emptyItem = CPListItem(
                text: "Geen bestemmingen",
                detailText: "Voeg favorieten toe in de iPhone app"
            )
            sections.append(CPListSection(items: [emptyItem]))
        }

        let listTemplate = CPListTemplate(
            title: "Bestemming kiezen",
            sections: sections
        )

        interfaceController.pushTemplate(listTemplate, animated: true, completion: nil)
    }
}

// MARK: - Map Button Rendering

extension CarPlaySceneDelegate {
    /// Render SF Symbol as a dark pre-rendered bitmap so CarPlay can't override the tint
    static func renderMapButtonIcon(_ systemName: String) -> UIImage? {
        let size = CGSize(width: 44, height: 44)
        let inkColor = UIColor(red: 0x0B/255.0, green: 0x19/255.0, blue: 0x29/255.0, alpha: 1)
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)

        guard let symbol = UIImage(systemName: systemName, withConfiguration: config) else { return nil }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            inkColor.setFill()
            let symbolSize = symbol.size
            let origin = CGPoint(
                x: (size.width - symbolSize.width) / 2,
                y: (size.height - symbolSize.height) / 2
            )
            symbol.withTintColor(inkColor, renderingMode: .alwaysOriginal)
                .draw(at: origin)
        }
    }
}

// MARK: - Hazard Reporting

extension CarPlaySceneDelegate {
    private func showHazardReport() {
        guard let interfaceController, let appDelegate = AppDelegate.shared else { return }

        let categories = HazardReport.HazardCategory.allCases
        let items = categories.map { category -> CPListItem in
            let item = CPListItem(
                text: category.displayName,
                detailText: nil,
                image: UIImage(systemName: category.iconName)
            )
            item.handler = { [weak self] _, completion in
                appDelegate.hazardReportViewModel.addReport(category: category)
                completion()
                self?.interfaceController?.popTemplate(animated: true, completion: nil)
            }
            return item
        }

        let section = CPListSection(items: items)
        let listTemplate = CPListTemplate(
            title: "Melding plaatsen",
            sections: [section]
        )

        interfaceController.pushTemplate(listTemplate, animated: true, completion: nil)
    }
}

// MARK: - Paywall View Controller

extension CarPlaySceneDelegate {
    static func makePaywallViewController() -> UIViewController {
        let vc = UIViewController()
        // Design.Ink.primary = 0x0B1929
        vc.view.backgroundColor = UIColor(red: 0x0B/255.0, green: 0x19/255.0, blue: 0x29/255.0, alpha: 1)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(stack)

        // Icon
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 40, weight: .light)
        let iconView = UIImageView(image: UIImage(systemName: "sailboat.fill", withConfiguration: iconConfig))
        // Design.Blue.b4 = 0x378ADD
        iconView.tintColor = UIColor(red: 0x37/255.0, green: 0x8A/255.0, blue: 0xDD/255.0, alpha: 1)
        stack.addArrangedSubview(iconView)

        // Title
        let title = UILabel()
        title.text = "BoatNav Pro"
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        title.textColor = .white
        stack.addArrangedSubview(title)

        // Subtitle
        let subtitle = UILabel()
        subtitle.text = "Activeer Pro op je iPhone\nvoor CarPlay navigatie"
        // Design.Blue.b5 = 0x85B7EB
        subtitle.textColor = UIColor(red: 0x85/255.0, green: 0xB7/255.0, blue: 0xEB/255.0, alpha: 1)
        subtitle.textAlignment = .center
        subtitle.numberOfLines = 0
        subtitle.font = .systemFont(ofSize: 16, weight: .regular)
        stack.addArrangedSubview(subtitle)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: vc.view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: vc.view.trailingAnchor, constant: -32)
        ])
        return vc
    }
}

// MARK: - Destination Selection

extension CarPlaySceneDelegate {

    func handleSavedRouteSelected(_ savedRoute: SavedRoute) {
        guard let appDelegate = AppDelegate.shared else { return }
        print("[CarPlay] Navigating saved route: \(savedRoute.name)")

        // Use the saved route's original start and destination
        appDelegate.navigationViewModel.startSelection = .search(
            name: savedRoute.startName,
            coordinate: savedRoute.startCoordinate
        )
        appDelegate.navigationViewModel.destinationSelection = .search(
            name: savedRoute.destinationName,
            coordinate: savedRoute.destinationCoordinate
        )

        mapViewController?.showLoading()
        interfaceController?.popToRootTemplate(animated: true, completion: nil)

        Task {
            await appDelegate.navigationViewModel.calculateRoute()
            await MainActor.run {
                self.mapViewController?.hideLoading()
                if let route = appDelegate.navigationViewModel.currentRoute {
                    print("[CarPlay] Route calculated: \(route.summary)")
                    self.startNavigation(with: route, destinationName: savedRoute.destinationName)
                } else {
                    print("[CarPlay] Route calculation failed")
                }
            }
        }
    }

    func handleFavoriteSelected(_ fav: FavoriteLocation) {
        guard let appDelegate = AppDelegate.shared else {
            print("[CarPlay] ERROR: AppDelegate is nil")
            return
        }
        print("[CarPlay] Navigating to favorite: \(fav.name)")
        let waypoint = Waypoint(id: fav.id, name: fav.name, description: fav.description, coordinate: fav.coordinate)

        mapViewController?.showLoading()
        interfaceController?.popToRootTemplate(animated: true, completion: nil)

        Task {
            do {
                let route = try await appDelegate.navigationViewModel.calculateRoute(to: waypoint)
                print("[CarPlay] Route calculated: \(route.summary)")
                await MainActor.run {
                    self.mapViewController?.hideLoading()
                    self.startNavigation(with: route, destinationName: fav.name)
                }
            } catch {
                print("[CarPlay] Route calculation failed: \(error)")
                await MainActor.run {
                    self.mapViewController?.hideLoading()
                }
            }
        }
    }

    private func startNavigation(with route: WaterwayRoute, destinationName: String) {
        guard let mapTemplate, let appDelegate = AppDelegate.shared else { return }

        // Clean up any previous navigation session
        if navigationSession != nil {
            endNavigationSession()
            mapTemplate.hideTripPreviews()
        }

        // Show route on map
        mapViewController?.showRoute(route)

        // Build named MKMapItems so CarPlay shows proper names
        let originItem = MKMapItem(placemark: MKPlacemark(coordinate: route.origin))
        originItem.name = "Huidige positie"

        let destItem = MKMapItem(placemark: MKPlacemark(coordinate: route.destination))
        destItem.name = destinationName

        let trip = CPTrip(
            origin: originItem,
            destination: destItem,
            routeChoices: [
                CPRouteChoice(
                    summaryVariants: [route.summary],
                    additionalInformationVariants: [route.distanceString],
                    selectionSummaryVariants: [route.summary]
                )
            ]
        )
        self.currentTrip = trip
        self.currentRoute = route

        let textConfig = CPTripPreviewTextConfiguration(
            startButtonTitle: "Start navigatie",
            additionalRoutesButtonTitle: nil,
            overviewButtonTitle: "Overzicht"
        )

        mapTemplate.showTripPreviews([trip], textConfiguration: textConfig)

        // When user taps "Start navigatie", begin CPNavigationSession
        mapViewController?.onTripStarted = { [weak self] trip, _ in
            self?.beginNavigationSession(for: trip)
        }

        appDelegate.navigationViewModel.isNavigating = true
    }

    private func beginNavigationSession(for trip: CPTrip) {
        guard let mapTemplate, let appDelegate = AppDelegate.shared,
              let route = currentRoute else { return }

        let session = mapTemplate.startNavigationSession(for: trip)
        self.navigationSession = session

        // Hide info bar during navigation to avoid overlap
        mapViewController?.setInfoBarHidden(true)

        // Build CPManeuvers from route maneuvers
        let cpManeuvers: [CPManeuver] = route.maneuvers.compactMap { maneuver in
            let m = CPManeuver()
            m.instructionVariants = [maneuver.instruction]
            m.initialTravelEstimates = CPTravelEstimates(
                distanceRemaining: Measurement(value: max(maneuver.distanceFromPrevious, 0), unit: .meters),
                timeRemaining: max(maneuver.estimatedTimeFromPrevious, 0)
            )
            if let symbolName = Self.symbolName(for: maneuver.type),
               let img = UIImage(systemName: symbolName) {
                m.symbolImage = img
            }
            return m
        }
        if !cpManeuvers.isEmpty {
            session.upcomingManeuvers = cpManeuvers
        }

        // Subscribe to proximity service for live distance updates
        sessionCancellables.removeAll()
        appDelegate.maneuverProximityService.$upcomingManeuver
            .combineLatest(appDelegate.maneuverProximityService.$distanceToManeuver)
            .receive(on: DispatchQueue.main)
            .sink { [weak session] maneuver, distance in
                guard let session, let maneuver, let distance else { return }
                let estimates = CPTravelEstimates(
                    distanceRemaining: Measurement(value: distance, unit: .meters),
                    timeRemaining: max(distance / 3.0, 0)
                )
                if let cpManeuver = session.upcomingManeuvers.first(where: {
                    $0.instructionVariants.first == maneuver.instruction
                }) {
                    session.updateEstimates(estimates, for: cpManeuver)
                }
            }
            .store(in: &sessionCancellables)

        // End session when navigation stops
        appDelegate.navigationViewModel.$isNavigating
            .dropFirst()
            .filter { !$0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.endNavigationSession()
            }
            .store(in: &sessionCancellables)

        print("[CarPlay] Navigation session started with \(cpManeuvers.count) maneuvers")
    }

    private func endNavigationSession() {
        navigationSession?.finishTrip()
        navigationSession = nil
        sessionCancellables.removeAll()
        // Show info bar again
        mapViewController?.setInfoBarHidden(false)
        print("[CarPlay] Navigation session ended")
    }

    private static func symbolName(for type: RouteManeuver.ManeuverType) -> String? {
        switch type {
        case .depart:
            return "location.fill"
        case .turn(let dir):
            switch dir {
            case .left: return "arrow.turn.up.left"
            case .right: return "arrow.turn.up.right"
            case .slightLeft: return "arrow.up.left"
            case .slightRight: return "arrow.up.right"
            case .straight: return "arrow.up"
            }
        case .bridge:
            return "arrow.up.and.down"
        case .lock:
            return "rectangle.split.3x1"
        case .arrive:
            return "flag.fill"
        }
    }

    func cancelNavigation() {
        guard let mapTemplate, let appDelegate = AppDelegate.shared else { return }
        mapTemplate.hideTripPreviews()
        endNavigationSession()
        appDelegate.navigationViewModel.stopNavigation()
        mapViewController?.recenterOnUser()
    }
}
