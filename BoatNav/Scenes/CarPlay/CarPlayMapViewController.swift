import UIKit
import MapKit
import CarPlay
import Combine

class CarPlayMapViewController: UIViewController, CPMapTemplateDelegate {

    private let mapView = MKMapView()
    private let mapViewModel: MapViewModel
    private let speedViewModel: SpeedViewModel
    private let settingsViewModel: SettingsViewModel
    private let weatherViewModel: WeatherViewModel
    private let waterLevelViewModel: WaterLevelViewModel
    private let navigationViewModel: NavigationViewModel
    private let maneuverProximityService: ManeuverProximityService
    private var cancellables = Set<AnyCancellable>()
    private var routeOverlays: [MKPolyline] = []
    private var isUserInteracting = false
    private var currentBRTOverlay: MKTileOverlay?
    private var currentSeamarkOverlay: MKTileOverlay?

    // UI colors (Design system)
    private let inkColor = UIColor(red: 0x0B/255.0, green: 0x19/255.0, blue: 0x29/255.0, alpha: 0.85)
    private let blueB5 = UIColor(red: 0x85/255.0, green: 0xB7/255.0, blue: 0xEB/255.0, alpha: 1)
    private let blueB4 = UIColor(red: 0x37/255.0, green: 0x8A/255.0, blue: 0xDD/255.0, alpha: 1)
    private let amberA5 = UIColor(red: 0xEF/255.0, green: 0x9F/255.0, blue: 0x27/255.0, alpha: 1)
    private let redR4 = UIColor(red: 0xE2/255.0, green: 0x4B/255.0, blue: 0x4A/255.0, alpha: 1)

    // Top info bar (horizontal pill — mirrors iPhone WeatherBarView)
    private let infoBar = UIView()
    private let infoBarStack = UIStackView()

    // Speed pill (bottom-left, separate)
    private let speedPill = UIView()
    private let speedLabel = UILabel()
    private let speedUnitLabel = UILabel()
    private let limitBadge = UIView()
    private let limitValueLabel = UILabel()

    // Navigation instruction (above speed, appears during nav)
    private let navBanner = UIView()
    private let navInstructionLabel = UILabel()
    private let navDistanceLabel = UILabel()

