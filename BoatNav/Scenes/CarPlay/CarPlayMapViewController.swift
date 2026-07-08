import UIKit
import MapKit
import CarPlay
import Combine

class CarPlayMapViewController: UIViewController, CPMapTemplateDelegate {

    private let mapView = MKMapView()
    private let mapViewModel: MapViewModel
    private let speedViewModel: SpeedViewModel
    private var cancellables = Set<AnyCancellable>()
    private var routeOverlays: [MKPolyline] = []
    private var isUserInteracting = false

    // Speed overlay
    private let speedContainer = UIView()
    private let speedLabel = UILabel()
    private let speedUnitLabel = UILabel()
    private let limitContainer = UIView()
    private let limitLabel = UILabel()
    private let limitValueLabel = UILabel()

    // Default region: Dordrecht / Biesbosch area
    private let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.8, longitude: 4.67),
        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
    )

    // Small annotation size for CarPlay's low-res display
    private let annotationSize = CGSize(width: 12, height: 12)

    init(mapViewModel: MapViewModel, speedViewModel: SpeedViewModel) {
        self.mapViewModel = mapViewModel
        self.speedViewModel = speedViewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupSpeedOverlay()
        bindViewModel()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if mapView.overlays.isEmpty {
            setupOverlays()
        }
    }

    // MARK: - Setup

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
        let brtOverlay = mapViewModel.tileOverlayProvider.createBRTOverlay()
        mapView.addOverlay(brtOverlay, level: .aboveLabels)

        let seamarkOverlay = mapViewModel.tileOverlayProvider.createOpenSeaMapOverlay()
        mapView.addOverlay(seamarkOverlay, level: .aboveLabels)
    }

    private func setupSpeedOverlay() {
        // Ink.primary background with rounded corners
        let inkColor = UIColor(red: 0x0B/255.0, green: 0x19/255.0, blue: 0x29/255.0, alpha: 0.85)
        let blueB5 = UIColor(red: 0x85/255.0, green: 0xB7/255.0, blue: 0xEB/255.0, alpha: 1)
        let blueB4 = UIColor(red: 0x37/255.0, green: 0x8A/255.0, blue: 0xDD/255.0, alpha: 1)

        // Speed container
        speedContainer.backgroundColor = inkColor
        speedContainer.layer.cornerRadius = 12
        speedContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(speedContainer)

        // Speed value
        speedLabel.text = "--"
        speedLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .bold)
        speedLabel.textColor = .white
        speedLabel.textAlignment = .center
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedContainer.addSubview(speedLabel)

        // Speed unit
        speedUnitLabel.text = "km/h"
        speedUnitLabel.font = .systemFont(ofSize: 13, weight: .medium)
        speedUnitLabel.textColor = blueB5
        speedUnitLabel.textAlignment = .center
        speedUnitLabel.translatesAutoresizingMaskIntoConstraints = false
        speedContainer.addSubview(speedUnitLabel)

        // Speed limit container (red border circle style)
        limitContainer.backgroundColor = inkColor
        limitContainer.layer.cornerRadius = 12
        limitContainer.translatesAutoresizingMaskIntoConstraints = false
        limitContainer.isHidden = true
        view.addSubview(limitContainer)

        // Limit label
        limitLabel.text = "MAX"
        limitLabel.font = .systemFont(ofSize: 10, weight: .bold)
        limitLabel.textColor = blueB5
        limitLabel.textAlignment = .center
        limitLabel.translatesAutoresizingMaskIntoConstraints = false
        limitContainer.addSubview(limitLabel)

        // Limit value
        limitValueLabel.text = "--"
        limitValueLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        limitValueLabel.textColor = blueB4
        limitValueLabel.textAlignment = .center
        limitValueLabel.translatesAutoresizingMaskIntoConstraints = false
        limitContainer.addSubview(limitValueLabel)

        NSLayoutConstraint.activate([
            // Speed container: bottom-left (safe area to avoid CarPlay chrome)
            speedContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            speedContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            speedContainer.widthAnchor.constraint(equalToConstant: 80),

            speedLabel.topAnchor.constraint(equalTo: speedContainer.topAnchor, constant: 8),
            speedLabel.leadingAnchor.constraint(equalTo: speedContainer.leadingAnchor, constant: 8),
            speedLabel.trailingAnchor.constraint(equalTo: speedContainer.trailingAnchor, constant: -8),

            speedUnitLabel.topAnchor.constraint(equalTo: speedLabel.bottomAnchor, constant: 0),
            speedUnitLabel.leadingAnchor.constraint(equalTo: speedContainer.leadingAnchor, constant: 8),
            speedUnitLabel.trailingAnchor.constraint(equalTo: speedContainer.trailingAnchor, constant: -8),
            speedUnitLabel.bottomAnchor.constraint(equalTo: speedContainer.bottomAnchor, constant: -8),

            // Limit container: above speed
            limitContainer.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            limitContainer.bottomAnchor.constraint(equalTo: speedContainer.topAnchor, constant: -8),
            limitContainer.widthAnchor.constraint(equalToConstant: 80),

            limitLabel.topAnchor.constraint(equalTo: limitContainer.topAnchor, constant: 6),
            limitLabel.leadingAnchor.constraint(equalTo: limitContainer.leadingAnchor, constant: 8),
            limitLabel.trailingAnchor.constraint(equalTo: limitContainer.trailingAnchor, constant: -8),

            limitValueLabel.topAnchor.constraint(equalTo: limitLabel.bottomAnchor, constant: 0),
            limitValueLabel.leadingAnchor.constraint(equalTo: limitContainer.leadingAnchor, constant: 8),
            limitValueLabel.trailingAnchor.constraint(equalTo: limitContainer.trailingAnchor, constant: -8),
            limitValueLabel.bottomAnchor.constraint(equalTo: limitContainer.bottomAnchor, constant: -6),
        ])
    }

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
                if self.speedViewModel.isValid {
                    self.speedLabel.text = String(format: "%.0f", kmh)
                } else {
                    self.speedLabel.text = "--"
                }
            }
            .store(in: &cancellables)

        // Speed exceeding limit — turn red
        speedViewModel.$isExceedingLimit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] exceeding in
                let redR4 = UIColor(red: 0xE2/255.0, green: 0x4B/255.0, blue: 0x4A/255.0, alpha: 1)
                self?.speedLabel.textColor = exceeding ? redR4 : .white
            }
            .store(in: &cancellables)

        // Speed limit
        speedViewModel.$currentSpeedLimit
            .receive(on: DispatchQueue.main)
            .sink { [weak self] limit in
                guard let self else { return }
                if let limit {
                    self.limitContainer.isHidden = false
                    self.limitValueLabel.text = String(format: "%.0f", limit)
                } else {
                    self.limitContainer.isHidden = true
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Map Controls

    func zoomIn() {
        // Disable tracking so the zoom doesn't snap back
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
        for overlay in routeOverlays {
            mapView.removeOverlay(overlay)
        }
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
            mapView.setVisibleMapRect(
                rect,
                edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
                animated: true
            )
        }
    }

    // MARK: - Annotation Image Helpers

    private func makeAnnotationImage(systemName: String, color: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        let image = UIImage(systemName: systemName, withConfiguration: config)?
            .withTintColor(color, renderingMode: .alwaysOriginal)

        // Render at fixed small size for CarPlay
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
            renderer.strokeColor = UIColor(red: 0x37/255.0, green: 0x8A/255.0, blue: 0xDD/255.0, alpha: 1)
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
        view.canShowCallout = false // No callouts on CarPlay

        switch seamark.type {
        case .buoy:
            view.image = makeAnnotationImage(systemName: "circle.fill", color: .systemRed)
        case .beacon:
            view.image = makeAnnotationImage(systemName: "triangle.fill", color: .systemGreen)
        case .bridge:
            view.image = makeAnnotationImage(systemName: "arrow.up.and.down.square.fill", color: .systemOrange)
        case .lock:
            view.image = makeAnnotationImage(systemName: "door.left.hand.closed", color: .systemPurple)
        case .restaurant:
            // Don't show restaurants on CarPlay — too much clutter
            view.image = nil
        }

        return view
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        mapViewModel.regionDidChange(to: mapView.region)
    }
}