    // Default region
    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.8, longitude: 4.67),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )

    private let annotationSize = CGSize(width: 8, height: 8)

    init(mapViewModel: MapViewModel, speedViewModel: SpeedViewModel,
         settingsViewModel: SettingsViewModel, weatherViewModel: WeatherViewModel,
         waterLevelViewModel: WaterLevelViewModel, navigationViewModel: NavigationViewModel,
         maneuverProximityService: ManeuverProximityService) {
        self.mapViewModel = mapViewModel
        self.speedViewModel = speedViewModel
        self.settingsViewModel = settingsViewModel
        self.weatherViewModel = weatherViewModel
        self.waterLevelViewModel = waterLevelViewModel
        self.navigationViewModel = navigationViewModel
        self.maneuverProximityService = maneuverProximityService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupInfoPanel()
        bindViewModel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if mapView.overlays.isEmpty {
            setupOverlays()
        }
    }

    // MARK: - Map Setup

    private func setupMapView() {
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading
        mapView.setRegion(defaultRegion, animated: false)
        mapView.mapType = .standard
    }

    private func setupOverlays() {
        let style = settingsViewModel.mapStyle
        let brtOverlay = mapViewModel.tileOverlayProvider.createBRTOverlay(style: style)
        currentBRTOverlay = brtOverlay
        mapView.addOverlay(brtOverlay, level: .aboveLabels)

        if settingsViewModel.showSeamarks {
            let seamarkOverlay = mapViewModel.tileOverlayProvider.createOpenSeaMapOverlay()
            currentSeamarkOverlay = seamarkOverlay
            mapView.addOverlay(seamarkOverlay, level: .aboveLabels)
        }
    }

    // MARK: - Info Bar (horizontal pill at top, like iPhone WeatherBarView)

    private func setupInfoPanel() {
        setupInfoBar()
        setupSpeedPill()
        setupNavBanner()
    }

    private func setupInfoBar() {
        // Horizontal pill at top — mirrors iPhone WeatherBarView exactly
        // Ink.secondary bg with subtle white border, pill shape
        infoBar.backgroundColor = UIColor(red: 0x0D/255.0, green: 0x21/255.0, blue: 0x35/255.0, alpha: 0.92)
        infoBar.layer.cornerRadius = 20
        infoBar.layer.borderWidth = 0.5
        infoBar.layer.borderColor = UIColor.white.withAlphaComponent(0.06).cgColor
        infoBar.clipsToBounds = true
        infoBar.translatesAutoresizingMaskIntoConstraints = false
        infoBar.isHidden = true
        view.addSubview(infoBar)

        infoBarStack.axis = .horizontal
        infoBarStack.spacing = 10
        infoBarStack.alignment = .center
        infoBarStack.translatesAutoresizingMaskIntoConstraints = false
        infoBar.addSubview(infoBarStack)

        NSLayoutConstraint.activate([
            infoBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            infoBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            infoBarStack.topAnchor.constraint(equalTo: infoBar.topAnchor, constant: 8),
            infoBarStack.leadingAnchor.constraint(equalTo: infoBar.leadingAnchor, constant: 14),
            infoBarStack.trailingAnchor.constraint(equalTo: infoBar.trailingAnchor, constant: -14),
            infoBarStack.bottomAnchor.constraint(equalTo: infoBar.bottomAnchor, constant: -8),
        ])
    }

    private func makeBarDivider() -> UIView {
        let d = UIView()
        d.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        d.translatesAutoresizingMaskIntoConstraints = false
        d.widthAnchor.constraint(equalToConstant: 1).isActive = true
        d.heightAnchor.constraint(equalToConstant: 14).isActive = true
        return d
    }

    private func rebuildInfoBar(weather: WeatherService.WeatherData?, waterLevel: WaterLevelService.WaterLevelData?) {
        // Remove all existing items
        infoBarStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let hasWeather = weather != nil
        let hasWater = waterLevel != nil
        infoBar.isHidden = !hasWeather && !hasWater

        guard hasWeather || hasWater else { return }

        let grayG4 = UIColor(red: 0x88/255.0, green: 0x87/255.0, blue: 0x80/255.0, alpha: 1)
        let grayG5 = UIColor(red: 0xB4/255.0, green: 0xB2/255.0, blue: 0xA9/255.0, alpha: 1)

        if let w = weather {
            // Temperature + icon
            let tempLabel = UILabel()
            tempLabel.text = String(format: "%.0f°", w.temperature)
            tempLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
            tempLabel.textColor = blueB5
            infoBarStack.addArrangedSubview(tempLabel)

            infoBarStack.addArrangedSubview(makeBarDivider())

            // Wind: Bft + direction
            let windLabel = UILabel()
            windLabel.text = "Bft \(w.beaufort) \(w.windDirectionLabel)"
            windLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
            windLabel.textColor = blueB5
            infoBarStack.addArrangedSubview(windLabel)

            infoBarStack.addArrangedSubview(makeBarDivider())

            // Precipitation
            let precipLabel = UILabel()
            if w.precipitation > 0 {
                precipLabel.text = String(format: "%.1f mm", w.precipitation)
                precipLabel.textColor = blueB5
            } else {
                precipLabel.text = "Droog"
                precipLabel.textColor = grayG4
            }
            precipLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            infoBarStack.addArrangedSubview(precipLabel)
        }

        if let wl = waterLevel {
            if hasWeather { infoBarStack.addArrangedSubview(makeBarDivider()) }

            // Water level: value + cm + trend + next extreme
            let trendIcon: String
            let trendColor: UIColor
            switch wl.trend {
            case .rising:  trendIcon = "↗"; trendColor = blueB4
            case .falling: trendIcon = "↘"; trendColor = redR4
            case .stable:  trendIcon = "→"; trendColor = grayG4
            }

            var waterText = String(format: "%+.0f cm %@", wl.waterLevelCm, trendIcon)

            // Next tide extreme
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            if let high = wl.nextHighTide, let low = wl.nextLowTide {
                let next = high.time < low.time
                    ? "HW \(formatter.string(from: high.time))"
                    : "LW \(formatter.string(from: low.time))"
                waterText += " \(next)"
            } else if let high = wl.nextHighTide {
                waterText += " HW \(formatter.string(from: high.time))"
            } else if let low = wl.nextLowTide {
                waterText += " LW \(formatter.string(from: low.time))"
            }

            let waterLabel = UILabel()
            waterLabel.text = waterText
            waterLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
            waterLabel.textColor = blueB5
            infoBarStack.addArrangedSubview(waterLabel)
        }
    }

    private func setupSpeedPill() {
        // Speed pill — bottom-left, separate from info bar
        speedPill.backgroundColor = inkColor
        speedPill.layer.cornerRadius = 14
        speedPill.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(speedPill)

        speedLabel.text = "--"
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        speedLabel.textColor = .white
        speedLabel.textAlignment = .center
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedPill.addSubview(speedLabel)

        speedUnitLabel.text = "km/h"
        speedUnitLabel.font = .systemFont(ofSize: 11, weight: .medium)
        speedUnitLabel.textColor = blueB5
        speedUnitLabel.textAlignment = .center
        speedUnitLabel.translatesAutoresizingMaskIntoConstraints = false
        speedPill.addSubview(speedUnitLabel)

        // Speed limit badge — red circle, positioned to the right of speed
        limitBadge.isHidden = true
        limitBadge.backgroundColor = .white
        limitBadge.layer.cornerRadius = 18
        limitBadge.layer.borderWidth = 3
        limitBadge.layer.borderColor = redR4.cgColor
        limitBadge.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(limitBadge)

        limitValueLabel.text = "--"
        limitValueLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .bold)
        limitValueLabel.textColor = redR4
        limitValueLabel.textAlignment = .center
        limitValueLabel.translatesAutoresizingMaskIntoConstraints = false
        limitBadge.addSubview(limitValueLabel)

        NSLayoutConstraint.activate([
            speedPill.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            speedPill.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            speedPill.widthAnchor.constraint(equalToConstant: 80),

            speedLabel.topAnchor.constraint(equalTo: speedPill.topAnchor, constant: 6),
            speedLabel.centerXAnchor.constraint(equalTo: speedPill.centerXAnchor),
            speedUnitLabel.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: -2),
            speedUnitLabel.centerXAnchor.constraint(equalTo: speedPill.centerXAnchor),
            speedUnitLabel.bottomAnchor.constraint(equalTo: speedPill.bottomAnchor, constant: -6),

            // Limit badge to the right of speed pill
            limitBadge.leadingAnchor.constraint(equalTo: speedPill.trailingAnchor, constant: 6),
            limitBadge.centerYAnchor.constraint(equalTo: speedPill.centerYAnchor),
            limitBadge.widthAnchor.constraint(equalToConstant: 36),
            limitBadge.heightAnchor.constraint(equalToConstant: 36),
            limitValueLabel.centerXAnchor.constraint(equalTo: limitBadge.centerXAnchor),
            limitValueLabel.centerYAnchor.constraint(equalTo: limitBadge.centerYAnchor),
        ])
    }

    private func setupNavBanner() {
        // Navigation instruction — above speed pill, appears during active navigation
        navBanner.backgroundColor = UIColor(red: 0x0B/255.0, green: 0x19/255.0, blue: 0x29/255.0, alpha: 0.92)
        navBanner.layer.cornerRadius = 12
        navBanner.translatesAutoresizingMaskIntoConstraints = false
        navBanner.isHidden = true
        view.addSubview(navBanner)

        navInstructionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        navInstructionLabel.textColor = .white
        navInstructionLabel.numberOfLines = 2
        navInstructionLabel.translatesAutoresizingMaskIntoConstraints = false
        navBanner.addSubview(navInstructionLabel)

        navDistanceLabel.font = .monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        navDistanceLabel.textColor = amberA5
        navDistanceLabel.translatesAutoresizingMaskIntoConstraints = false
        navBanner.addSubview(navDistanceLabel)

        NSLayoutConstraint.activate([
            navBanner.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            navBanner.bottomAnchor.constraint(equalTo: speedPill.topAnchor, constant: -8),
            navBanner.widthAnchor.constraint(lessThanOrEqualToConstant: 200),

            navDistanceLabel.topAnchor.constraint(equalTo: navBanner.topAnchor, constant: 8),
            navDistanceLabel.leadingAnchor.constraint(equalTo: navBanner.leadingAnchor, constant: 10),
            navInstructionLabel.topAnchor.constraint(equalTo: navDistanceLabel.bottomAnchor, constant: 2),
            navInstructionLabel.leadingAnchor.constraint(equalTo: navBanner.leadingAnchor, constant: 10),
            navInstructionLabel.trailingAnchor.constraint(equalTo: navBanner.trailingAnchor, constant: -10),
            navInstructionLabel.bottomAnchor.constraint(equalTo: navBanner.bottomAnchor, constant: -8),
        ])
    }

    // MARK: - Bindings

    private func bindViewModel() {
        // Annotations
        mapViewModel.$annotations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] annotations in
                guard let self else { return }
                let existing = self.mapView.annotations.filter { $0 is SeamarkAnnotation }
                self.mapView.removeAnnotations(existing)
                self.mapView.addAnnotations(annotations)
            }
            .store(in: &cancellables)

        // Speed
        speedViewModel.$speedKmh
            .receive(on: DispatchQueue.main)
            .sink { [weak self] kmh in
                guard let self else { return }
                self.speedLabel.text = self.speedViewModel.isValid ? String(format: "%.0f", kmh) : "--"
            }
            .store(in: &cancellables)

        speedViewModel.$isExceedingLimit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] exceeding in
                guard let self else { return }
                self.speedLabel.textColor = exceeding ? self.redR4 : .white
            }
            .store(in: &cancellables)

        speedViewModel.$currentSpeedLimit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] limit in
                guard let self else { return }
                if let limit {
                    self.limitBadge.isHidden = false
                    self.limitValueLabel.text = String(format: "%.0f", limit)
                } else {
                    self.limitBadge.isHidden = true
                }
            }
            .store(in: &cancellables)

        // Weather + water level → rebuild info bar (mirrors iPhone WeatherBarView)
        weatherViewModel.$weather
            .combineLatest(waterLevelViewModel.$waterLevel)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] weather, wl in
                self?.rebuildInfoBar(weather: weather, waterLevel: wl)
            }
            .store(in: &cancellables)

        // Navigation instruction
        maneuverProximityService.$upcomingManeuver
            .combineLatest(maneuverProximityService.$distanceToManeuver)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] maneuver, distance in
                guard let self else { return }
                if let maneuver, let distance, distance <= 500 {
                    self.navBanner.isHidden = false
                    self.navInstructionLabel.text = maneuver.instruction
                    self.navDistanceLabel.text = String(format: "%.0f m", distance)
                } else {
                    self.navBanner.isHidden = true
                }
            }
            .store(in: &cancellables)

        // Settings: map style change
        settingsViewModel.$mapStyle
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStyle in
                self?.updateMapStyle(newStyle)
            }
            .store(in: &cancellables)

        // Settings: seamark overlay toggle
        settingsViewModel.$showSeamarks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                guard let self else { return }
                if show && self.currentSeamarkOverlay == nil {
                    let overlay = self.mapViewModel.tileOverlayProvider.createOpenSeaMapOverlay()
                    self.currentSeamarkOverlay = overlay
                    self.mapView.addOverlay(overlay, level: .aboveLabels)
                } else if !show, let overlay = self.currentSeamarkOverlay {
                    self.mapView.removeOverlay(overlay)
                    self.currentSeamarkOverlay = nil
                }
            }
            .store(in: &cancellables)

        // Settings: annotation visibility changes → refresh annotations
        Publishers.CombineLatest3(
            settingsViewModel.$showBuoys,
            settingsViewModel.$showBridges,
            settingsViewModel.$showRestaurants
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            guard let self else { return }
            let existing = self.mapView.annotations.filter { $0 is SeamarkAnnotation }
            self.mapView.removeAnnotations(existing)
            self.mapView.addAnnotations(self.mapViewModel.annotations)
        }
        .store(in: &cancellables)
    }

    // MARK: - Settings Sync

    private func updateMapStyle(_ style: MapStyle) {
        // Remove current BRT overlay and add new one
        if let old = currentBRTOverlay {
            mapView.removeOverlay(old)
        }
        let newOverlay = mapViewModel.tileOverlayProvider.createBRTOverlay(style: style)
        currentBRTOverlay = newOverlay
        // Insert at bottom so seamark overlay stays on top
        mapView.insertOverlay(newOverlay, at: 0, level: .aboveLabels)
    }

    // MARK: - Map Controls

    func zoomIn() {
        mapView.userTrackingMode = .none
        isUserInteracting = true
        var region = mapView.region
        region.span.latitudeDelta /= 2
        region.span.longitudeDelta /= 2
        mapView.setRegion(region, animated: true)
    }

    func zoomOut() {
        mapView.userTrackingMode = .none
        isUserInteracting = true
        var region = mapView.region
        region.span.latitudeDelta = min(region.span.latitudeDelta * 2, 10)
        region.span.longitudeDelta = min(region.span.longitudeDelta * 2, 10)
        mapView.setRegion(region, animated: true)
    }

    func recenterOnUser() {
        isUserInteracting = false
        mapView.setUserTrackingMode(.followWithHeading, animated: true)
    }

    func showRoute(_ route: WaterwayRoute) {
        for overlay in routeOverlays { mapView.removeOverlay(overlay) }
        routeOverlays.removeAll()

        var boundingRect: MKMapRect?
        for segment in route.polylines {
            guard segment.count >= 2 else { continue }
            let polyline = MKPolyline(coordinates: segment, count: segment.count)
            mapView.addOverlay(polyline, level: .aboveLabels)
            routeOverlays.append(polyline)
            if let existing = boundingRect {
                boundingRect = existing.union(polyline.boundingMapRect)
            } else {
                boundingRect = polyline.boundingMapRect
            }
        }

        let bridgeAnnotations = route.bridges.map { bridge -> SeamarkAnnotation in
            SeamarkAnnotation(
                coordinate: bridge.coordinate,
                title: bridge.name,
                subtitle: String(format: "Doorvaarthoogte: %.1f m", bridge.clearanceHeight),
                type: .bridge
            )
        }
        mapView.addAnnotations(bridgeAnnotations)

        if let rect = boundingRect {
            mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40), animated: true)
        }
    }

    // MARK: - Annotation Image Helpers

    private func makeAnnotationImage(systemName: String, color: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        let image = UIImage(systemName: systemName, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        let renderer = UIGraphicsImageRenderer(size: annotationSize)
        return renderer.image { _ in
            image?.draw(in: CGRect(origin: .zero, size: annotationSize))
        }
    }

    // MARK: - CPMapTemplateDelegate

    func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {
        print("[CarPlay] Trip started")
        mapTemplate.hideTripPreviews()
    }

    func mapTemplateDidShowPanningInterface(_ mapTemplate: CPMapTemplate) {
        mapView.userTrackingMode = .none
        isUserInteracting = true
    }

    func mapTemplateDidDismissPanningInterface(_ mapTemplate: CPMapTemplate) {
        isUserInteracting = false
        mapView.setUserTrackingMode(.followWithHeading, animated: true)
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, panWith direction: CPMapTemplate.PanDirection) {
        mapView.userTrackingMode = .none
        isUserInteracting = true
        let offset: CLLocationDegrees = mapView.region.span.latitudeDelta * 0.25
        var center = mapView.centerCoordinate
        if direction.contains(.up) { center.latitude += offset }
        if direction.contains(.down) { center.latitude -= offset }
        if direction.contains(.left) { center.longitude -= offset }
        if direction.contains(.right) { center.longitude += offset }
        mapView.setCenter(center, animated: true)
    }

    // iOS 26 share destination stubs
    @available(iOS 26.4, *)
    func mapTemplate(_ mapTemplate: CPMapTemplate, willShareDestinationFor trip: CPTrip) {}
    @available(iOS 26.4, *)
    func mapTemplate(_ mapTemplate: CPMapTemplate, didShareDestinationFor trip: CPTrip) {}
    @available(iOS 26.4, *)
    func mapTemplate(_ mapTemplate: CPMapTemplate, didFailToShareDestinationFor trip: CPTrip, error: Error) {}
}

// MARK: - MKMapViewDelegate

extension CarPlayMapViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let tileOverlay = overlay as? MKTileOverlay {
            return MKTileOverlayRenderer(overlay: tileOverlay)
        }
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = blueB4
            renderer.lineWidth = 5
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let seamark = annotation as? SeamarkAnnotation else { return nil }
        let identifier = "CarPlaySeamark"
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        view.annotation = annotation
        view.canShowCallout = false

        switch seamark.type {
        case .buoy:
            view.image = settingsViewModel.showBuoys
                ? makeAnnotationImage(systemName: "circle.fill", color: .systemRed) : nil
        case .beacon:
            view.image = settingsViewModel.showBuoys
                ? makeAnnotationImage(systemName: "circle.fill", color: .systemGreen) : nil
        case .bridge:
            view.image = settingsViewModel.showBridges
                ? makeAnnotationImage(systemName: "square.fill", color: .systemOrange) : nil
        case .lock:
            view.image = settingsViewModel.showBridges
                ? makeAnnotationImage(systemName: "square.fill", color: .systemPurple) : nil
        case .restaurant:
            view.image = settingsViewModel.showRestaurants
                ? makeAnnotationImage(systemName: "circle.fill", color: .systemBrown) : nil
        }
        return view
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        // Detect user-initiated gestures (pinch, pan) and disable tracking
        if let gestureRecognizers = mapView.subviews.first?.gestureRecognizers {
            for gr in gestureRecognizers where gr.state == .began || gr.state == .changed {
                mapView.userTrackingMode = .none
                isUserInteracting = true
                return
            }
        }
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        mapViewModel.regionDidChange(to: mapView.region)
    }
}
